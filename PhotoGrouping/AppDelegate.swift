//
//  AppDelegate.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Create window and set up the app
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let homeViewController = HomeViewController()
        
        let navigationController = UINavigationController(rootViewController: homeViewController)
        
        window?.rootViewController = navigationController
        window?.layoutIfNeeded()
        
        DispatchQueue.main.async {

            (UIApplication.shared.delegate as? AppDelegate)?.window = self.window
            
            self.window?.makeKey()
            self.window?.isHidden = false
            self.window?.makeKeyAndVisible()
            self.window?.layoutIfNeeded()
            self.window?.windowLevel = .normal
            self.window?.layoutIfNeeded()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.window?.makeKeyAndVisible()
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {

    }
}
