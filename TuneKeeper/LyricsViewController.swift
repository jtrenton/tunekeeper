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
        
        self.title = parts[index].name
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func doneBtnClicked() {
        
        if lyricsTextView.text != nil && !lyricsTextView.text.isEmpty {

            part?.lyrics = lyricsTextView.text
            DatabaseController.saveContext()
        }
        
        self.dismiss(animated: true, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    func fetchPart() -> Part? {

        let fetchRequest:NSFetchRequest<Part> = Part.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "id == %d", partIdToBeReceived!)
        
        do {
            let parts = try DatabaseController.getContext().fetch(fetchRequest)
            
            if !parts.isEmpty {
                return parts[0]
            }

        }
        catch {
            
        }
        
        return nil
    }

}
