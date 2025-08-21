//
//  ImageDetailView.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import SwiftUI
import Photos

// MARK: - Image Detail with Smooth Paging
struct ImageDetailView: View {
    let assetIDs: [String]
    @State var index: Int
    @Environment(\.dismiss) private var dismiss
    
    init(assetIDs: [String], startIndex: Int) {
        self.assetIDs = assetIDs
        self._index = State(initialValue: startIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if assetIDs.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    Text("No photos available")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            } else {
                PageViewController(pages: assetIDs.map { AssetImageView(assetID: $0) }, currentIndex: $index)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
                    .foregroundColor(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - UIKit PageViewController Wrapper
struct PageViewController<Page: View>: UIViewControllerRepresentable {
    var pages: [Page]
    @Binding var currentIndex: Int
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let vc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        vc.dataSource = context.coordinator
        vc.delegate = context.coordinator
        
        let first = context.coordinator.controllers[currentIndex]
        vc.setViewControllers([first], direction: .forward, animated: false)
        
        return vc
    }
    
    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        let controller = context.coordinator.controllers[currentIndex]
        pageVC.setViewControllers([controller], direction: .forward, animated: false)
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageViewController
        var controllers: [UIViewController]
        
        init(_ parent: PageViewController) {
            self.parent = parent
            self.controllers = parent.pages.map { UIHostingController(rootView: $0) }
        }
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            return index == 0 ? nil : controllers[index - 1]
        }
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            return index + 1 == controllers.count ? nil : controllers[index + 1]
        }
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            if completed, let visible = pageViewController.viewControllers?.first,
               let index = controllers.firstIndex(of: visible) {
                parent.currentIndex = index
            }
        }
    }
}

// MARK: - AssetImageView with Flicker Fix
struct AssetImageView: View {
    let assetID: String
    @State private var image: UIImage?
    @State private var isLoading = true
    
    private let imageManager = PHCachingImageManager.default()
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(2.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    Text("Failed to load image")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
        }
        .onAppear { loadImage() }
    }
    
    private func loadImage() {
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
        guard let asset = asset else {
            isLoading = false
            return
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImage(
            for: asset,
            targetSize: UIScreen.main.bounds.size * UIScreen.main.scale,
            contentMode: .aspectFit,
            options: options
        ) { result, info in
            // Skip degraded images completely
            if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
            
            DispatchQueue.main.async {
                self.image = result
                self.isLoading = false
            }
        }
    }
}

// Helper: scale CGSize
fileprivate extension CGSize {
    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}
