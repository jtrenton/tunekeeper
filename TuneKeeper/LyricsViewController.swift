//
//  LyricsViewController.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 7/15/17.
//  Copyright © 2017 Jeffrey Crace. All rights reserved.
//

import UIKit
import CoreData

class LyricsViewController: UIViewController {
    
    var partIdToBeReceived:Int16?
    var part:Part?
    var song:Song?
    
    @IBOutlet weak var lyricsTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let index = Int(partIdToBeReceived!)
        let partsSet = song?.parts
        var parts = partsSet?.allObjects as! [Part]
        parts = parts.sorted(by: {$0.id < $1.id})
        part = parts[index]
        self.title = part?.name
        lyricsTextView.text = part?.lyrics
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        saveLyrics()
    }
    
    @IBAction func doneBtnClicked() {
        saveLyrics()
        self.dismiss(animated: true, completion: nil)
    }
    
    func saveLyrics() {
        if let lyrics = lyricsTextView.text{
            part?.lyrics = lyrics
            DatabaseController.saveContext()
        }
    }

}
