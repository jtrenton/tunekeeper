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
        
        do {
            songs = try DatabaseController.getContext().fetch(fetchRequest)
        }
        catch {
            fatalError("TuneKeeper encountered an error fetching all songs in a sorted list -- \(error.localizedDescription)")
        }
        
        songs = songs.sorted(by: {$0.name! < $1.name!})

        return songs
    }
    
    static func fetchSong(songName: String) -> Song? {
        
        let fetchRequest:NSFetchRequest<Song> = Song.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "name == %@", songName)
        
        do {
            let songs = try DatabaseController.getContext().fetch(fetchRequest)
            
            if !songs.isEmpty {
                return songs[0]
            }
            else {
                //Fatal error, throw exception from here
            }
        }
        catch {
            print("Failed to get context for container")
        }
        
        return nil
    }
    
    static func save(songName: String) throws -> Song {
        
        try checkForDupeSongNames(songName: songName)
        
        let newSong:Song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: DatabaseController.persistentContainer.viewContext) as! Song
        
        newSong.name = songName
        
        DatabaseController.saveContext()
        
        return newSong
    }
    
    static func checkForDupeSongNames(songName: String) throws {
        
        let fetchRequest:NSFetchRequest<Song> = Song.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "name == %@", songName)
        
        do {
            let songsWithDupeNames = try DatabaseController.getContext().fetch(fetchRequest)
            if !songsWithDupeNames.isEmpty {
                throw SongManagerError.duplicateSong
            }
        }
        catch {
            fatalError("TuneKeeper error occurred fetching songs to check for duplicate titles -- \(error.localizedDescription)")
        }
    }
    
    static func addDefaultPartsToSong(newSong: Song) throws {
        try PartManager.save(song: newSong, partName: "Lyrics", hasLyrics: true)
        try PartManager.save(song: newSong, partName: "Intro", hasLyrics: false)
        try PartManager.save(song: newSong, partName: "Verse 1", hasLyrics: false)
        try PartManager.save(song: newSong, partName: "Chorus 1", hasLyrics: false)
        try PartManager.save(song: newSong, partName: "Verse 2", hasLyrics: false)
        try PartManager.save(song: newSong, partName: "Chorus 2", hasLyrics: false)
        try PartManager.save(song: newSong, partName: "Bridge", hasLyrics: false)
        try PartManager.save(song: newSong, partName: "Chorus 3", hasLyrics: false)
        try PartManager.save(song: newSong, partName: "Outro", hasLyrics: false)
        DatabaseController.saveContext()
    }
    
    enum SongManagerError: Error {
        case duplicateSong
    }
}


