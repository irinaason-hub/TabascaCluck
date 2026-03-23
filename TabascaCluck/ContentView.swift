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

    @State private var rounds: Int = 8
    @State private var sets: Int = 8
    
    @State private var subtitles: [String] = [
        "Reveal Your Fluffiness",
        "Unleash Your Inner Chicken",
        "Train the Chicken Within",
        "From Fluffy to Feisty",
        "Cluck Into Shape",
        "Hatch Your Power",
        "Turn Fluff Into Fire",
        "Fluff Today. Beast Tomorrow",
        "Peck. Rest. Repeat.",
        "Cluck Your Limits",
        "Where Chickens Become Legends",
        "Small Bird. Big Burn."
    ]
    
    @State private var selectedSubtitle: String = ""
    
    @State private var isLoadingOverlayVisible = true

    var header: some View {
        VStack(spacing: 4) {
            Text("Tabasca Cluck")
                .font(.title.weight(.bold))
            Text(selectedSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    var loginSection: some View {
        HStack {
            Button(spotify.isLoggedIn ? "Connected to Spotify" : "Connect Spotify") {
                if !spotify.isLoggedIn { spotify.login() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .symbolEffect(.bounce, value: spotify.isLoggedIn)
            .disabled(spotify.isLoggedIn)

            if !spotify.statusText.isEmpty {
                Text(spotify.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    var playlistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Playlist")
                    .font(.headline)
                Spacer()
                Button {
                    Task {
                        await spotify.loadPlaylist(from: "https://open.spotify.com/playlist/3xJUJSrhai5KTFbH0bbze2")
                    }
                } label: {
                    Label("Load", systemImage: "arrow.down.circle.fill")
                }
                .disabled(!spotify.isLoggedIn)
            }


            if !spotify.playlistName.isEmpty {
                Text("Loaded: \(spotify.playlistName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    var body: some View {
        let engine = engineHolder.engine(spotify: spotify, duck: duck)

        //todo: add loading image

        VStack(spacing: 16) {
            header
            loginSection
            playlistSection
            settingsSection(engine: engine)
            timerSection(engine: engine)
            controlsSection(engine: engine)
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(colors: [.orange.opacity(0.3), .yellow.opacity(0.2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .onAppear {
            engine.configureRounds(rounds)
            if let s = subtitles.randomElement() { selectedSubtitle = s }
        }
    }

    private func settingsSection(engine: TabascaEngine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Settings")
            .font(.headline)

            Stepper("Rounds per set: \(rounds)", value: $rounds, in: 1...8)
            .onChange(of: rounds) { _, newValue in
                engine.configureRounds(newValue)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            Stepper("Sets: \(sets)", value: $sets, in: 1...8)
            .onChange(of: sets) { _, newValue in
                engine.sets = max(1, newValue)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func timerSection(engine: TabascaEngine) -> some View {
        let isWork = engine.phase == .work
        let accent = isWork ? Color.red : Color.green

        return VStack(spacing: 10) {
            Text(phaseLabel(engine.phase))
            .font(.headline)
            .foregroundStyle(accent)

            Text("Set \(min(engine.currentSetNumber, engine.sets)) / \(engine.sets) • Round \(min(engine.currentRoundInSet, engine.roundsPerSet)) / \(engine.roundsPerSet)")
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("\(engine.secondsRemaining)s")
            .font(.system(size: 56, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(accent)

            ProgressView(value: Double(engine.currentRoundInSet - 1), total: Double(max(1, engine.roundsPerSet)))
            .tint(accent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }

    private func controlsSection(engine: TabascaEngine) -> some View {
        HStack(spacing: 12) {
            Button {
                if engine.phase == .idle || engine.phase == .finished {
                    engine.configureRounds(rounds)
                    engine.sets = sets
                    engine.start(withTrackURIs: spotify.playlistTracks)
                } else {
                    engine.togglePause()
                }
            } label: {
                if engine.phase == .idle || engine.phase == .finished {
                    Label("Start", systemImage: "play.fill")
                } else if engine.phase == .paused {
                    Label("Resume", systemImage: "playpause.fill")
                } else {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(spotify.playlistTracks.isEmpty)

            Button(role: .destructive) {
                engine.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(engine.phase == .idle)
        }
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

#Preview {
    ContentView()
        .environmentObject(SpotifyController())
        .environmentObject(DuckingAudioController())
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
