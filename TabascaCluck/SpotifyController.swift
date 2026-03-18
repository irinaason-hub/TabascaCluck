//
//  SpotifyController.swift
//  TabascaCluck
//
//  Created by Irina Ason on 2/26/26.
//

import Foundation
import SpotifyiOS
import UIKit
import Combine

@MainActor
final class SpotifyController: NSObject, ObservableObject {

    // MARK: - Configure these
    private let clientID = "b5deb90282b6483e92ba9c828a91ead6"
    private let redirectURI = URL(string: "tabasca-cluck://callback")!
    private let scopes: [String] = [
                                        "app-remote-control",
                                        "user-modify-playback-state",
                                        "user-read-playback-state",
                                        "playlist-read-private",
                                        "playlist-read-collaborative"
                                    ]

    // MARK: - Published state
    @Published var isLoggedIn = false
    @Published var isAppRemoteConnected = false
    @Published var statusText: String = "Not logged in"
    @Published var playlistTracks: [String] = []   // Spotify track URIs
    @Published var playlistName: String = ""

    // MARK: - Playback resume cache
    private var lastKnownURI: String?
    private var lastKnownPositionMs: Int = 0
    private var pendingResumeAfterReconnect: Bool = false

    // MARK: - Spotify SDK
    private lazy var configuration: SPTConfiguration = {
        let c = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        return c
    }()

    private lazy var appRemote: SPTAppRemote = {
        let ar = SPTAppRemote(configuration: configuration, logLevel: .debug)
        ar.delegate = self
        return ar
    }()

    private var accessToken: String?

    func configure() {
        statusText = "Ready"
    }

    // MARK: - Auth
    func login() {
        wakeUp(scopes: scopes)
        statusText = "Opening Spotify login…"
    }
    
    func wakeUp(scopes: [String] = []) {
        appRemote.authorizeAndPlayURI("spotify:track:0Z2B3ArGjNi86MkZgWDCNp", asRadio: false,
                                      additionalScopes: scopes, completionHandler: nil)
    }

    func handleAuthCallback(url: URL) -> Bool {
        print("handleAuthCallback called with: \(url)")
        
        guard let token = url.absoluteString.substring(between: "#access_token=", and: "&token_type") else {
            isLoggedIn = false
            statusText = "Logged in Failed"
            return false
        }

        accessToken = token
        isLoggedIn = true
        statusText = "Logged in"
        connectAppRemoteIfPossible()
        return true
    }

    // MARK: - App Remote (removed)
    func connectAppRemoteIfPossible() {

        guard let token = accessToken else {
            print("connectAppRemoteIfPossible: no access token yet")
            return
        }
        appRemote.connectionParameters.accessToken = token
        appRemote.delegate = self
        appRemote.connect()
        statusText = isAppRemoteConnected ? "Reconnecting to Spotify" : "Connecting to Spotify"
    }

    func disconnectAppRemote() {
        if appRemote.isConnected { appRemote.disconnect() }
        isAppRemoteConnected = false
    }

    // MARK: - Playback helpers (use Web API only)
    func playTrack(uri: String) {
        guard appRemote.isConnected else { return }
        appRemote.playerAPI?.play(uri, callback: { _, error in
            if let error = error {
                print("Play error:", error)
            }
        })
    }

    func pause() {
        guard appRemote.isConnected else { return }
        // Attempt to capture current state before pausing
        appRemote.playerAPI?.getPlayerState({ [weak self] result, error in
            if let state = result as? SPTAppRemotePlayerState {
                self?.lastKnownURI = state.track.uri
                self?.lastKnownPositionMs = state.playbackPosition
            }
            // Now pause playback
            self?.appRemote.playerAPI?.pause { _, _ in }
        })
    }

    func resume() {
        if appRemote.isConnected {
            appRemote.playerAPI?.resume { _, _ in }
            return
        }

        // Not connected: reconnect and mark that we should resume after connection
        pendingResumeAfterReconnect = true
        wakeUp(scopes: scopes)
        connectAppRemoteIfPossible()
    }

