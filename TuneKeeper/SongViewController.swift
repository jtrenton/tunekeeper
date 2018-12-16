//
//  ViewController.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 5/5/17.
//  Copyright © 2017 Jeffrey Crace. All rights reserved.
//

import UIKit
import CoreData


class SongViewController: UIViewController {
    
    var songs:[Song] = []
    
    @IBOutlet weak var songTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        songs = SongManager.fetchAll()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPartsOfSong" {
            if let indexPath = self.songTable.indexPathForSelectedRow {
                let navController: UINavigationController = segue.destination as! UINavigationController
                let controller = navController.topViewController as! PartsOfSongViewController
                if let name = songs[indexPath.row].name {
                    controller.songNameToBeReceived = name
                }
            }
        }
    }

    @IBAction func plusBtnClicked(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Add song", message: nil, preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = "Enter song name"
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0]
            let name:String! = textField?.text!
            self.saveSong(name: name)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func saveSong(name: String){
        do {
            let newSong = try SongManager.save(songName: name)
            self.reloadSongTable()
            SongManager.addDefaultPartsToSong(newSong: newSong)
        }
        catch SongManager.SongManagerError.duplicateSong {
            self.showFailureAlert(errorMessage: "Duplicate Song Title")
        }
        catch SongManager.SongManagerError.emptySongTitle {
            self.showFailureAlert(errorMessage: "Empty Song Title")
        }
        catch {
            self.showFailureAlert(errorMessage: "Something went wrong")
        }
    }
    
    func showFailureAlert(errorMessage: String) {
        
        let alert = UIAlertController(title: nil, message: "Duplicate song title", preferredStyle: .alert)
        
        self.present(alert, animated: true, completion:{
            alert.view.superview?.isUserInteractionEnabled = true
            alert.view.superview?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backgroundTapped)))
        })
    }
    
    @objc func backgroundTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func reloadSongTable() {
        
        songs = SongManager.fetchAll()
        
        DispatchQueue.main.async {
            self.songTable.reloadData()
        }
    }

}

extension SongViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if !songs.isEmpty {
            songTable.separatorStyle = .singleLine
            songTable.backgroundColor = UIColor.white
            return 1
        }
        else {
            emptyTableMessage(message: "Tap + button to add a song")
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        cell.textLabel?.text = songs[indexPath.row].name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            do {
                
                guard let name = songs[indexPath.row].name else {
                    print("Song being deleted did not have name")
                    return
                }
                
                let fileManager = FileManager.default
                let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let folderName = "\(name)"
                let filePath = documentDirectory.appendingPathComponent(folderName)
                if fileManager.fileExists(atPath: filePath.path) {
                    try fileManager.removeItem(at: filePath)
                }
                
                let fetchRequest: NSFetchRequest<Song> = Song.fetchRequest()
                
                fetchRequest.predicate = NSPredicate(format: "name == %@", name)
                
                let fetchedSongs = try DatabaseController.getContext().fetch(fetchRequest)
                
                for song in fetchedSongs {
                    DatabaseController.getContext().delete(song)
                }
                
                try DatabaseController.getContext().save()
                
                reloadSongTable()
            }
            catch {
                print("Error occurred while deleting song -- \(error)")
            }
        }
    }
    
    func emptyTableMessage(message: String) {
        let emptyTableMessage = UILabel()
        emptyTableMessage.text = message
        emptyTableMessage.textColor = UIColor.white
        emptyTableMessage.numberOfLines = 0
        emptyTableMessage.textAlignment = .center
        emptyTableMessage.font = UIFont.systemFont(ofSize: 15)
        emptyTableMessage.sizeToFit()

        let xConstraint = NSLayoutConstraint(
            item: emptyTableMessage,
            attribute: .centerX,
            relatedBy: .equal,
            toItem: songTable,
            attribute: .centerX,
            multiplier: 1,
            constant: 0
        )
        
        let yConstraint = NSLayoutConstraint(
            item: emptyTableMessage,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: songTable,
            attribute: .centerY,
            multiplier: 0.50,
            constant: 0
        )
        
        songTable.backgroundView = emptyTableMessage
        songTable.backgroundView?.translatesAutoresizingMaskIntoConstraints = false
        songTable.backgroundColor = UIColor.clear
        songTable.separatorStyle = .none
        
        NSLayoutConstraint.activate([xConstraint, yConstraint])
    }
}
