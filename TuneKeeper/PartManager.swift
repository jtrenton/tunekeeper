//
//  PartManager.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 9/2/17.
//  Copyright © 2017 Jeffrey Crace. All rights reserved.
//

import Foundation
import CoreData

class PartManager {
    
    static func save(song: Song, partName: String, hasLyrics: Bool) {
        
        let partsSet = song.mutableSetValue(forKey: "parts")
        let parts = partsSet.allObjects as! [Part]
        
        let part:Part = NSEntityDescription.insertNewObject(forEntityName: "Part", into: DatabaseController.persistentContainer.viewContext) as! Part
        
        part.id = Int16(parts.count)
        
        part.name = partName
        
        part.hasLyrics = hasLyrics
        
        part.song = song
        
        DatabaseController.saveContext()

    }
    
    static func fetchById(partId: Int) -> Part? {
        let fetchRequest:NSFetchRequest<Part> = Part.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "id == %d", partId)
        
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
