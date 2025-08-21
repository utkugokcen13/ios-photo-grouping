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

    // Grid’de göstereceğimiz ID’leri “batch” olarak büyütüyoruz
    @State private var displayedIDs: [String] = []
    @State private var isPrimed: Bool = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let thumbSize = CGSize(width: 180, height: 180)

    private var sourceIDs: [String] {
        if let g = group { return store.groups[g] ?? [] }
        return store.others
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(displayedIDs, id: \.self) { id in
                    NavigationLink {
                        ImageDetailView(assetIDs: displayedIDs, startIndex: displayedIDs.firstIndex(of: id) ?? 0)
                    } label: {
                        ThumbnailView(localIdentifier: id, targetSize: thumbSize)
                            .onAppear {
                                // basit preheat: görünen hücrenin çevresini önceden cache’le
                                if let idx = displayedIDs.firstIndex(of: id) {
                                    let lo = max(0, idx - 30)
                                    let hi = min(displayedIDs.count - 1, idx + 30)
                                    let ids = Array(displayedIDs[lo...hi])
                                    PhotoThumbCache.shared.preheat(ids: ids, size: thumbSize)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .transaction { $0.animation = nil } // sürekli ekleme animasyon yapmasın
        }
        .navigationTitle(group?.rawValue.uppercased() ?? "Others")
        .onAppear {
            // ilk açılışta mevcutları chunk chunk yükle
            primeDisplayedIDsIfNeeded()
        }
        .onChange(of: sourceIDs) { new in
            // yeni gelenleri küçük parçalar halinde ekle
            appendIncrementally(newIDs: new)
        }
    }

    private func primeDisplayedIDsIfNeeded() {
        guard !isPrimed else { return }
        isPrimed = true
        displayedIDs.removeAll(keepingCapacity: true)
        appendIncrementally(newIDs: sourceIDs, initial: true)
    }

    private func appendIncrementally(newIDs: [String], initial: Bool = false) {
        // mevcut ile farkı al
        if newIDs.count <= displayedIDs.count { return }
        let delta = Array(newIDs[displayedIDs.count...])

        // ilk yüklemede biraz daha büyük batch, sonrasında küçük
        let chunk = initial ? 200 : 80
        var idx = 0

        func scheduleNext() {
            guard idx < delta.count else { return }
            let end = min(idx + chunk, delta.count)
            let slice = delta[idx..<end]
            displayedIDs.append(contentsOf: slice)
            // küçük bir ara vererek main thread’i rahatlat
            idx = end
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                scheduleNext()
            }
        }
        scheduleNext()
    }
}

struct ThumbnailView: View {
    let localIdentifier: String
    let targetSize: CGSize

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.28))
            }
        }
        .frame(height: 120)
        .clipped()
        .cornerRadius(8)
        .animation(nil, value: image) // parlamayı engelle
        .onAppear { load() }
        .onDisappear { cancel() }
        .id(localIdentifier) // cell state karışmasın
        .contentShape(Rectangle()) // tap hedefi net olsun
    }

    private func load() {
        // zaten yüklenmişse çık
        if image != nil { return }

        requestID = PhotoThumbCache.shared.image(for: localIdentifier,
                                                 targetSize: targetSize,
                                                 mode: .aspectFill) { img in
            DispatchQueue.main.async { self.image = img }
        }
    }

    private func cancel() {
        PhotoThumbCache.shared.cancel(requestID)
        requestID = nil
    }
}
