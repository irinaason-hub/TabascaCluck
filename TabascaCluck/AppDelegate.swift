//
//  AppDelegate.swift
//  TabascaCluck
//
//  Created by Irina Ason on 2/26/26.
//

import UIKit
import Combine

final class AppDelegate: NSObject, UIApplicationDelegate {

    // Expose manager to SwiftUI
    let spotify = SpotifyController()
    let duck = DuckingAudioController()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        spotify.configure()
        return true
    }

   func application(_ app: UIApplication, open url: URL,
                    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
       print("AppDelegate openURL received: \(url)")
       return spotify.handleAuthCallback(url: url)
   }
}
