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

    @StateObject private var vm = GroupDetailViewModel()

    private let bottomSentinel = "bottom-sentinel"

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView {
                    LazyVGrid(columns: vm.columns, spacing: 4) {
                        ForEach(Array(vm.displayedIDs.enumerated()), id: \.element) { idx, id in
                            Button {
                                vm.openDetail(at: idx)
                            } label: {
                                ThumbnailCell(id: id, targetSize: vm.thumbSize)
                                    .contentShape(Rectangle())
                                    .onAppear { vm.preheat(around: idx) }
                            }
                            .buttonStyle(.plain)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(bottomSentinel)
                    }
                    .padding(.horizontal, 6)
                    .transaction { $0.animation = nil }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(bottomSentinel, anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(16)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
                            .shadow(radius: 6, x: 0, y: 3)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
                    .accessibilityLabel("Scroll to bottom")
                    .allowsHitTesting(!vm.showDetail)
                }
            }
            .navigationTitle(group?.rawValue.uppercased() ?? "Others")
            .fullScreenCover(isPresented: $vm.showDetail, onDismiss: {
                vm.detailDismissed()
            }) {
                NavigationView {
                    ImageDetailView(assetIDs: vm.displayedIDs, startIndex: vm.selectedIndex)
                        .background(Color.black.ignoresSafeArea())
                        .id(vm.selectedIndex)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
            .onAppear {
                vm.bind(group: group, store: store)
                vm.onAppear()
            }
            .onDisappear {
                vm.onDisappear()
            }
        }
    }
}

private struct ThumbnailCell: View {
    @StateObject private var tvm: ThumbnailViewModel
    init(id: String, targetSize: CGSize) {
        _tvm = StateObject(wrappedValue: ThumbnailViewModel(id: id, targetSize: targetSize))
    }

    var body: some View {
        Group {
            if let img = tvm.image {
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
        .animation(nil, value: tvm.image)
        .onAppear { tvm.load() }
        .onDisappear { tvm.cancel() }
        .id(tvm.id)
        .contentShape(Rectangle())
    }
}
