//
//  ImageDetailView.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import SwiftUI
import Photos

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
            Color.black
                .ignoresSafeArea()
            
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
                TabView(selection: $index) {
                    ForEach(Array(assetIDs.enumerated()), id: \.element) { idx, assetID in
                        AssetImageView(assetID: assetID)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

struct AssetImageView: View {
    let assetID: String
    @State private var image: UIImage?
    @State private var isLoading = true
    
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
        .onAppear {
            loadImage()
        }
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
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { result, _ in
            DispatchQueue.main.async {
                self.image = result
                self.isLoading = false
            }
        }
    }
}

#Preview {
    NavigationView {
        ImageDetailView(assetIDs: ["sample1", "sample2"], startIndex: 0)
    }
}
