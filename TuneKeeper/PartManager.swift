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
        
        let part:Part = NSEntityDescription.insertNewObject(forEntityName: "Part", into: DatabaseController.persistentContainer.viewContext) as! Part
        
        part.id = song.partsCount
        
        song.partsCount = song.partsCount + 1
        
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
