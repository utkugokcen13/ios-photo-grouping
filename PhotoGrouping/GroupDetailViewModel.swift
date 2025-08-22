import Foundation
import SwiftUI
import Photos
import Combine

@MainActor
final class GroupDetailViewModel: ObservableObject {
    private weak var store: GalleryStore?
    private var group: PhotoGroup?

    @Published var displayedIDs: [String] = []
    @Published var isPrimed = false

    @Published var showDetail = false
    @Published var selectedIndex = 0

    private var drainTask: Task<Void, Never>?
    private var nextIndex = 0
    @Published var pauseDrain = false

    @Published var isVisible: Bool = false

    let columns: [GridItem] = [.init(.flexible()), .init(.flexible()), .init(.flexible())]
    let thumbSize = CGSize(width: 180, height: 180)

    private var lastPreheatAt: TimeInterval = 0
    private let preheatWindow = 0.10

    private var cancellables = Set<AnyCancellable>()

    init() {}

    func bind(group: PhotoGroup?, store: GalleryStore) {
        guard self.store == nil else { return }
        self.group = group
        self.store = store

        store.$groups.combineLatest(store.$others)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                guard self.isVisible, self.drainTask == nil else { return }
                self.startDrain(initial: false)
            }
            .store(in: &cancellables)
    }

    private var sourceIDs: [String] {
        guard let store else { return [] }
        if let g = group { return store.groups[g] ?? [] }
        return store.others
    }

    func onAppear() {
        isVisible = true
        guard !isPrimed else { return }
        isPrimed = true
        displayedIDs.removeAll(keepingCapacity: true)
        nextIndex = 0
        startDrain(initial: true)
    }

    func onDisappear() {
        isVisible = false
        drainTask?.cancel()
        drainTask = nil
    }

    func openDetail(at idx: Int) {
        selectedIndex = idx
        pauseDrain = true
        PhotoThumbCache.shared.suspend()
        showDetail = true
    }

    func detailDismissed() {
        PhotoThumbCache.shared.resume()
        pauseDrain = false
    }

    func preheat(around visibleIndex: Int) {
        if showDetail { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastPreheatAt > preheatWindow else { return }
        lastPreheatAt = now

        let lo = max(0, visibleIndex - 36)
        let hi = min(displayedIDs.count - 1, visibleIndex + 36)
        guard lo <= hi else { return }
        let ids = Array(displayedIDs[lo...hi])
        PhotoThumbCache.shared.preheat(ids: ids, size: thumbSize)
    }

    private func startDrain(initial: Bool) {
        drainTask?.cancel()
        let firstChunk = 180
        let laterChunk = 60

        drainTask = Task { @MainActor in
            while !Task.isCancelled {
                if pauseDrain {
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    continue
                }

                let src = sourceIDs
                guard nextIndex < src.count else {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }

                let chunk = displayedIDs.isEmpty ? firstChunk : laterChunk
                let end = min(nextIndex + chunk, src.count)
                displayedIDs.append(contentsOf: src[nextIndex..<end])
                nextIndex = end

                try? await Task.sleep(nanoseconds: 45_000_000)
            }
        }
    }
}
