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
    
    var recorder: AVAudioRecorder!
    var player: AVAudioPlayer!
    
    var partIdToBeReceived: Int16?
    var part: Part?
    var song: Song?
    var recordings = [URL]()
    
    var meterTimer: Timer!
    
    var soundFileURL: URL!
    var songClipsDirectory: URL!
    
    @IBOutlet weak var clipTable: UITableView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
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

        recordButton.isEnabled = true
        playButton.isEnabled = false
        setSessionPlayback()
        
        let folderName = "\(song!.name!)/\(part!.name!)"
        
        songClipsDirectory = URL.createFolder(folderName: folderName)
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
            recorderState = RecorderState.paused
        }
        else if recorderState == RecorderState.paused {
            playButton.isEnabled = false
            recordButton.setTitle("Stop", for: .normal)
            recordWithPermission()
            recorderState = RecorderState.resumedRecording
        }
        
        
    }
    
    @IBAction func didTouchPlayButton(_ sender: UIButton) {
        
        if recorderState == RecorderState.paused {
            playButton.setTitle("Pause", for: .normal)
            recordButton.isEnabled = false
            setupPlayer()
            player.play()
            recorderState = RecorderState.initialPlaying
        }
        else if recorderState == RecorderState.initialPlaying {
            playButton.setTitle("Play", for: .normal)
            recordButton.isEnabled = true
            player.pause()
            recorderState = RecorderState.paused
        }
        else if recorderState == RecorderState.paused {
            playButton.setTitle("Pause", for: .normal)
            recordButton.isEnabled = false
            player.play()
            recorderState = RecorderState.initialPlaying
        }
    }
    
    func setupPlayer() {

        let url = self.recorder.url
        
        do {
            self.player = try AVAudioPlayer(contentsOf: url)
            stopButton.isEnabled = true
            player.delegate = self
            player.prepareToPlay()
            player.volume = 1.0
        } catch {
            self.player = nil
            print(error.localizedDescription)
        }
        
    }
    
    @IBAction func didTouchStopButton(_ sender: UIButton) {
        
        if (recorder != nil && recorder.isRecording){
            
        }
        
        recorder?.stop()
        player?.stop()
        
        meterTimer.invalidate()
        
        recordButton.setTitle("Record", for: .normal)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
            playButton.isEnabled = true
            stopButton.isEnabled = false
            recordButton.isEnabled = true
        } catch {
            print("could not make session inactive")
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
                        self.setupRecorder()
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
    
    func setupRecorder() {
        
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let partName = part!.name
        let currentFileName = "\(partName ?? "partName")-\(format.string(from: Date())).m4a"

        self.soundFileURL = songClipsDirectory.appendingPathComponent(currentFileName)
        
        if FileManager.default.fileExists(atPath: soundFileURL.absoluteString) {
            // probably won't happen. want to do something about it?
            print("soundfile \(soundFileURL.absoluteString) exists")
        }
        
        let recordSettings:[String : Any] = [
            AVFormatIDKey:             kAudioFormatAppleLossless,
            AVEncoderAudioQualityKey:  AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey :      32000,
            AVNumberOfChannelsKey:     2,
            AVSampleRateKey :          44100.0
        ]
        
        do {
            recorder = try AVAudioRecorder(url: soundFileURL, settings: recordSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord() // creates/overwrites the file at soundFileURL
        } catch {
            recorder = nil
            print(error.localizedDescription)
        }
        
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

        stopButton.isEnabled = false
        playButton.isEnabled = true
        recordButton.setTitle("Record", for:UIControlState())
        
        // iOS8 and later
        let alert = UIAlertController(title: "Finished Recording",
                                      message: "Is it a keeper?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: {action in
            self.recorder = nil
            self.recordings = self.fetchRecordings()
            self.clipTable.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: {action in
            self.recorder.deleteRecording()
            self.playButton.isEnabled = false;
            self.progressLabel.text = "00:00"
        }))
        self.present(alert, animated:true, completion:nil)
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
        print("\(#function)")
        
        print("finished playing \(flag)")
        recordButton.isEnabled = true
        stopButton.isEnabled = false
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("\(#function)")
        
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
    case paused
    case initialPlaying
    case resumedPlaying
}
