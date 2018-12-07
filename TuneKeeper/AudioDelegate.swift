//
//  AudioDelegate.swift
//  TuneKeeper
//
//  Created by Jeffrey Crace on 11/24/18.
//  Copyright © 2018 Jeffrey Crace. All rights reserved.
//

import Foundation
import AVFoundation

protocol AudioDelegate {
    func updateAudioProgressSlider(value: Float)
    func updateProgressLabel(value: String)
    func updateNegProgressLabel(value: String)
    func updateFileNameTextField(value: String)
    func enablePlayButton(bool: Bool)
    func setTitleOnRecordButton(title: String)
    func enableAudioProgressSlider(bool: Bool)
    func setPlayButtonImageToPlay()
    func setPlayButtonImageToPause()
    func refreshClips()
}
