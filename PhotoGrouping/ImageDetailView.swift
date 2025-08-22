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
    @StateObject private var vm: ImageDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(assetIDs: [String], startIndex: Int) {
        _vm = StateObject(wrappedValue: ImageDetailViewModel(assetIDs: assetIDs, startIndex: startIndex))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if vm.assetIDs.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    Text("No photos available")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            } else {
                PageViewController(pages: vm.assetIDs.map { AssetImageView(assetID: $0) }, currentIndex: $vm.index)
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

// MARK: - UIKit PageViewController Wrapper (Windowed pool: only ±1, Binding-synced)
struct PageViewController<Page: View>: UIViewControllerRepresentable {
    var pages: [Page]
    @Binding var currentIndex: Int

    func makeCoordinator() -> Coordinator { Coordinator(currentIndex: $currentIndex) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator

        context.coordinator.totalCount = pages.count
        context.coordinator.provider = { index in
            guard index >= 0 && index < pages.count else { return nil }
            if let vc = context.coordinator.pool[index] { return vc }
            let vc = UIHostingController(rootView: pages[index])
            context.coordinator.pool[index] = vc
            return vc
        }

        let start = max(0, min(currentIndex, pages.count - 1))
        if let startVC = context.coordinator.provider?(start) {
            pvc.setViewControllers([startVC], direction: .forward, animated: false)
            context.coordinator.visibleIndex = start
            context.coordinator.trimPool(around: start)
            // Binding'i başlangıçta da senkronla
            if context.coordinator.currentIndexBinding.wrappedValue != start {
                context.coordinator.currentIndexBinding.wrappedValue = start
            }
        }
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        let C = context.coordinator
        C.totalCount = pages.count

        // Swipe/anim sırasında veya programatik set sürerken dokunma
        guard !C.isAnimating, !C.isProgrammaticSet else { return }

        // Görünür index ile binding farklıysa, hizala
        if let visible = pvc.viewControllers?.first,
           let visIdx = C.index(of: visible),
           visIdx != currentIndex,
           let target = C.provider?(currentIndex) {

            let dir: UIPageViewController.NavigationDirection = currentIndex > visIdx ? .forward : .reverse
            C.isProgrammaticSet = true
            pvc.setViewControllers([target], direction: dir, animated: false) { _ in
                C.isProgrammaticSet = false
                C.visibleIndex = currentIndex
                C.trimPool(around: currentIndex)
            }
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var pool: [Int: UIViewController] = [:]
        var provider: ((Int) -> UIViewController?)?
        var totalCount: Int = 0

        let currentIndexBinding: Binding<Int>

        var isAnimating = false
        var isProgrammaticSet = false
        var visibleIndex: Int?

        init(currentIndex: Binding<Int>) {
            self.currentIndexBinding = currentIndex
        }

        func index(of vc: UIViewController) -> Int? {
            return pool.first(where: { $0.value === vc })?.key
        }

        func trimPool(around pivot: Int) {
            let keep = Set([pivot - 1, pivot, pivot + 1].filter { $0 >= 0 && $0 < totalCount })
            for (idx, vc) in pool where !keep.contains(idx) {
                pool.removeValue(forKey: idx)
                _ = vc.view
            }
        }

        // MARK: Data Source
        func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let idx = index(of: vc), idx > 0 else { return nil }
            return provider?(idx - 1)
        }
        func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let idx = index(of: vc), idx + 1 < totalCount else { return nil }
            return provider?(idx + 1)
        }

        // MARK: Delegate
        func pageViewController(_ pvc: UIPageViewController, willTransitionTo pending: [UIViewController]) {
            isAnimating = true
        }

        func pageViewController(_ pvc: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            isAnimating = false
            guard completed,
                  let current = pvc.viewControllers?.first,
                  let idx = index(of: current) else { return }

            if currentIndexBinding.wrappedValue != idx {
                currentIndexBinding.wrappedValue = idx
            }
            visibleIndex = idx
            trimPool(around: idx)
        }
    }
}



// MARK: - AssetImageView with Flicker Fix
struct AssetImageView: View {
    let assetID: String
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var requestID: PHImageRequestID?

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
        .onDisappear { if let id = requestID { imageManager.cancelImageRequest(id) } }
    }

    private func loadImage() {
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
        guard let asset = asset else { isLoading = false; return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .fast

        requestID = imageManager.requestImage(
            for: asset,
            targetSize: UIScreen.main.bounds.size * UIScreen.main.scale,
            contentMode: .aspectFit,
            options: options
        ) { result, info in
            if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
            if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled { return }
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
