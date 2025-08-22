// ImageDetailViewModel.swift
import Foundation
import SwiftUI

@MainActor
final class ImageDetailViewModel: ObservableObject {
    @Published var index: Int
    let assetIDs: [String]

    init(assetIDs: [String], startIndex: Int) {
        self.assetIDs = assetIDs
        self.index = startIndex
    }
}