    // MARK: - Playlist parsing + fetch (Web API)
    func loadPlaylist(from playlistURLString: String) async {
        guard let id = Self.extractPlaylistID(from: playlistURLString) else {
            statusText = "Couldn’t parse playlist URL"
            return
        }
        guard let token = accessToken else {
            statusText = "Login first"
            return
        }
        do {
            let (name, uris) = try await fetchPlaylistTracks(playlistID: id, token: token)
            playlistName = name
            playlistTracks = uris
            statusText = "Loaded \(uris.count) tracks"
        } catch {
            statusText = "Playlist fetch failed: \(error.localizedDescription)"
        }
    }

    private func fetchPlaylistTracks(playlistID: String, token: String) async throws -> (String, [String]) {
        let fields = "name,items.items(is_local,item(uri))"

        var comps = URLComponents(string: "https://api.spotify.com/v1/playlists/\(playlistID)")!
        comps.queryItems = [URLQueryItem(name: "fields", value: fields)]

        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "SpotifyWebAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bad response"])
        }
        
        struct Root: Decodable {
            let name: String
            let items: Tracks
            struct Tracks: Decodable { let items: [Item] }
            struct Item: Decodable { let item: Track?; let is_local: Bool?  }
            struct Track: Decodable { let uri: String; }
        }

        let decoded = try JSONDecoder().decode(Root.self, from: data)
        let excludedURIs: Set<String> = [
             "spotify:track:0Z2B3ArGjNi86MkZgWDCNp"
        ]

        let uris = decoded.items.items
            .filter { ($0.is_local ?? false) == false } // avoid local files
            .compactMap { $0.item }
            .map { $0.uri }
            .filter { !excludedURIs.contains($0) }

        return (decoded.name, uris)
    }

    static func extractPlaylistID(from s: String) -> String? {
        if s.contains("spotify:playlist:") {
            return s.components(separatedBy: "spotify:playlist:").last?.split(separator: "?").first.map(String.init)
        }
        if let url = URL(string: s), url.host?.contains("spotify.com") == true {
            let parts = url.pathComponents
            if let idx = parts.firstIndex(of: "playlist"), idx + 1 < parts.count {
                return parts[idx + 1]
            }
        }
        return nil
    }
}

// MARK: - App remote delegate
extension SpotifyController: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        isAppRemoteConnected = true
        statusText = "Connected to Spotify"
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { _, error in
            if let error = error { print("Subscribe error:", error) }
        })

        // If we were asked to resume after reconnect, do it now
        if pendingResumeAfterReconnect {
            pendingResumeAfterReconnect = false

            if let uri = lastKnownURI {
                appRemote.playerAPI?.play(uri, callback: { [weak self] _, _ in
                    guard let self = self else { return }
                    self.appRemote.playerAPI?.seek(toPosition: self.lastKnownPositionMs, callback: { _, _ in
                        print("Default resume 1")
                    })
                })
                lastKnownURI = nil
            }
            else {
                print("Default resume 2")
            }
        }
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        isAppRemoteConnected = false
        statusText = "Spotify connect failed"
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        isAppRemoteConnected = false
        statusText = "Spotify disconnected"
        print("App Remote disconnected. Cached uri=\(lastKnownURI ?? "nil"), pos=\(lastKnownPositionMs)")
    }
}

// MARK: - Player state delegate
extension SpotifyController: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {

    }
}


extension String {
    func substring(between start: String, and end: String, options: String.CompareOptions = []) -> String? {
        guard let startRange = self.range(of: start, options: options) else { return nil }
        let from = startRange.upperBound
        guard let endRange = self.range(of: end, options: options, range: from..<endIndex) else { return nil }
        return String(self[from..<endRange.lowerBound])
    }
}
