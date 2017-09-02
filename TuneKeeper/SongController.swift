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
            
            
            do {
                let newSong = try SongManager.save(songName: name)
                self.reloadSongTable()
                self.addDefaultPartsToSong(newSong: newSong)
            }
            catch {
                self.showFailureAlert()
            }
            
        }))
        
        self.present(alert, animated: true, completion: nil)
    }

    
    func addDefaultPartsToSong(newSong: Song){

        PartManager.save(song: newSong, partName: "Lyrics", hasLyrics: true)
        
        PartManager.save(song: newSong, partName: "Intro", hasLyrics: false)
        
        PartManager.save(song: newSong, partName: "Verse 1", hasLyrics: false)
        
        PartManager.save(song: newSong, partName: "Chorus 1", hasLyrics: false)
        
        PartManager.save(song: newSong, partName: "Verse 2", hasLyrics: false)
        
        PartManager.save(song: newSong, partName: "Chorus 2", hasLyrics: false)
        
        PartManager.save(song: newSong, partName: "Bridge", hasLyrics: false)
        
        PartManager.save(song: newSong, partName: "Chorus 3", hasLyrics: false)
        
        PartManager.save(song: newSong, partName: "Outro", hasLyrics: false)
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
    
    func reloadSongTable() {
        
        songs = SongManager.fetchAll()
        
        DispatchQueue.main.async {
            self.songTable.reloadData()
        }
    }
}

