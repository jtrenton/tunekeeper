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
        let sort = NSSortDescriptor(key: #keyPath(Song.name), ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare))
        fetchRequest.sortDescriptors = [sort]
        
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
    
    static func addDefaultPartsToSong(newSong: Song){
        
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
    
    enum SongManagerError: Error {
        case duplicateSong
        case emptySongTitle
    }
    
}


