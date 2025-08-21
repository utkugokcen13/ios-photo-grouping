//
//  GroupDetailView.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import SwiftUI
import Photos

struct GroupDetailView: View {
    let group: PhotoGroup?
    @ObservedObject var store: GalleryStore

    var assetIDs: [String] {
        if let g = group { return store.groups[g] ?? [] }
        return store.others
    }

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(assetIDs, id: \.self) { id in
                    NavigationLink {
                        ImageDetailView(assetIDs: assetIDs, startIndex: assetIDs.firstIndex(of: id) ?? 0)
                    } label: {
                        ThumbnailView(localIdentifier: id)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle(group?.rawValue.uppercased() ?? "Others")
    }
}

struct ThumbnailView: View {
    let localIdentifier: String
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
        .frame(height: 120)
        .clipped()
        .cornerRadius(8)
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
        guard let asset = asset else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 180, height: 180),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}
