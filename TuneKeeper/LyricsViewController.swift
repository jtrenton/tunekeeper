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
    
    @IBOutlet weak var lyricsTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        part = fetchPart()
        
        if part != nil {
            self.title = part?.name
            
            lyricsTextView.text = part?.lyrics
        }

        // Do any additional setup after loading the view.
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
