//
//  DuckingAudioController.swift
//  TabascaCluck
//
//  Created by Irina Ason on 3/4/26.
//

import AVFoundation
import Combine

@MainActor
final class DuckingAudioController: ObservableObject {
    
    private var player: AVAudioPlayer?

    func startDucking(with soundURL: URL, volume: Float = 0.2, loop: Bool = false) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, options: [.duckOthers])
        try session.setActive(true)

        let audio = try AVAudioPlayer(contentsOf: soundURL)
        audio.numberOfLoops = loop ? -1 : 0
        audio.volume = volume
        audio.prepareToPlay()
        audio.play()
        self.player = audio
    }

    func stopDucking() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

