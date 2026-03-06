//
//  TabascaEngine.swift
//  TabascaCluck
//
//  Created by Irina Ason on 2/26/26.
//

import Foundation
import Combine
import AVFoundation
import UIKit

@MainActor
final class TabascaEngine: ObservableObject {

    enum Phase { case idle, work, rest, finished, paused }

    @Published var phase: Phase = .idle
    @Published var round: Int = 0

    @Published var sets: Int = 8
    @Published var roundsPerSet: Int = 8

    var totalRounds: Int { max(1, sets * roundsPerSet) }
    @Published var secondsRemaining: Int = 0

    var workSeconds: Int = 20
    var restSeconds: Int = 10

    private var timer: DispatchSourceTimer?
    private var tracks: [String] = []
    private var currentTrackIndex: Int = 0

    private let spotify: SpotifyController
    private let duck: DuckingAudioController

    private var lastPhaseBeforePause: Phase = .idle

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    init(spotify: SpotifyController, duck: DuckingAudioController) {
        self.spotify = spotify
        self.duck = duck
    }

    func configureRounds(_ n: Int) {
        roundsPerSet = max(1, n)
    }

    func start(withTrackURIs uris: [String]) {
        tracks = uris.shuffled()
        round = 0
        currentTrackIndex = 0
        phase = .work
        secondsRemaining = workSeconds

        configureAudioSessionForBackground()

        playCurrentRoundTrack()
        startTimer()
    }

    func togglePause() {
        switch phase {
        case .work, .rest:
            lastPhaseBeforePause = phase
            phase = .paused
            stopTimer()
            spotify.pause()
        case .paused:
            phase = lastPhaseBeforePause
            if phase == .work { spotify.resume() }
            startTimer()
        default:
            break
        }
    }

    func reset() {
        stopTimer()
        spotify.pause()
        phase = .idle
        round = 0
        secondsRemaining = 0
    }

    private func startTimer() {
        stopTimer()
        beginBackgroundTask()

        let queue = DispatchQueue(label: "com.tabasca.engine.timer", qos: .userInitiated)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1.0, repeating: 1.0)
        t.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer = t
        t.resume()
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        endBackgroundTask()
    }

    private func tick() {
        guard phase == .work || phase == .rest else { return }

        if secondsRemaining > 0 {
            secondsRemaining -= 1
            return
        }

        if phase == .work {
            phase = .rest
            secondsRemaining = restSeconds
            
            var urlStr = "round_\(round + 1)_completed"
            if((round + 1) >= roundsPerSet) {
                urlStr = "finish"
            } else if((round + 1) % roundsPerSet == 0){
                urlStr = "set_\(currentSetNumber)_completed"
                
            }

            guard let pauseURL = Bundle.main.url(forResource: urlStr, withExtension: "mp3") else {
                print("File \(urlStr).mp3 missing")
                return
            }
            try? duck.startDucking(with: pauseURL, volume: 1)

        } else if phase == .rest {
            duck.stopDucking()
            round += 1
            if round >= totalRounds {
                finish()
                return
            }
            phase = .work
            secondsRemaining = workSeconds
            if roundsPerSet > 0 && (round % roundsPerSet) == 0 {
                currentTrackIndex += 1
                playCurrentRoundTrack()
            }
        }
    }

    private func playCurrentRoundTrack() {
        guard !tracks.isEmpty else { return }
        let uri = tracks[currentTrackIndex % tracks.count]
        spotify.playTrack(uri: uri)
    }

    private func finish() {
        stopTimer()
        spotify.pause()
        phase = .finished
        secondsRemaining = 0
    }

    var currentSetNumber: Int { (round / max(1, roundsPerSet)) + 1 }
    var currentRoundInSet: Int { (round % max(1, roundsPerSet)) + 1 }

    // MARK: - Background & Audio helpers
    private func configureAudioSessionForBackground() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }

    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TabascaEngineTimer") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
