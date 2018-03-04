//
//  ClipsViewController.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 5/14/17.
//  Copyright © 2017 Jeffrey Crace. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation

class ClipsViewController: UIViewController {
    
    let fileExtension = ".m4a"
    var fileName = ""
    var secondFileName = ""
    var mergedFileName = ""
    var trimmedFileName = ""
    
    var existsTwoFiles = false
    
    var recorder: AVAudioRecorder!
    var player: AVAudioPlayer!
    
    var partIdToBeReceived: Int16?
    var part: Part?
    var song: Song?
    var recordings = [URL]()
    
    var meterTimer: Timer!
    
    var firstSoundFileUrl: URL!
    var secondSoundFileUrl: URL!
    var mergedSoundFileUrl: URL!
    var trimmedSoundFileUrl: URL!
    var songClipsDirectory: URL!
    
    @IBOutlet weak var clipTable: UITableView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    
    var recorderState: RecorderState?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backButton: UIBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(back))
        self.navigationItem.leftBarButtonItem = backButton
        
        let index = Int(partIdToBeReceived!)

        let partsSet = song?.parts
        var parts = partsSet?.allObjects as! [Part]
        parts = parts.sorted(by: {$0.id < $1.id})
        
        part = parts[index]

        self.title = part?.name
        
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        fileName = "\(part!.name ?? "partName")-\(format.string(from: Date()))"
        
        fileName = fileName + fileExtension
        secondFileName = fileName + "-2" + fileExtension
        mergedFileName = fileName + "-merged" + fileExtension
        trimmedFileName = fileName + "-trimmed" + fileExtension

        recordButton.isEnabled = true
        playButton.isEnabled = false
        setSessionPlayback()
        
        let folderName = "\(song!.name!)/\(part!.name!)"
        
        songClipsDirectory = URL.createFolder(folderName: folderName)
        
        self.firstSoundFileUrl = songClipsDirectory.appendingPathComponent(fileName)
        self.secondSoundFileUrl = songClipsDirectory.appendingPathComponent(secondFileName)
        self.mergedSoundFileUrl = songClipsDirectory.appendingPathComponent(mergedFileName)
        
        recordings = fetchRecordings()
        
        recorderState = RecorderState.startup
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPlayClip" {
            if let indexPath = self.clipTable.indexPathForSelectedRow {
                let navController:UINavigationController = segue.destination as! UINavigationController
                let controller = navController.topViewController as! PlayClipViewController
                controller.soundFileURLToBeReceived = recordings[indexPath.row]
            }
        }
    }
    
    @objc func back() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didTouchRecordButton(_ sender: UIButton) {
        
        if recorderState == RecorderState.startup {
            recordButton.setTitle("Stop", for: .normal)
            recordWithPermission()
            recorderState = RecorderState.initialRecording
        }
        else if recorderState == RecorderState.initialRecording {
            playButton.isEnabled = true
            recordButton.setTitle("Record", for: .normal)
            recorder.pause()
            recorderState = RecorderState.pausedRecording
        }
        else if recorderState == RecorderState.pausedRecording {
            playButton.isEnabled = false
            recordButton.setTitle("Stop", for: .normal)
            recordWithPermission()
            recorderState = RecorderState.resumedRecording
        }
        else if recorderState == RecorderState.stoppedPlaying {
            playButton.isEnabled = false
            recordButton.setTitle("Stop", for: .normal)
            //Start new recording
            recorderState = RecorderState.initialRecording
        }
        else if recorderState == RecorderState.pausedPlaying {
            trimFile()
            playButton.isEnabled = false
            recordButton.setTitle("Stop", for: .normal)
            recorderState = RecorderState.resumedRecording
        }
        
    }
    
    @IBAction func didTouchPlayButton(_ sender: UIButton) {
        
        if recorderState == RecorderState.pausedRecording {
            
            playButton.setTitle("Pause", for: .normal)
            recordButton.isEnabled = false
            recorderState = RecorderState.initialPlaying
            
            if existsTwoFiles {
                mergeFiles(){
                    self.setupPlayer()
                    self.player.play()
                }
            }
            else {
                setupPlayer()
                player.play()
            }
        }
        else if recorderState == RecorderState.initialPlaying {
            playButton.setTitle("Play", for: .normal)
            recordButton.isEnabled = true
            player.pause()
            recorderState = RecorderState.pausedPlaying
        }
        else if recorderState == RecorderState.pausedPlaying {
            playButton.setTitle("Pause", for: .normal)
            recordButton.isEnabled = false
            player.play()
            recorderState = RecorderState.resumedPlaying
        }
    }
    
    func setupPlayer() {

        let url = self.recorder.url
        
        do {
            self.player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.volume = 1.0
        } catch {
            self.player = nil
            print(error.localizedDescription)
        }
        
    }
    
    @IBAction func didTouchSaveButton(_ sender: UIButton) {
    }
    
    @IBAction func didTouchDeleteButton(_ sender: UIButton) {
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
    
    func recordWithPermission() {
        
        AVAudioSession.sharedInstance().requestRecordPermission() {
            [unowned self] granted in
            if granted {
                
                DispatchQueue.main.async {
                    self.setSessionPlayAndRecord()
                    if self.recorderState == RecorderState.initialRecording {
                        self.setupRecorder(soundFileUrl: self.firstSoundFileUrl)
                    }
                    else if self.recorderState == RecorderState.pausedPlaying {
                        self.setupRecorder(soundFileUrl: self.secondSoundFileUrl)
                    }
                    self.recorder.record()
                    self.meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                                           target:self,
                                                           selector:#selector(self.updateAudioMeter(_:)),
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
    
    @objc func updateAudioMeter(_ timer:Timer) {
        
        if let recorder = self.recorder {
            if recorder.isRecording {
                let min = Int(recorder.currentTime / 60)
                let sec = Int(recorder.currentTime.truncatingRemainder(dividingBy: 60))
                let timeAsString = String(format: "%02d:%02d", min, sec)
                progressLabel.text = timeAsString
                recorder.updateMeters()
                // if you want to draw some graphics...
                //var apc0 = recorder.averagePowerForChannel(0)
                //var peak0 = recorder.peakPowerForChannel(0)
            }
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
        
        if FileManager.default.fileExists(atPath: firstSoundFileUrl.absoluteString) {
            // probably won't happen. want to do something about it?
            print("soundfile \(firstSoundFileUrl.absoluteString) exists")
        }
        
        let recordSettings:[String : Any] = [
            AVFormatIDKey:             kAudioFormatAppleLossless,
            AVEncoderAudioQualityKey:  AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey :      32000,
            AVNumberOfChannelsKey:     2,
            AVSampleRateKey :          44100.0
        ]
        
        do {
            recorder = try AVAudioRecorder(url: firstSoundFileUrl, settings: recordSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord() // creates/overwrites the file at soundFileURL
        } catch {
            recorder = nil
            print(error.localizedDescription)
        }
        
    }
    
    func trimFile(){

        let asset = AVAsset(url: self.firstSoundFileUrl)
        
        let endOfClip = player?.currentTime
        
        player?.stop()
        
        if let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) {
            exporter.outputFileType = AVFileType.m4a
            exporter.outputURL = trimmedSoundFileUrl

            let startTime = CMTime(seconds: 0, preferredTimescale: 1000)
            let stopTime = CMTime(seconds: endOfClip!, preferredTimescale: 1000)
            exporter.timeRange = CMTimeRange(start: startTime, duration: stopTime)

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
                            try FileManager.default.moveItem(at: self.trimmedSoundFileUrl, to: self.firstSoundFileUrl)
                        }
                        catch {
                            
                    }
                }
            })
        } else {
            print("cannot create AVAssetExportSession for asset \(asset)")
        }
        
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
        let timeRange2 = CMTimeRangeMake(duration1, duration2)
        
        try! compositionAudioTrack1.insertTimeRange(timeRange1, of: assetTrack1, at: kCMTimeZero)
        try! compositionAudioTrack2.insertTimeRange(timeRange2, of: assetTrack2, at: duration1)
        
        let assetExport = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
        assetExport?.outputFileType =  AVFileType.m4a
        assetExport?.outputURL = mergedSoundFileUrl
        assetExport?.exportAsynchronously(completionHandler: {
            
            do {
                try FileManager.default.moveItem(at: self.mergedSoundFileUrl, to: self.firstSoundFileUrl)
                completionHandler()
            }
            catch {
                
            }

        })
        
    }

    
    func fetchRecordings() -> [URL] {
        var recordings = [URL]()
        do {
            recordings = try FileManager.default.contentsOfDirectory(at: songClipsDirectory,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
        } catch {
            print(error.localizedDescription)
            print("something went wrong listing recordings")
        }
        
        return recordings
    }
    
}

extension ClipsViewController : AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {

//        stopButton.isEnabled = false
//        playButton.isEnabled = true
//        recordButton.setTitle("Record", for:UIControlState())
//
//        // iOS8 and later
//        let alert = UIAlertController(title: "Finished Recording",
//                                      message: "Is it a keeper?",
//                                      preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: {action in
//            self.recorder = nil
//            self.recordings = self.fetchRecordings()
//            self.clipTable.reloadData()
//        }))
//        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: {action in
//            self.recorder.deleteRecording()
//            self.playButton.isEnabled = false;
//            self.progressLabel.text = "00:00"
//        }))
//        self.present(alert, animated:true, completion:nil)
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        
        if let e = error {
            print("\(e.localizedDescription)")
        }
    }
    
}

// MARK: AVAudioPlayerDelegate
extension ClipsViewController : AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {

        recordButton.isEnabled = true
        playButton.setTitle("Play", for: .normal)
        recorderState = RecorderState.stoppedPlaying
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        
        if let e = error {
            print("\(e.localizedDescription)")
        }
        
    }
}

extension ClipsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        cell.textLabel?.text = recordings[indexPath.row].lastPathComponent.fileName()
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "showPlayClip", sender: self)
    }
    
}

extension URL {
    static func createFolder(folderName: String) -> URL? {
        let fileManager = FileManager.default
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentDirectory.appendingPathComponent(folderName)
        if !fileManager.fileExists(atPath: filePath.path) {
            do {
                try fileManager.createDirectory(atPath: filePath.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
                return nil
            }
        }
        return filePath
    }
}

public enum RecorderState {
    case startup
    case initialRecording
    case resumedRecording
    case pausedRecording
    case initialPlaying
    case resumedPlaying
    case pausedPlaying
    case stoppedPlaying
}
