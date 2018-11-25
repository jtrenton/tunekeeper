//
//  Recorder.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 11/24/18.
//  Copyright © 2018 Jeffrey Crace. All rights reserved.
//

import Foundation
import AVFoundation

class RecordingManager: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    
    let fileExtension = ".m4a"
    var fileName = ""
    var secondFileName = ""
    var mergedFileName = ""
    var trimmedFileName = ""
    
    var existsTwoFiles = false
    
    var recorderState: RecorderState?
    
    var recorder: AVAudioRecorder!
    var player: AVAudioPlayer!
    
    var currentMeterMin = 0
    var currentMeterSec = 0
    
    var firstSoundFileUrl: URL!
    var secondSoundFileUrl: URL!
    var mergedSoundFileUrl: URL!
    var trimmedSoundFileUrl: URL!
    
    var songClipsDirectory: URL!
    
    var audioDelegate: AudioDelegate?
    
    init(audioDelegate: AudioDelegate, songClipsDirectory: URL) {
        super.init()
        self.audioDelegate = audioDelegate
        self.songClipsDirectory = songClipsDirectory
        setSessionPlayback()
        prepareForInitialRecording()
    }
    
    func setSessionPlayback() {
        
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(AVAudioSessionCategoryPlayback, with: .defaultToSpeaker)
            
        } catch {
            print("Something went wrong with setting session category.")
            print(error.localizedDescription)
        }
        
        do {
            try session.setActive(true)
        } catch {
            print("Something went wrong with setting session to active.")
            print(error.localizedDescription)
        }
    }
    
    func prepareForInitialRecording() {
        prepareFilesAndURLs()
        resetRecorderState()
        
        existsTwoFiles = false
        
        currentMeterMin = 0
        currentMeterSec = 0
        
        audioDelegate?.updateFileNameTextField(value: self.fileName.replacingOccurrences(of: self.fileExtension, with: ""))
        audioDelegate?.updateAudioProgressSlider(value: 0.0)
        audioDelegate?.updateProgressLabel(value: "00:00")
        audioDelegate?.updateNegProgressLabel(value: "-00:00")
        
    }
    
    func prepareFilesAndURLs() {
        let format = DateFormatter()
        format.dateFormat = "MM-dd-yy|HH:mm:ss.SSSS"
        fileName = "\(format.string(from: Date()))"
        
        secondFileName = fileName + "-2" + fileExtension
        mergedFileName = fileName + "-merged" + fileExtension
        trimmedFileName = fileName + "-trimmed" + fileExtension
        fileName = fileName + fileExtension
        
        firstSoundFileUrl = songClipsDirectory.appendingPathComponent(fileName)
        secondSoundFileUrl = songClipsDirectory.appendingPathComponent(secondFileName)
        mergedSoundFileUrl = songClipsDirectory.appendingPathComponent(mergedFileName)
        trimmedSoundFileUrl = songClipsDirectory.appendingPathComponent(trimmedFileName)
    }
    
    func resetRecorderState() {
        recorderState = RecorderState.stoppedPlaying
        audioDelegate?.resetButtons()
    }
    
    func movedSliderTo(position: Float){
        if recorderState == .playing {
            
        }
        else if recorderState == .pausedPlaying {
            
        }
    }
    
    func done(completionHandler: @escaping()->()){
        recorder?.stop()
        player?.stop()
        
        if existsTwoFiles {
            mergeFiles {
                completionHandler()
            }
        }
        else {
            completionHandler()
        }
    }
    
    func saveCurrentRecording(){
        if recorderState == .pausedPlaying || recorderState == .stoppedPlaying || recorderState == .pausedRecording {
            if existsTwoFiles {
                mergeFiles(){
                    self.existsTwoFiles = false
                    self.prepareForInitialRecording()
                    self.currentMeterMin = 0
                    self.currentMeterSec = 0
                    self.audioDelegate?.refreshClips()
                }
            }
            else {
                self.prepareForInitialRecording()
                self.currentMeterMin = 0
                self.currentMeterSec = 0
                self.audioDelegate?.refreshClips()
            }
        }
    }
    
    func deleteCurrentRecording() {
        
        do {
            try FileManager.default.removeItem(at: firstSoundFileUrl)
            
            if existsTwoFiles {
                try FileManager.default.removeItem(at: secondSoundFileUrl)
            }
        }
        catch {
            print("Error occurred deleting first and/or second sound files: \(error)")
        }
        
        prepareForInitialRecording()
    }
    
    func mergeFiles(completionHandler: @escaping ()->()) {
        
        let composition = AVMutableComposition()
        
        let compositionAudioTrack1:AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        let compositionAudioTrack2:AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        
        let avAsset1 = AVURLAsset(url: firstSoundFileUrl as URL, options: nil)
        let avAsset2 = AVURLAsset(url: secondSoundFileUrl as URL, options: nil)
        
        let tracks1 =  avAsset1.tracks(withMediaType: AVMediaType.audio)
        let tracks2 =  avAsset2.tracks(withMediaType: AVMediaType.audio)
        
        let assetTrack1:AVAssetTrack = tracks1[0]
        let assetTrack2:AVAssetTrack = tracks2[0]
        
        let duration1: CMTime = assetTrack1.timeRange.duration
        let duration2: CMTime = assetTrack2.timeRange.duration
        
        let timeRange1 = CMTimeRangeMake(kCMTimeZero, duration1)
        let timeRange2 = CMTimeRangeMake(kCMTimeZero, duration2)
        
        try! compositionAudioTrack1.insertTimeRange(timeRange1, of: assetTrack1, at: kCMTimeZero)
        try! compositionAudioTrack2.insertTimeRange(timeRange2, of: assetTrack2, at: duration1)
        
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
        exporter?.outputFileType =  AVFileType.m4a
        exporter?.outputURL = mergedSoundFileUrl
        exporter?.exportAsynchronously(completionHandler: {
            
            switch exporter!.status {
            case  AVAssetExportSessionStatus.failed:
                if let e = exporter!.error {
                    print("export failed \(e)")
                }
            case AVAssetExportSessionStatus.cancelled:
                print("export cancelled \(String(describing: exporter!.error))")
            default:
                do {
                    try FileManager.default.removeItem(at: self.firstSoundFileUrl)
                    try FileManager.default.removeItem(at: self.secondSoundFileUrl)
                    try FileManager.default.moveItem(at: self.mergedSoundFileUrl, to: self.firstSoundFileUrl)
                    completionHandler()
                }
                catch {
                    print(error)
                }
            }
        })
    }
    
    func record(){
        
        if recorderState ==  .stoppedPlaying {
            currentMeterMin = 0
            currentMeterSec = 0
            audioDelegate?.enablePlayButton(bool: false)
            audioDelegate?.setTitleOnRecordButton(title: "Stop")
            self.recorderState = RecorderState.recording
            audioDelegate?.enableAudioProgressSlider(bool: false)
            recordWithPermission()
        }
        else if recorderState == .recording || recorderState == .resumedRecording {
            audioDelegate?.enablePlayButton(bool: true)
            audioDelegate?.setTitleOnRecordButton(title: "Rec")
            recorder.pause()
            self.recorderState = RecorderState.pausedRecording
        }
        else if recorderState == .pausedRecording {
            audioDelegate?.enablePlayButton(bool: false)
            audioDelegate?.setTitleOnRecordButton(title: "Stop")
            self.recorderState = RecorderState.recording
            recorder.record()
        }
        else if recorderState == .pausedPlaying {
            currentMeterMin = Int(player.currentTime / 60)
            currentMeterSec = Int(player.currentTime.truncatingRemainder(dividingBy: 60))
            trimFile(){
                self.audioDelegate?.enablePlayButton(bool: false)
                self.audioDelegate?.setTitleOnRecordButton(title: "Stop")
                self.audioDelegate?.enableAudioProgressSlider(bool: false)
                self.recorderState = RecorderState.resumedRecording
                self.recordWithPermission()
            }
        }
        else if recorderState == RecorderState.playing {
            audioDelegate?.setPlayButtonImageToPlay()
            player.pause()
            
            currentMeterMin = Int(player.currentTime / 60)
            currentMeterSec = Int(player.currentTime.truncatingRemainder(dividingBy: 60))
            
            trimFile(){
                self.audioDelegate?.enablePlayButton(bool: false)
                self.audioDelegate?.setTitleOnRecordButton(title: "Stop")
                self.audioDelegate?.enableAudioProgressSlider(bool: false)
                self.recorderState = RecorderState.resumedRecording
                self.recordWithPermission()
            }
        }
    }
    
    func play() {
        if recorderState == RecorderState.pausedRecording {
            currentMeterMin = 0
            currentMeterSec = 0
            audioDelegate?.updateAudioProgressSlider(value: 0.0)
            recorder.stop()
            audioDelegate?.setPlayButtonImageToPause()
            recorderState = RecorderState.playing
            audioDelegate?.enableAudioProgressSlider(bool: true)
            
            if existsTwoFiles {
                mergeFiles(){
                    self.existsTwoFiles = false
                    self.play(atTime: nil)
                }
            }
            else {
                play(atTime: nil)
            }
        }
        else if recorderState == RecorderState.playing {
            audioDelegate?.setPlayButtonImageToPlay()
            player.pause()
            recorderState = RecorderState.pausedPlaying
        }
        else if recorderState == RecorderState.pausedPlaying || recorderState == RecorderState.stoppedPlaying {
            audioDelegate?.setPlayButtonImageToPause()
            player.play()
            recorderState = RecorderState.playing
            audioDelegate?.enableAudioProgressSlider(bool: true)
        }
    }
    
    func play(atTime time:TimeInterval?) {
        do {
            player = try AVAudioPlayer(contentsOf: firstSoundFileUrl)
            player.delegate = self
            player.volume = 1.0
        } catch {
            player = nil
            print(error.localizedDescription)
        }
        
        if let timeInterval = time {
            player.play(atTime: timeInterval)
        }
        else {
            player.play()
        }
        Timer.scheduledTimer(timeInterval: 0.1,
                             target:self,
                             selector:#selector(self.updateMeterDuringPlaying(_:)),
                             userInfo:nil,
                             repeats:true)
    }
    
    @objc func updateMeterDuringPlaying(_ timer: Timer){
        if let player = self.player {
            if player.isPlaying {
                
                let min = Int(player.currentTime / 60) + currentMeterMin
                let sec = Int(player.currentTime.truncatingRemainder(dividingBy: 60)) + currentMeterSec
                let timeAsString = String(format: "%02d:%02d", min, sec)
                audioDelegate?.updateProgressLabel(value: timeAsString)
                
                let durationMin = Int(player.duration / 60) - min
                let durationSec = Int(player.duration.truncatingRemainder(dividingBy: 60)) - sec
                let durationAsString = String(format: "-%02d:%02d", durationMin, durationSec)
                audioDelegate?.updateNegProgressLabel(value: durationAsString)
                
                audioDelegate?.updateAudioProgressSlider(value: (Float(player.currentTime / player.duration) * 100) + 2)
                
                player.updateMeters()
            }
        }
    }
    
    func recordWithPermission() {
        
        AVAudioSession.sharedInstance().requestRecordPermission() {
            [unowned self] granted in
            if granted {
                
                DispatchQueue.main.async {
                    self.audioDelegate?.updateNegProgressLabel(value: "-00:00")
                    self.audioDelegate?.updateAudioProgressSlider(value: 0.0)
                    self.setSessionPlayAndRecord()
                    if self.recorderState == RecorderState.recording {
                        self.setupRecorder(soundFileUrl: self.firstSoundFileUrl)
                    }
                    else if self.recorderState == RecorderState.resumedRecording {
                        self.setupRecorder(soundFileUrl: self.secondSoundFileUrl)
                        self.existsTwoFiles = true
                    }
                    self.recorder.record()
                    Timer.scheduledTimer(timeInterval: 0.1,
                                         target:self,
                                         selector:#selector(self.updateMeterDuringRecording(_:)),
                                         userInfo:nil,
                                         repeats:true)
                }
            } else {
                print("Permission to record not granted")
            }
        }
        
        if AVAudioSession.sharedInstance().recordPermission() == .denied {
            print("permission denied")
        }
    }
    
    func trimFile(completionHandler: @escaping ()->()){
        
        let asset = AVAsset(url: self.firstSoundFileUrl)
        let endOfClip = player?.currentTime
        
        player?.stop()
        
        if let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) {
            exporter.outputFileType = AVFileType.m4a
            exporter.outputURL = trimmedSoundFileUrl
            
            let startTime = CMTime(seconds: 0.0, preferredTimescale: 1000)
            let stopTime = CMTime(seconds: endOfClip!, preferredTimescale: 1000)
            let timeRange = CMTimeRange(start: startTime, duration: stopTime)
            exporter.timeRange = timeRange
            
            exporter.exportAsynchronously(completionHandler: {
                
                switch exporter.status {
                case  AVAssetExportSessionStatus.failed:
                    if let e = exporter.error {
                        print("export failed \(e)")
                    }
                case AVAssetExportSessionStatus.cancelled:
                    print("export cancelled \(String(describing: exporter.error))")
                default:
                    do {
                        try FileManager.default.removeItem(at: self.firstSoundFileUrl)
                        try FileManager.default.moveItem(at: self.trimmedSoundFileUrl, to: self.firstSoundFileUrl)
                        completionHandler()
                    }
                    catch {
                        print(error)
                    }
                }
            })
        } else {
            print("cannot create AVAssetExportSession for asset \(asset)")
        }
        
    }
    
    func setSessionPlayAndRecord() {
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        } catch {
            print("Something went wrong setting session category to PlayAndRecord.")
            print(error.localizedDescription)
        }
        
        do {
            try session.setActive(true)
        } catch {
            print("Something went wrong setting session to active.")
            print(error.localizedDescription)
        }
    }
    
    func setupRecorder(soundFileUrl: URL) {
        
        let recordSettings:[String : Any] = [
            AVFormatIDKey:             kAudioFormatAppleLossless,
            AVEncoderAudioQualityKey:  AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey :      320000,
            AVNumberOfChannelsKey:     2,
            AVSampleRateKey :          44100.0
        ]
        
        do {
            recorder = try AVAudioRecorder(url: soundFileUrl, settings: recordSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
        } catch {
            recorder = nil
            print(error.localizedDescription)
        }
        
    }
    
    @objc func updateMeterDuringRecording(_ timer: Timer) {
        if let recorder = self.recorder {
            if recorder.isRecording {
                let min = Int(recorder.currentTime / 60) + currentMeterMin
                let sec = Int(recorder.currentTime.truncatingRemainder(dividingBy: 60)) + currentMeterSec
                let timeAsString = String(format: "%02d:%02d", min, sec)
                audioDelegate?.updateProgressLabel(value: timeAsString)
                recorder.updateMeters()
            }
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        currentMeterMin = 0
        currentMeterSec = 0
        audioDelegate?.setPlayButtonImageToPlay()
        recorderState = RecorderState.stoppedPlaying
    }
    
}

