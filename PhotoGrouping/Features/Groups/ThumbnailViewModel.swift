//
//  ThumbnailViewModel.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import Foundation
import UIKit
import Photos

@MainActor
final class ThumbnailViewModel: ObservableObject, Identifiable {
    let id: String
    let targetSize: CGSize

    @Published var image: UIImage?
    private var requestID: PHImageRequestID?

    init(id: String, targetSize: CGSize) {
        self.id = id
        self.targetSize = targetSize
    }

    func load() {
        guard image == nil else { return }
        requestID = PhotoThumbCache.shared.image(for: id, targetSize: targetSize, mode: .aspectFill) { [weak self] img in
            guard let self else { return }
            Task { @MainActor in self.image = img }
        }
    }

    func cancel() {
        PhotoThumbCache.shared.cancel(requestID)
        requestID = nil

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            if requestID == nil { self.image = nil }
        }
    }

    deinit {
        PhotoThumbCache.shared.cancel(requestID)
    }
}
