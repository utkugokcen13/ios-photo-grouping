//
//  ListUpdateCoordinator.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import UIKit

final class ListUpdateCoordinator {
    private weak var collectionView: UICollectionView?
    private var dataSource: UICollectionViewDiffableDataSource<HomeViewController.Section, HomeViewController.Item>?
    private var currentItems: [HomeViewController.Item] = []
    private var isNavigating = false
    private var pendingRebuild = false

    var isInteracting: Bool {
        guard let cv = collectionView else { return false }
        return cv.isDragging || cv.isDecelerating || cv.isTracking || isNavigating
    }

    init(collectionView: UICollectionView,
         dataSource: UICollectionViewDiffableDataSource<HomeViewController.Section, HomeViewController.Item>) {
        self.collectionView = collectionView
        self.dataSource = dataSource
    }

    func beginNavigationPriorityWindow() {
        isNavigating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isNavigating = false
            if self?.pendingRebuild == true {
                self?.pendingRebuild = false
                self?.rebuildSnapshot(animated: false)
            }
        }
    }

    func setItems(_ newItems: [HomeViewController.Item]) {
        let oldIDs = Set(currentItems.map { $0.id })
        let newIDs = Set(newItems.map { $0.id })

        currentItems = newItems

        if oldIDs == newIDs {
            reconfigureItems(ids: Array(newIDs))
        } else {
            if isInteracting {
                pendingRebuild = true
            } else {
                rebuildSnapshot(animated: false)
            }
        }
    }

    private func rebuildSnapshot(animated: Bool) {
        guard let ds = dataSource else { return }
        var snap = NSDiffableDataSourceSnapshot<HomeViewController.Section, HomeViewController.Item>()
        snap.appendSections([.main])
        snap.appendItems(currentItems, toSection: .main)
        ds.apply(snap, animatingDifferences: animated)
    }

    private func reconfigureItems(ids: [HomeViewController.GroupID]) {
        guard let ds = dataSource else { return }

        var snap = NSDiffableDataSourceSnapshot<HomeViewController.Section, HomeViewController.Item>()
        snap.appendSections([.main])
        snap.appendItems(currentItems, toSection: .main)
        ds.apply(snap, animatingDifferences: false)
    }
}
