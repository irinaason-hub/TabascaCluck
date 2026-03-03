//
//  SceneDelegate.swift
//  TabascaCluck
//
//  Created by Irina Ason on 2/27/26.
//

import UIKit

final class SceneDelegate: NSObject, UIWindowSceneDelegate {

    var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let urlContext = URLContexts.first else { return }
        let url = urlContext.url
        print("SceneDelegate openURL received: \(url.absoluteString)")
        _ = appDelegate?.spotify.handleAuthCallback(url: url)
    }
}
