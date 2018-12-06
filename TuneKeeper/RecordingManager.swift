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
    let secondSoundFileName = "second.m4a"
    
    var existsTwoFiles = false
    
    var recorderState: RecorderState?
    
    var recorder: AVAudioRecorder!
    var player: AVAudioPlayer!
    
    var currentMeterMin = 0
    var currentMeterSec = 0
    
    var currentSoundFileUrl: URL!
    
    var songClipsDirectory: URL!
    
    var audioDelegate: AudioDelegate?
    var playTimer: Timer?
    
    init(audioDelegate: AudioDelegate, songClipsDirectory: URL) {
        super.init()
        self.audioDelegate = audioDelegate
        self.songClipsDirectory = songClipsDirectory
        recorderState = .startup
        setSessionPlayAndRecord()
        createAudioFile()
        prepareForRecording()
    }
    
    func prepareForRecording() {
        
        currentMeterMin = 0
        currentMeterSec = 0
        
        audioDelegate?.enablePlayButton(bool: false)
        audioDelegate?.enableAudioProgressSlider(bool: false)
        
        audioDelegate?.updateAudioProgressSlider(value: 0.0)
        audioDelegate?.updateProgressLabel(value: "00:00")
        audioDelegate?.updateNegProgressLabel(value: "-00:00")
    }
    
    func createAudioFile() {
        let format = DateFormatter()
        format.dateFormat = "MM-dd-yy|HH:mm:ss.SSSS"
        
        var fileName = "\(format.string(from: Date()))"
        fileName = fileName + fileExtension
        currentSoundFileUrl = songClipsDirectory.appendingPathComponent(fileName)
        
        audioDelegate?.updateFileNameTextField(value: fileName.replacingOccurrences(of: self.fileExtension, with: ""))
    }
    
    func done(completionHandler: (()->())?){
        recorder?.stop()
        player?.stop()
        
        if existsTwoFiles {
            mergeFiles {
                completionHandler?()
            }
        }
        else {
            completionHandler?()
        }
    }
    
    func saveCurrentRecording(url: URL?){
        if recorderState == .pausedPlaying || recorderState == .stoppedPlaying || recorderState == .pausedRecording {
            if existsTwoFiles {
                mergeFiles(){
                    self.existsTwoFiles = false
                    self.createAudioFile()
                    self.prepareForRecording()
                    self.recorderState = .startup
                    self.audioDelegate?.refreshClips()
                }
            }
            else {
                createAudioFile()
                prepareForRecording()
                recorderState = .startup
                audioDelegate?.refreshClips()
            }
        }
    }
    
    func deleteCurrentRecording() {
        
        do {
            try FileManager.default.removeItem(at: currentSoundFileUrl)
            
            if existsTwoFiles {
                let secondSoundFileUrl = recorder.url
                try FileManager.default.removeItem(at: secondSoundFileUrl)
                existsTwoFiles = false
            }
        }
        catch {
            print("Error occurred deleting first and/or second sound files: \(error)")
        }
        
        createAudioFile()
        prepareForRecording()
        recorderState = .startup
    }
    
    func recordingButtonPressed(){
        if recorderState == .startup {
            recorderState = RecorderState.recording
            recordWithPermission(url: currentSoundFileUrl)
        }
        else if recorderState ==  .stoppedPlaying {
            prepareForRecording()
            recorderState = RecorderState.recording
            recordWithPermission(url: currentSoundFileUrl)
        }
        else if recorderState == .recording || recorderState == .resumedRecording {
            audioDelegate?.enablePlayButton(bool: true)
            audioDelegate?.setTitleOnRecordButton(title: "Rec")
            recorderState = RecorderState.pausedRecording
            recorder.pause()
        }
        else if recorderState == .pausedRecording {
            audioDelegate?.enablePlayButton(bool: false)
            audioDelegate?.setTitleOnRecordButton(title: "Stop")
            audioDelegate?.enableAudioProgressSlider(bool: false)
            self.recorderState = RecorderState.recording
            recorder.record()
        }
        else if recorderState == .pausedPlaying {
            resumeRecordingAfterPlaying()
        }
        else if recorderState == RecorderState.playing {
            audioDelegate?.setPlayButtonImageToPlay()
            player.pause()
            resumeRecordingAfterPlaying()
        }
    }
    
    func resumeRecordingAfterPlaying() {
        currentMeterMin = Int(player.currentTime / 60)
        currentMeterSec = Int(player.currentTime.truncatingRemainder(dividingBy: 60))
        
        trimFile(){
            self.recorderState = RecorderState.resumedRecording

            self.existsTwoFiles = true
            
            let secondSoundFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(self.secondSoundFileName)
            
            self.recordWithPermission(url: secondSoundFileUrl)
        }
    }
    
    func playButtonPressed() {
        if recorderState == RecorderState.pausedRecording {
            currentMeterMin = 0
            currentMeterSec = 0
            recorder.stop()
            audioDelegate?.setPlayButtonImageToPause()
            recorderState = RecorderState.playing
            audioDelegate?.enableAudioProgressSlider(bool: true)
            
            if existsTwoFiles {
                mergeFiles(){
                    self.existsTwoFiles = false
                    self.play()
                }
            }
            else {
                play()
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
    
    func adjustProgressLabels(value: Float) {
        let duration = player.duration
        let progress = Float(duration) * value / 100.0
        let negProgress = Float(duration) - progress
        
        let progressMin = Int(progress / 60)
        let progressSec = Int(progress.truncatingRemainder(dividingBy: 60))
        let progressTimeAsString = String(format: "%02d:%02d", progressMin, progressSec)
        
        let negProgressMin = Int(negProgress / 60)
        let negProgressSec = Int(negProgress.truncatingRemainder(dividingBy: 60))
        let negProgressTimeAsString = String(format: "-%02d:%02d", negProgressMin, negProgressSec)
        
        audioDelegate?.updateProgressLabel(value: progressTimeAsString)
        audioDelegate?.updateNegProgressLabel(value: negProgressTimeAsString)
    }
    
    func stopPlaying() {
        player.stop()
        playTimer?.invalidate()
    }
    
    func movedSliderTo(position: Float){
        let duration = player.duration
        let playheadPosition = Float(duration) * position / 100.0
        player.currentTime = TimeInterval(playheadPosition)
        
        if recorderState == .playing {
            player.play()
            playTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                             target:self,
                                             selector:#selector(self.updateMeterDuringPlaying(_:)),
                                             userInfo:nil,
                                             repeats:true)
        }
        else if recorderState == .pausedPlaying {
            currentMeterMin = Int(playheadPosition / 60)
            currentMeterSec = Int(playheadPosition.truncatingRemainder(dividingBy: 60))
        }
    }
    
    func playAfterSkipping(to time: TimeInterval?){
        player.currentTime = time!
        player.play()
        playTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                         target:self,
                                         selector:#selector(self.updateMeterDuringPlaying(_:)),
                                         userInfo:nil,
                                         repeats:true)
    }
    
    func play() {
        do {
            player = try AVAudioPlayer(contentsOf: currentSoundFileUrl)
            player.delegate = self
            player.volume = 1.0
        } catch {
            player = nil
            print(error.localizedDescription)
        }
        
        player.play()
        playTimer = Timer.scheduledTimer(timeInterval: 0.1,
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
    
    func recordWithPermission(url: URL) {
        
        AVAudioSession.sharedInstance().requestRecordPermission() {
            [unowned self] granted in
            if granted {
                
                DispatchQueue.main.async {
                    self.audioDelegate?.enablePlayButton(bool: false)
                    self.audioDelegate?.setTitleOnRecordButton(title: "Stop")
                    self.audioDelegate?.enableAudioProgressSlider(bool: false)
                    self.audioDelegate?.resetSlider()
                    self.setupRecorder(soundFileUrl: url)
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
        
        player?.stop()
        
        let trimmedSoundFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent("trimmed.m4a")
        
        let asset = AVAsset(url: self.currentSoundFileUrl)
        let endOfClip = player?.currentTime
        
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
                        try FileManager.default.removeItem(at: self.currentSoundFileUrl)
                        try FileManager.default.moveItem(at: trimmedSoundFileUrl, to: self.currentSoundFileUrl)
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
        audioDelegate?.resetSlider()
        recorderState = RecorderState.stoppedPlaying
    }
    
    func mergeFiles(completionHandler: @escaping ()->()) {
        
        let composition = AVMutableComposition()
        
        let compositionAudioTrack1:AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        let compositionAudioTrack2:AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        
        let avAsset1 = AVURLAsset(url: currentSoundFileUrl, options: nil)
        let avAsset2 = AVURLAsset(url: self.recorder.url, options: nil)
        
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

        let mergedSoundFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent("merged.m4a")
        let secondSoundFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(secondSoundFileName)
        
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
                    try FileManager.default.removeItem(at: self.currentSoundFileUrl)
                    try FileManager.default.removeItem(at: secondSoundFileUrl)
                    try FileManager.default.moveItem(at: mergedSoundFileUrl, to: self.currentSoundFileUrl)
                    completionHandler()
                }
                catch {
                    print(error)
                }
            }
        })
    }
    
}

