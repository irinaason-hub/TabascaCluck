//
//  TabascaCluckApp.swift
//  TabascaCluck
//
//  Created by Irina Ason on 2/26/26.
//
// App ID = b5deb90282b6483e92ba9c828a91ead6
// App Name = Tabasca-Cluck
// redirect URI = tabasca-cluck://callback


import SwiftUI

@main
struct TabascaCluckApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.spotify)
                .onOpenURL { url in
                    print("TabascaCluckApp onOpenURL received: \(url)")
                    _ = appDelegate.spotify.handleAuthCallback(url: url)
                }
        }
    }
}
