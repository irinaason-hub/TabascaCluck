//
//  TabascaEngine.swift
//  TabascaCluck
//
//  Created by Irina Ason on 2/26/26.
//

import Foundation
import Combine

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

    private var timer: Timer?
    private var tracks: [String] = []
    private var currentTrackIndex: Int = 0

    private let spotify: SpotifyController
    private let duck: DuckingAudioController

    private var lastPhaseBeforePause: Phase = .idle

    init(spotify: SpotifyController, duck: DuckingAudioController) {
        self.spotify = spotify
        self.duck = duck
    }

    func configureRounds(_ n: Int) {
        roundsPerSet = max(1, n)
    }

    func start(withTrackURIs uris: [String]) {
        tracks = uris
        round = 0
        currentTrackIndex = 0
        phase = .work
        secondsRemaining = workSeconds
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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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

            guard let pauseURL = Bundle.main.url(forResource: "round_\(round+1)_V1", withExtension: "mp3") else {
                print("File round_\(round+1)_V1.mp3 missing")
                return
            }
            try? duck.startDucking(with: pauseURL, volume: 1)
            
        } else if phase == .rest {
        duck.stopDucking();
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
}
