//
//  ContentView.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        HomeContainerView()
    }
}

struct HomeContainerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let homeViewController = HomeViewController()
        let navigationController = UINavigationController(rootViewController: homeViewController)
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
}

#Preview {
    ContentView()
}
