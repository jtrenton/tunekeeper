//
//  ViewController.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 5/5/17.
//  Copyright © 2017 Jeffrey Crace. All rights reserved.
//

import UIKit
import CoreData


class SongController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var songs:[Song] = []
    
    @IBOutlet weak var songTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        songs = fetchSongs()
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
                controller.songNameToBeReceived = songs[indexPath.row].name!
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        cell.textLabel?.text = songs[indexPath.row].name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }

    @IBAction func plusBtnClicked(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Add song", message: nil, preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = "Enter song name"
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0]
            
            let name:String! = textField?.text!
            
            self.addNewSong(songName: name)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }

    func addNewSong(songName: String) {
        
        if checkForDupeSongNames(songName: songName){
            showFailureAlert()
            return
        }
        
        let newSong:Song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: DatabaseController.persistentContainer.viewContext) as! Song
        
        newSong.name = songName
        
        newSong.partsCount = 0
        
        DatabaseController.saveContext()
        
        songs = fetchSongs()
        
        DispatchQueue.main.async {
            self.songTable.reloadData()
        }
        
        addDefaultPartsToSong(newSong: newSong)
    }
    
    func addDefaultPartsToSong(newSong: Song){

        addPart(song: newSong, partName: "Lyrics", hasLyrics: true)
        
        addPart(song: newSong, partName: "Intro", hasLyrics: false)
        
        addPart(song: newSong, partName: "Verse 1", hasLyrics: false)
        
        addPart(song: newSong, partName: "Chorus 1", hasLyrics: false)
        
        addPart(song: newSong, partName: "Verse 2", hasLyrics: false)
        
        addPart(song: newSong, partName: "Chorus 2", hasLyrics: false)
        
        addPart(song: newSong, partName: "Bridge", hasLyrics: false)
        
        addPart(song: newSong, partName: "Chorus 3", hasLyrics: false)
        
        addPart(song: newSong, partName: "Outro", hasLyrics: false)
    }
    
    func addPart(song: Song, partName: String, hasLyrics: Bool){
        
        let part:Part = NSEntityDescription.insertNewObject(forEntityName: "Part", into: DatabaseController.persistentContainer.viewContext) as! Part
        
        part.id = song.partsCount
        
        song.partsCount = song.partsCount + 1
        
        part.name = partName
        
        part.hasLyrics = hasLyrics
        
        part.song = song
        
        DatabaseController.saveContext()
        
    }
    
    func checkForDupeSongNames(songName: String) -> Bool {
        
        let fetchRequest:NSFetchRequest<Song> = Song.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "name == %@", songName)
        
        do {
            let songsWithDupeNames = try DatabaseController.getContext().fetch(fetchRequest)
            
            if songsWithDupeNames.isEmpty {
                return false
            }
            else {
                return true
            }
        }
        catch {
            print("Failed to get context for container")
            return true
        }
        
    }
    
    func showFailureAlert() {
        
        let alert = UIAlertController(title: "!", message: "Duplicate song title", preferredStyle: .alert)
        
        self.present(alert, animated: true, completion:{
            alert.view.superview?.isUserInteractionEnabled = true
            alert.view.superview?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backgroundTapped)))
        })
    }
    
    func backgroundTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func fetchSongs() -> [Song] {
        
        var songs:[Song] = []
        
        let fetchRequest:NSFetchRequest<Song> = Song.fetchRequest()
        
        do {
            songs = try DatabaseController.getContext().fetch(fetchRequest)
        }
        catch {
            print("Failed to fetch song records")
            
        }
        
        return songs
    }
}

