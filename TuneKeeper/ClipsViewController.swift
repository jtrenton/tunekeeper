//
//  ClipsViewController.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 5/14/17.
//  Copyright © 2017 Jeffrey Crace. All rights reserved.
//

import UIKit
import CoreData

class ClipsViewController: UIViewController {
    
    var partIdToBeReceived:Int16?
    var part:Part?
    var song:Song?

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

}
