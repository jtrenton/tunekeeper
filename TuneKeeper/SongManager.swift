//
//  SongManager.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 9/2/17.
//  Copyright © 2017 Jeffrey Crace. All rights reserved.
//

import Foundation
import CoreData

class SongManager {
    
    static func fetchAll() -> [Song] {
        
        var songs:[Song] = []
        
        let fetchRequest:NSFetchRequest<Song> = Song.fetchRequest()
        
        songs = try! DatabaseController.getContext().fetch(fetchRequest)

        return songs
    }
    
    static func save(songName: String) throws -> Song {
        
        if songName.isEmpty {
            throw SongManagerError.emptySongTitle
        }
        
        try checkForDupeSongNames(songName: songName)
        
        let newSong:Song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: DatabaseController.persistentContainer.viewContext) as! Song
        
        newSong.name = songName
        
        newSong.partsCount = 0
        
        DatabaseController.saveContext()
        
        return newSong
        
    }
    
    static func checkForDupeSongNames(songName: String) throws{
        
        let fetchRequest:NSFetchRequest<Song> = Song.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "name == %@", songName)
        
        let songsWithDupeNames = try! DatabaseController.getContext().fetch(fetchRequest)
            
        if !songsWithDupeNames.isEmpty {
            throw SongManagerError.duplicateSong
        }
    }
    
    enum SongManagerError: Error {
        case duplicateSong
        case emptySongTitle
    }
    
}


