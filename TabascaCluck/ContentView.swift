//
//  ContentView.swift
//  TabascaCluck
//
//  Created by Irina Ason on 2/26/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var spotify: SpotifyController
    @EnvironmentObject var duck: DuckingAudioController

    @StateObject private var engineHolder = EngineHolder()

    @State private var playlistURL: String = ""
    @State private var rounds: Int = 8
    @State private var sets: Int = 8

    var body: some View {
        let engine = engineHolder.engine(spotify: spotify, duck: duck)

        VStack(spacing: 16) {
            Text("Tabasca Cluck")
                .font(.title2).bold()

            Text(spotify.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Button(spotify.isLoggedIn ? "Logged in" : "Login with Spotify") {
                    if !spotify.isLoggedIn {
                    spotify.login()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(spotify.isLoggedIn)

                Text(spotify.statusText)
                    .font(.caption)
            }

             VStack(alignment: .leading, spacing: 8) {
                 Button("Load playlist") {
                 // todo: remove hardcode from here;
                     Task { await spotify.loadPlaylist(from: "https://open.spotify.com/playlist/3xJUJSrhai5KTFbH0bbze2") }
                 }
                 .buttonStyle(.bordered)
                 .disabled(!spotify.isLoggedIn)

                 if !spotify.playlistName.isEmpty {
                     Text("Playlist: \(spotify.playlistName)")
                         .font(.caption)
                         .foregroundStyle(.secondary)
                 }
             }

            HStack {
                Stepper("Rounds per set: \(rounds)", value: $rounds, in: 1...8)
                    .onChange(of: rounds) { _, newValue in
                        engine.configureRounds(newValue)
                    }
                Stepper("Sets: \(sets)", value: $sets, in: 1...8)
                    .onChange(of: sets) { _, newValue in
                        engine.sets = max(1, newValue)
                    }
            }

            VStack(spacing: 6) {
                Text(phaseLabel(engine.phase))
                    .font(.headline)

                Text("Set \(min(engine.currentSetNumber, engine.sets)) / \(engine.sets) — Round \(min(engine.currentRoundInSet, engine.roundsPerSet)) / \(engine.roundsPerSet)")
                    .font(.subheadline)

                Text("\(engine.secondsRemaining)s")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
            }
            .padding(.vertical, 8)

            HStack(spacing: 12) {
                Button(engine.phase == .idle || engine.phase == .finished ? "Start" : "Pause/Resume") {
                    if engine.phase == .idle || engine.phase == .finished {
                        engine.configureRounds(rounds)
                        engine.sets = sets
                        engine.start(withTrackURIs: spotify.playlistTracks)
                    } else {
                        engine.togglePause()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(spotify.playlistTracks.isEmpty)

                Button("Reset") {
                    engine.reset()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .onAppear { engine.configureRounds(rounds) }
    }

    private func phaseLabel(_ p: TabascaEngine.Phase) -> String {
        switch p {
        case .idle: return "Idle"
        case .work: return "WORK"
        case .rest: return "REST"
        case .paused: return "Paused"
        case .finished: return "Done"
        }
    }
}

final class EngineHolder: ObservableObject {
    @Published private(set) var engine: TabascaEngine?
    private var engineCancellable: AnyCancellable?

    func engine(spotify: SpotifyController, duck: DuckingAudioController) -> TabascaEngine {
        if let e = engine { return e }
        let e = TabascaEngine(spotify: spotify, duck: duck)
        engine = e
        engineCancellable = e.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        return e
    }
}
