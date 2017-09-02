//
//  PartsOfSongViewController.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 5/7/17.
//  Copyright © 2017 Jeffrey Crace. All rights reserved.
//

import UIKit
import CoreData

class PartsOfSongViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var songNameToBeReceived = ""
    var song:Song!
    
    var parts:[Part] = []
    
    @IBOutlet weak var reorderBtn: UIButton!
    
    @IBOutlet weak var songNameLbl: UILabel!
    @IBOutlet weak var partsOfSongTable: UITableView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !songNameToBeReceived.isEmpty {
            
            song = fetchSong()
            
            parts = fetchParts()
            
            self.title = song.name
        }
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
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
        
        parts = fetchParts()
        
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
    
    
    func fetchParts() -> [Part] {
        
        var parts:[Part]
        
        let partsSet = song.mutableSetValue(forKey: "parts")
        
        parts = partsSet.allObjects as! [Part]
        
        parts.sort(by: {$0.id < $1.id})
        
        return parts
    }
    
    @IBAction func plusBtnClicked(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Add part", message: "ex. Verse, Chorus, etc.", preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = "Enter part name"
        }
        
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0]
            
            let name:String! = textField?.text!
            
            self.addPart(partName: name)
        }))
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func addPart(partName: String){
        
        let part:Part = NSEntityDescription.insertNewObject(forEntityName: "Part", into: DatabaseController.persistentContainer.viewContext) as! Part
        
        part.id = song.partsCount
        
        song.partsCount = song.partsCount + 1
        
        part.name = partName
        
        part.hasLyrics = false
        
        part.song = song
        
        DatabaseController.saveContext()
        
        parts = fetchParts()
        
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
    
    func backgroundTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    func checkForDupePartNames(partName: String) -> Bool {
        
        let fetchRequest:NSFetchRequest<Part> = Part.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "name == %@", partName)
        
        do {
            let parts = try DatabaseController.getContext().fetch(fetchRequest)
            
            if parts.count > 0 {
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
    
    func fetchSong() -> Song? {

        let fetchRequest:NSFetchRequest<Song> = Song.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "name == %@", songNameToBeReceived)
        
        do {
            let songs = try DatabaseController.getContext().fetch(fetchRequest)
            
            if !songs.isEmpty {
                return songs[0]
            }
            else {
                //Failed to find song
            }
        }
        catch {
            print("Failed to get context for container")
        }
        
        return nil
    }
}
