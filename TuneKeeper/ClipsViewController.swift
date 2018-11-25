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
    
    @objc func back() {
        tuneRecorder?.done {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func didTouchRecordButton(_ sender: UIButton) {
        tuneRecorder?.record()
    }
    
    @IBAction func didTouchPlayButton(_ sender: UIButton) {
        tuneRecorder?.play()
    }

    @IBAction func didTouchSaveButton(_ sender: UIButton) {
        tuneRecorder?.saveCurrentRecording()
    }
    
    @IBAction func didTouchDeleteButton(_ sender: UIButton) {
        
        if tuneRecorder?.recorderState == .stoppedPlaying || tuneRecorder?.recorderState == .pausedPlaying || tuneRecorder?.recorderState == .pausedRecording {
            showDeleteRecordingDialog()
        }
    }
    
    func showDeleteRecordingDialog() {
        let alert = UIAlertController(title: nil, message: "Delete current recording? This cannot be undone.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            self.tuneRecorder?.deleteCurrentRecording()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func didTouchSlider(_ sender: Any) {
        tuneRecorder?.movedSliderTo(position: 0.0)
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
    
    func updateSlider(value: Float) {
        DispatchQueue.main.async {
            self.audioProgressSlider.value = value
        }
    }
    
    func updateProgressLabel(value: String) {
        DispatchQueue.main.async {
            self.progressLabel.text = value
        }
    }
    
    func updateNegProgress(value: String) {
        DispatchQueue.main.async {
            self.negProgressLabel.text = value
        }
    }
    
    func updateFileNameTextField(value: String) {
        DispatchQueue.main.async {
            self.fileNameTextField.text = value
        }
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
    
    func setPlayButtonImageToPause() {
        DispatchQueue.main.async {
            self.playButton.setImage(#imageLiteral(resourceName: "baseline_pause_black_48pt"), for: .normal)
        }
    }
    
    func resetButtons() {
        DispatchQueue.main.async {
            self.recordButton.isEnabled = true
            self.playButton.isEnabled = false
        }
    }
    
    func refreshClips() {
        fetchRecordings(url: songClipsDirectory)
        clipTable.reloadData()
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
