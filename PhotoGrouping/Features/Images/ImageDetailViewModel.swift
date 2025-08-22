//
//  ImageDetailViewModel.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

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
