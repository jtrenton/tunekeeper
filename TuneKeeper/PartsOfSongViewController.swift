//
//  PartsOfSongViewController.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 5/7/17.
//  Copyright © 2017 Jeffrey Crace. All rights reserved.
//

import UIKit
import CoreData

class PartsOfSongViewController: UIViewController {
    
    var songNameToBeReceived = ""
    var song:Song!
    
    var parts:[Part] = []
    
    @IBOutlet weak var reorderBtn: UIButton!
    @IBOutlet weak var partsOfSongTable: UITableView!
    @IBOutlet weak var songNameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard !songNameToBeReceived.isEmpty else {
            print("Song name passed from SongViewController to PartsOfSongViewController via segue was empty.")
            return
        }

        song = SongManager.fetchSong(songName: songNameToBeReceived)
        fetchParts()
        
        guard let name = song.name else {
            print("Song did not have a name")
            return
        }
        
        songNameLabel.text = name
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showMusicClips" {
            if let indexPath = self.partsOfSongTable.indexPathForSelectedRow {
                let navController:UINavigationController = segue.destination as! UINavigationController
                let controller = navController.topViewController as! ClipsViewController
                controller.partIdToBeReceived = parts[indexPath.row].id 
                controller.song = song
                
            }
        }
        else if segue.identifier == "showLyrics" {
            if let indexPath = self.partsOfSongTable.indexPathForSelectedRow {
                let navController:UINavigationController = segue.destination as! UINavigationController
                let controller = navController.topViewController as! LyricsViewController
                controller.partIdToBeReceived = parts[indexPath.row].id
                controller.song = song
            }
        }
    }
    
    @IBAction func reorderBtnClicked(_ sender: UIButton) {
        
        switch reorderBtn.titleLabel!.text {
            case "Reorder"?:
                reorderBtn.setTitle("Done", for: .normal)
            case "Done"?:
                reorderBtn.setTitle("Reorder", for: .normal)
            default: break
        }
        
        partsOfSongTable.isEditing = !partsOfSongTable.isEditing
    }

    func fetchParts(){
        let partsSet = song.mutableSetValue(forKey: "parts")
        parts = partsSet.allObjects as! [Part]
        parts.sort(by: {$0.id < $1.id})
    }
    
    @IBAction func plusBtnClicked(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Add part", message: "ex. Verse, Chorus, etc.", preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = "Enter part name"
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0]
            if let textField = textField, let name = textField.text, !name.isEmpty {
                self.addPart(partName: name)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func addPart(partName: String){
        
        PartManager.save(song: song, partName: partName, hasLyrics: false)
        
        fetchParts()
        
        DispatchQueue.main.async {
            self.partsOfSongTable.reloadData()
        }
        
    }
    
    func showFailureAlert() {
        
        let alert = UIAlertController(title: "!", message: "Duplicate part title", preferredStyle: .alert)
        
        self.present(alert, animated: true, completion:{
            alert.view.superview?.isUserInteractionEnabled = true
            alert.view.superview?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backgroundTapped)))
        })
    }
    
    @objc func backgroundTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    func checkForDupePartNames(partName: String) -> Bool {
        
        let fetchRequest:NSFetchRequest<Part> = Part.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "name == %@", partName)
        
        do {
            let parts = try DatabaseController.getContext().fetch(fetchRequest)
            
            if !parts.isEmpty {
                print("Found duplicate part name")
                return true
            }
            else {
                return false
            }
        }
        catch {
            print("Failed to get context for container")
            return true
        }
        
    }

    @IBAction func dismissToSongs(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension PartsOfSongViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return parts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        cell.textLabel?.text = parts[indexPath.row].name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
        let movedObject = self.parts[sourceIndexPath.row]
        parts.remove(at: sourceIndexPath.row)
        parts.insert(movedObject, at: destinationIndexPath.row)
        
        var i = 0;
        var end = 0;
        
        if (sourceIndexPath.row < destinationIndexPath.row){
            i = sourceIndexPath.row
            end = destinationIndexPath.row
        }
        else {
            i = destinationIndexPath.row
            end = sourceIndexPath.row
        }
        
        while (i <= end){
            parts[i].id = Int16(i);
            i = i + 1;
        }
        
        DatabaseController.saveContext()
        
        fetchParts()
        
        DispatchQueue.main.async {
            self.partsOfSongTable.reloadData()
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if parts[indexPath.row].hasLyrics{
            performSegue(withIdentifier: "showLyrics", sender: self)
        }
        else {
            performSegue(withIdentifier: "showMusicClips", sender: self)
        }
    }
    
    public func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if indexPath.row == 0 {
            return UITableViewCellEditingStyle.none
        } else {
            return UITableViewCellEditingStyle.delete
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            do {
                let fileManager = FileManager.default
                let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let folderName = "\(song!.name!)/\(parts[indexPath.row].name!)"
                let filePath = documentDirectory.appendingPathComponent(folderName)
                if fileManager.fileExists(atPath: filePath.path) {
                    try fileManager.removeItem(at: filePath)
                }
                
                let fetchRequest: NSFetchRequest<Part> = Part.fetchRequest()
                fetchRequest.predicate = NSPredicate.init(format: "id==\(parts[indexPath.row].id)")
                
                let fetchedParts = try DatabaseController.getContext().fetch(fetchRequest)
                for part in fetchedParts {
                    DatabaseController.getContext().delete(part)
                }
                try DatabaseController.getContext().save()
                
                parts.remove(at: indexPath.row)
                
                for i in indexPath.row..<parts.count {
                    parts[i].id = parts[i].id - 1
                }
                
                try DatabaseController.getContext().save()
            
                partsOfSongTable.reloadData()
                
            }
            catch {
                print("Error occurred while deleting clip -- \(error)")
            }
        }
    }
}
