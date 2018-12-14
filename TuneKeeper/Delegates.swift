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
    func setPlayButtonImageToPlay()
    func disablePlay()
    func playing()
    func pausedRecording()
    func recording()
    func refreshClips(url: URL?)
    func enablePlayButton()
}

protocol ClipCellDelegate {
    func didPressPlayButtonOnCell(_ row: Int)
    func didEditClipCellTextField(onCell cell: ClipCell)
}
