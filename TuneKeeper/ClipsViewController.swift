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

class ClipsViewController: UIViewController, AudioDelegate, UITextFieldDelegate {

    let fileExtension = ".m4a"
    var partIdToBeReceived: Int16?
    var part: Part?
    var song: Song?
    var recordings = [URL]()
    var songClipsDirectory: URL!
    var recordingManager: RecordingManager?
    
    var audioAssets = [AVURLAsset]()
    
    var oldContentInset = UIEdgeInsets.zero
    var oldIndicatorInset = UIEdgeInsets.zero
    var oldOffset = CGPoint.zero
    var keyboardShowing = false
    
    @IBOutlet weak var clipTable: UITableView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var fileNameTextField: UITextField!
    @IBOutlet weak var negProgressLabel: UILabel!
    @IBOutlet weak var audioProgressSlider: UISlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardShow), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardHide), name: .UIKeyboardWillHide, object: nil)
        
        let contentView = self.clipTable.subviews[0]
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalTo:self.clipTable.widthAnchor),
            contentView.heightAnchor.constraint(equalTo:self.clipTable.heightAnchor),
            ])
        
        self.clipTable.keyboardDismissMode = .interactive
        
        fileNameTextField.delegate = self
        
        let backButton: UIBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(back))
        self.navigationItem.leftBarButtonItem = backButton

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
        
        recordingManager = RecordingManager(audioDelegate: self, songClipsDirectory: songClipsDirectory)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        recordingManager?.done(completionHandler: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        if recordingManager?.recorderState != .startup {
            recordingManager?.saveCurrentRecording(url: nil)
        }
    }
    
    @objc func keyboardShow(_ n:Notification) {
        if self.keyboardShowing {
            return
        }
        self.keyboardShowing = true

        self.oldContentInset = self.clipTable.contentInset
        self.oldIndicatorInset = self.clipTable.scrollIndicatorInsets
        self.oldOffset = self.clipTable.contentOffset
        
        let d = n.userInfo!
        var r = d[UIKeyboardFrameEndUserInfoKey] as! CGRect
        r = self.clipTable.convert(r, from:nil)
        self.clipTable.contentInset.bottom = r.size.height
        self.clipTable.scrollIndicatorInsets.bottom = r.size.height
    }
    
    @objc func keyboardHide(_ n:Notification) {
        if !self.keyboardShowing {
            return
        }
        self.keyboardShowing = false

        self.clipTable.contentOffset = self.oldOffset
        self.clipTable.scrollIndicatorInsets = self.oldIndicatorInset
        self.clipTable.contentInset = self.oldContentInset
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if let name = textField.text, !name.isEmpty {
            recordingManager?.changeAudioFileName(currentFileUrl: nil, newFileName: name)
        }
        else if let name = recordingManager?.currentSoundFileUrl.lastPathComponent.replacingOccurrences(of: fileExtension, with: ""), !name.isEmpty{
            updateFileNameTextField(value: name)
        }
        
        textField.resignFirstResponder()
        return true
    }
    
    @objc func back() {
        recordingManager?.done {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func didTouchRecordButton(_ sender: UIButton) {
        recordingManager?.recordingButtonPressed()
    }
    
    @IBAction func didTouchPlayButton(_ sender: UIButton) {
        recordingManager?.playButtonPressed()
    }

    @IBAction func didTouchSaveButton(_ sender: UIButton) {
        if recordingManager?.recorderState != .startup {
            if fileNameTextField.isEditing {
                _ = textFieldShouldReturn(fileNameTextField)
            }
            recordingManager?.saveCurrentRecording(url: nil)
        }
    }
    
    @IBAction func didTouchDeleteButton(_ sender: UIButton) {
        if recordingManager?.recorderState == .stoppedPlaying || recordingManager?.recorderState == .pausedPlaying || recordingManager?.recorderState == .pausedRecording {
            showDeleteRecordingDialog()
        }
    }
    
    func showDeleteRecordingDialog() {
        let alert = UIAlertController(title: nil, message: "Delete current recording? This cannot be undone.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.recordingManager?.deleteCurrentRecording(url: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func didTouchDownSlider(_ sender: UISlider) {
        if recordingManager?.recorderState == .playing {
            recordingManager?.stopPlaying()
        }
    }
    
    @IBAction func didEditNewRecordingFileName(_ sender: UITextField) {
        recordingManager?.changeAudioFileName(currentFileUrl: nil, newFileName: sender.text!)
    }
    
    
    @IBAction func valueChangedOnSlider(_ sender: UISlider) {
        recordingManager?.adjustProgressLabels(value: sender.value)
    }
    
    
    @IBAction func didTouchUpInsideSlider(_ sender: UISlider) {
        recordingManager?.movedSliderTo(position: sender.value)
    }

    func fetchRecordings(url: URL) {
        do {
            recordings = try FileManager.default.contentsOfDirectory(at: url,
                                                                     includingPropertiesForKeys: [.contentModificationDateKey],
                                                                   options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
            
            recordings = recordings.sorted(by: {
                do {
                    return try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate! > $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate!
                }
                catch{
                    fatalError("Encountered an error while sorting clips by contentModificationDateKey -- \(error.localizedDescription)")
                }
                return false
            })

            
        } catch {
            fatalError("Failed to access URLs of clips -- \(error.localizedDescription)")
        }
    }
    
    func updateAudioProgressSlider(value: Float) {
        DispatchQueue.main.async {
            self.audioProgressSlider.value = value
        }
    }
    
    func updateProgressLabel(value: String) {
        DispatchQueue.main.async {
            self.progressLabel.text = value
        }
    }
    
    func updateNegProgressLabel(value: String) {
        DispatchQueue.main.async {
            self.negProgressLabel.text = value
        }
    }
    
    func updateFileNameTextField(value: String) {
        DispatchQueue.main.async {
            self.fileNameTextField.text = value
        }
    }
    
    func enablePlayButton() {
        DispatchQueue.main.async {
            self.playButton.isEnabled = true
        }
    }
    
    func setPlayButtonImageToPlay() {
        DispatchQueue.main.async {
            self.playButton.setImage(#imageLiteral(resourceName: "baseline_play_arrow_black_48pt"), for: .normal)
        }
    }
    
    func disablePlay() {
        DispatchQueue.main.async {
            self.playButton.isEnabled = false
            self.audioProgressSlider.isEnabled = false
        }
    }
    
    func pausedRecording() {
        DispatchQueue.main.async {
            self.recordButton.setTitle("Rec", for: .normal)
            self.playButton.isEnabled = true
        }
    }
    
    func recording() {
        DispatchQueue.main.async {
            self.recordButton.setTitle("Stop", for: .normal)
        }
    }
    
    func playing() {
        DispatchQueue.main.async {
            self.playButton.setImage(#imageLiteral(resourceName: "baseline_pause_black_48pt"), for: .normal)
            self.audioProgressSlider.isEnabled = true
        }
    }
    
    func refreshClips(url: URL?) {
        fetchRecordings(url: songClipsDirectory)
        if let url = url {
            recordings = recordings.filter() { $0 != url }
        }
        DispatchQueue.main.async {
            self.clipTable.reloadData()
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
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ClipCell
        cell.cellDelegate = self
        cell.clipCellTextField.text = recordings[indexPath.row].lastPathComponent.replacingOccurrences(of: fileExtension, with: "")
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            do {
                try FileManager.default.removeItem(at: recordings[indexPath.row])
                recordings.remove(at: indexPath.row)
                clipTable.reloadData()
            }
            catch {
                print("Error occurred while deleting clip -- \(error)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedUrl = recordings[indexPath.row]
        recordingManager?.saveCurrentRecording(url: selectedUrl)
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
    case startup
    case loaded
}

public class ClipCell: UITableViewCell, UITextFieldDelegate {
    
    var cellDelegate: ClipCellDelegate?
    
    @IBOutlet weak var clipCellTextField: UITextField!
    
    public override func awakeFromNib() {
        clipCellTextField.delegate = self
        
        let rect = CGRect(origin: CGPoint(x: 300, y: 0), size: CGSize(width: self.frame.width - 275, height: self.frame.height))
        let imageView = UIImageView(frame: rect)
        let image = UIImage(imageLiteralResourceName: "baseline_play_arrow_black_48pt")
        imageView.image = image
        self.backgroundView = UIView()
        self.backgroundView!.addSubview(imageView)
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        cellDelegate?.didEditClipCellTextField(onCell: self)
        textField.resignFirstResponder()
        return true
    }
}

extension ClipsViewController: ClipCellDelegate {
    
    func didEditClipCellTextField(onCell cell: ClipCell) {
        
        guard let indexPath = clipTable.indexPath(for: cell) else {
            return
        }
        
        if let fileName = cell.clipCellTextField.text, !fileName.isEmpty {
            recordingManager?.changeAudioFileName(currentFileUrl: recordings[indexPath.row], newFileName: fileName)
        }
        else {
            cell.clipCellTextField.text = recordings[indexPath.row].lastPathComponent.replacingOccurrences(of: fileExtension, with: "")
        }

    }
}
