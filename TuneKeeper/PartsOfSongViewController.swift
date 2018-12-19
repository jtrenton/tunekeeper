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
            self.dismiss(animated: false, completion: nil)
            return
        }

        song = SongManager.fetchSong(songName: songNameToBeReceived)
        fetchParts()
        
        guard let name = song.name else {
            self.dismiss(animated: false, completion: nil)
            return
        }
        
        songNameLabel.text = name
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
            if let textFields = alert?.textFields, let name = textFields[0].text, !name.isEmpty {
                self.addPart(partName: name)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func addPart(partName: String){
        
        do {
            try PartManager.save(song: song, partName: partName, hasLyrics: false)
        }
        catch PartManager.PartManagerError.duplicatePart {
            showFailureAlert(errorMessage: "Duplicate part title!")
        }
        catch {
            fatalError("Encountered an error while adding a part -- \(error.localizedDescription)")
        }
        
        fetchParts()
        
        DispatchQueue.main.async {
            self.partsOfSongTable.reloadData()
        }
        
    }
    
    func showFailureAlert(errorMessage: String) {
        
        let alert = UIAlertController(title: nil, message: errorMessage, preferredStyle: .alert)
        
        self.present(alert, animated: true, completion:{
            alert.view.superview?.isUserInteractionEnabled = true
            alert.view.superview?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backgroundTapped)))
        })
    }
    
    @objc func backgroundTapped() {
        self.dismiss(animated: true, completion: nil)
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
                    do {
                        try fileManager.removeItem(at: filePath)
                    }
                    catch {
                        showFailureAlert(errorMessage: "There was an error deleting a part!")
                    }
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
                fatalError("Encountered an error while fetching parts after deleting a part -- \(error.localizedDescription)")
            }
        }
    }
}
