//
//  PlayClipViewController.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 1/28/18.
//  Copyright © 2018 Jeffrey Crace. All rights reserved.
//

import UIKit
import AVFoundation

class PlayClipViewController: UIViewController {
    
    var player:AVAudioPlayer!
    var soundFileURLToBeReceived: URL?

    @IBOutlet weak var clipLabel: UILabel!
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    
    var meterTimer: Timer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if soundFileURLToBeReceived != nil {
            clipLabel.text = soundFileURLToBeReceived?.lastPathComponent.fileName()
        }
        
        stopButton.isEnabled = false
        playButton.isEnabled = true
        setSessionPlayback()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func didTouchPlayButton(_ sender: UIButton) {
        
        if playButton.titleLabel?.text == "Play" {
            playButton.setTitle("Pause", for: .normal)
            play()
        }
        else {
            playButton.setTitle("Play", for: .normal)
            player.pause()
        }
    }
    
    func play() {
        
        do {
            self.player = try AVAudioPlayer(contentsOf: soundFileURLToBeReceived!)
            player.delegate = self
            player.prepareToPlay()
            player.volume = 1.0
            player.play()
            self.meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                                   target:self,
                                                   selector:#selector(self.updateAudioMeter(_:)),
                                                   userInfo:nil,
                                                   repeats:true)
        } catch {
            self.player = nil
            print(error.localizedDescription)
        }
        
    }
    
    @IBAction func didTouchStopButton(_ sender: UIButton) {

        player?.stop()
        
        meterTimer.invalidate()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
            playButton.isEnabled = true
            stopButton.isEnabled = false

        } catch {
            print("could not make session inactive")
            print(error.localizedDescription)
        }
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
    
    func updateAudioMeter(_ timer:Timer) {
        
        if let player = self.player {
            if player.isPlaying {
                let min = Int(player.currentTime / 60)
                let sec = Int(player.currentTime.truncatingRemainder(dividingBy: 60))
                let timeAsString = String(format: "%02d:%02d", min, sec)
                progressLabel.text = timeAsString
                player.updateMeters()
                // if you want to draw some graphics...
                //var apc0 = recorder.averagePowerForChannel(0)
                //var peak0 = recorder.peakPowerForChannel(0)
            }
        }
    }
    
}

extension PlayClipViewController : AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("\(#function)")
        
        print("finished playing \(flag)")
        stopButton.isEnabled = false
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("\(#function)")
        
        if let e = error {
            print("\(e.localizedDescription)")
        }
        
    }
}

extension String {
    
    func fileName() -> String {
        
        if let fileNameWithoutExtension = NSURL(fileURLWithPath: self).deletingPathExtension?.lastPathComponent {
            return fileNameWithoutExtension
        } else {
            return ""
        }
    }
}
