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

class ClipsViewController: UIViewController, AudioDelegate {
    
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
    
    var currentMeterMin = 0
    var currentMeterSec = 0
    
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
    @IBOutlet weak var fileNameTextField: UITextField!
    @IBOutlet weak var negProgressLabel: UILabel!
    @IBOutlet weak var audioProgressSlider: UISlider!
    
    var recorderState: RecorderState?
    
    var tuneRecorder: Recorder?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backButton: UIBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(back))
        self.navigationItem.leftBarButtonItem = backButton
        
        audioProgressSlider.isContinuous = false
        audioProgressSlider.isEnabled = false
        
        let index = Int(partIdToBeReceived!)

        let partsSet = song?.parts
        var parts = partsSet?.allObjects as! [Part]
        parts = parts.sorted(by: {$0.id < $1.id})
        
        part = parts[index]

        self.title = part?.name

        let folderName = "\(song!.name!)/\(part!.name!)"
        songClipsDirectory = URL.createFolder(folderName: folderName)
        
        fetchRecordings(url: songClipsDirectory)
        
        tuneRecorder = Recorder(audioDelegate: self, songClipsDirectory: songClipsDirectory)
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
    
    func updateSlider(value: Float) {
        audioProgressSlider.value = value
    }
    
    func updateProgressLabel(value: String) {
        progressLabel.text = value
    }
    
    func updateNegProgress(value: String) {
        negProgressLabel.text = value
    }
    
    func updateFileNameTextField(value: String) {
        fileNameTextField.text = value
    }
    
    func enablePlayButton(bool: Bool) {
        DispatchQueue.main.async {
            self.playButton.isEnabled = bool
        }
    }
    
    func setTitleOnRecordButton(title: String) {
        DispatchQueue.main.async {
            self.recordButton.setTitle(title, for: .normal)
        }
    }
    
    func enableAudioProgressSlider(bool: Bool) {
        DispatchQueue.main.async {
            self.audioProgressSlider.isEnabled = bool
        }
    }
    
    func setPlayButtonImageToPlay() {
        DispatchQueue.main.async {
            self.playButton.setImage(#imageLiteral(resourceName: "baseline_play_arrow_black_48pt"), for: .normal)
        }
    }
    
    @objc func back() {
        tuneRecorder?.done {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func didTouchRecordButton(_ sender: UIButton) {
        
        
        if tuneRecorder?.recorderState == .stoppedPlaying {
            tuneRecorder?.set(recorderState: .recording)
        }
        
        if recorderState ==  .stoppedPlaying {
            currentMeterMin = 0
            currentMeterSec = 0
            playButton.isEnabled = false
            recordButton.setTitle("Stop", for: .normal)
            recorderState = RecorderState.recording
            audioProgressSlider.isEnabled = false
            recordWithPermission()
        }
        else if recorderState == .recording || recorderState == .resumedRecording {
            playButton.isEnabled = true
            recordButton.setTitle("Rec", for: .normal)
            recorder.pause()
            recorderState = RecorderState.pausedRecording
        }
        else if recorderState == .pausedRecording {
            playButton.isEnabled = false
            recordButton.setTitle("Stop", for: .normal)
            recorderState = RecorderState.recording
            recorder.record()
        }
        else if recorderState == .pausedPlaying {
            currentMeterMin = Int(player.currentTime / 60)
            currentMeterSec = Int(player.currentTime.truncatingRemainder(dividingBy: 60))
            trimFile(){
                DispatchQueue.main.async {
                    self.playButton.isEnabled = false
                    self.recordButton.setTitle("Stop", for: .normal)
                    self.audioProgressSlider.isEnabled = false
                }
                self.recorderState = RecorderState.resumedRecording
                self.recordWithPermission()
            }
        }
        else if recorderState == RecorderState.playing {
            playButton.setImage(#imageLiteral(resourceName: "baseline_play_arrow_black_48pt"), for: .normal)
            player.pause()
            
            currentMeterMin = Int(player.currentTime / 60)
            currentMeterSec = Int(player.currentTime.truncatingRemainder(dividingBy: 60))
            
            trimFile(){
                DispatchQueue.main.async {
                    self.playButton.isEnabled = false
                    self.recordButton.setTitle("Stop", for: .normal)
                    self.audioProgressSlider.isEnabled = false
                }
                self.recorderState = RecorderState.resumedRecording
                self.recordWithPermission()
            }
        }
    }
    
    @IBAction func didTouchPlayButton(_ sender: UIButton) {
        
        if recorderState == RecorderState.pausedRecording {
            currentMeterMin = 0
            currentMeterSec = 0
            audioProgressSlider.value = 0.0
            recorder.stop()
            playButton.setImage(#imageLiteral(resourceName: "baseline_pause_black_48pt"), for: .normal)
            recorderState = RecorderState.playing
            audioProgressSlider.isEnabled = true
            
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
            playButton.setImage(#imageLiteral(resourceName: "baseline_play_arrow_black_48pt"), for: .normal)
            player.pause()
            recorderState = RecorderState.pausedPlaying
        }
        else if recorderState == RecorderState.pausedPlaying || recorderState == RecorderState.stoppedPlaying {
            playButton.setImage(#imageLiteral(resourceName: "baseline_pause_black_48pt"), for: .normal)
            player.play()
            recorderState = RecorderState.playing
            audioProgressSlider.isEnabled = true
        }
    }
    
    func prepareForInitialRecording() {
        prepareFilesAndURLs()
        resetRecorderState()
        
        DispatchQueue.main.async {
            self.fileNameTextField.text = self.fileName.replacingOccurrences(of: self.fileExtension, with: "")
        }
        
        existsTwoFiles = false
        
        currentMeterMin = 0
        currentMeterSec = 0

        audioProgressSlider.value = 0.0
        progressLabel.text = "00:00"
        negProgressLabel.text = "-00:00"
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
    
    func resetButtons() {
        DispatchQueue.main.async {
            self.recordButton.isEnabled = true
            self.playButton.isEnabled = false
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
        meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                               target:self,
                                               selector:#selector(self.updateMeterDuringPlaying(_:)),
                                               userInfo:nil,
                                               repeats:true)
    }
    
    @IBAction func didTouchSaveButton(_ sender: UIButton) {
        if recorderState == .pausedPlaying || recorderState == .stoppedPlaying {
            fetchRecordings(url: songClipsDirectory)
            clipTable.reloadData()
            prepareForInitialRecording()
        }
        else if recorderState == .pausedRecording {
            if existsTwoFiles {
                mergeFiles(){
                    self.existsTwoFiles = false
                    self.saveCurrentRecording()
                }
            }
            else {
                saveCurrentRecording()
            }
        }
    }
    
    func saveCurrentRecording() {
        fetchRecordings(url: self.songClipsDirectory)
        clipTable.reloadData()
        prepareForInitialRecording()
        currentMeterMin = 0
        currentMeterSec = 0
    }
    
    @IBAction func didTouchDeleteButton(_ sender: UIButton) {
        
        if recorderState == .stoppedPlaying || recorderState == .pausedPlaying || recorderState == .pausedRecording {
            showDeleteRecordingDialog()
        }
    }
    
    func showDeleteRecordingDialog() {
        let alert = UIAlertController(title: nil, message: "Delete current recording? This cannot be undone.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            self.deleteCurrentRecording()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
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
    
    @IBAction func didTouchSlider(_ sender: Any) {
        if recorderState == .playing {
            player.stop()
            player.play(atTime: <#T##TimeInterval#>)
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
    
    func recordWithPermission() {
        
        AVAudioSession.sharedInstance().requestRecordPermission() {
            [unowned self] granted in
            if granted {
                
                DispatchQueue.main.async {
                    self.negProgressLabel.text = "-00:00"
                    self.audioProgressSlider.value = 0.0
                    self.setSessionPlayAndRecord()
                    if self.recorderState == RecorderState.recording {
                        self.setupRecorder(soundFileUrl: self.firstSoundFileUrl)
                    }
                    else if self.recorderState == RecorderState.resumedRecording {
                        self.setupRecorder(soundFileUrl: self.secondSoundFileUrl)
                        self.existsTwoFiles = true
                    }
                    self.recorder.record()
                    self.meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
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
    
    @objc func updateMeterDuringRecording(_ timer: Timer) {
        if let recorder = self.recorder {
            if recorder.isRecording {
                let min = Int(recorder.currentTime / 60) + currentMeterMin
                let sec = Int(recorder.currentTime.truncatingRemainder(dividingBy: 60)) + currentMeterSec
                let timeAsString = String(format: "%02d:%02d", min, sec)
                progressLabel.text = timeAsString
                recorder.updateMeters()
            }
        }
    }
    
    @objc func updateMeterDuringPlaying(_ timer: Timer){
        if let player = self.player {
            if player.isPlaying {
                
                let min = Int(player.currentTime / 60) + currentMeterMin
                let sec = Int(player.currentTime.truncatingRemainder(dividingBy: 60)) + currentMeterSec
                let timeAsString = String(format: "%02d:%02d", min, sec)
                progressLabel.text = timeAsString
                
                let durationMin = Int(player.duration / 60) - min
                let durationSec = Int(player.duration.truncatingRemainder(dividingBy: 60)) - sec
                let durationAsString = String(format: "-%02d:%02d", durationMin, durationSec)
                negProgressLabel.text = durationAsString

                audioProgressSlider.value = (Float(player.currentTime / player.duration) * 100) + 2
                
                player.updateMeters()
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

    
    func fetchRecordings(url: URL) {
        do {
            recordings = try FileManager.default.contentsOfDirectory(at: url,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
        } catch {
            print(error.localizedDescription)
            print("something went wrong listing recordings")
        }
    }
}

extension ClipsViewController : AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {

    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        
        if let e = error {
            print("\(e.localizedDescription)")
        }
    }
    
}

extension ClipsViewController : AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        currentMeterMin = 0
        currentMeterSec = 0
        recordButton.isEnabled = true
        playButton.setImage(#imageLiteral(resourceName: "baseline_play_arrow_black_48pt"), for: .normal)
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
    case recording
    case resumedRecording
    case pausedRecording
    case pausedPlaying
    case stoppedPlaying
    case playing
}
