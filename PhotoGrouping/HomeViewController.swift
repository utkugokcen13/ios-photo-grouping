//
//  HomeViewController.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import UIKit
import SwiftUI

class HomeViewController: UIViewController {
    
    // MARK: - Types
    
    enum Section {
        case main
    }
    
    struct Item: Hashable {
        let id = UUID()
        let title: String
        let count: Int
        let group: PhotoGroup?
    }
    
    // MARK: - Properties
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    private let store = GalleryStore()
    private let scanner = ScanningService()
    private let debouncer = Debouncer(delay: 0.05)  // 0.1 -> 0.05
    
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let progressLabel = UILabel()
    private var hasStartedScanning = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupDataSource()
        setupScanner()
        
        // Show initial empty state
        rebuildSnapshot()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Start scanning only once
        if !hasStartedScanning {
            hasStartedScanning = true
            scanner.startScan()
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Groups"
        view.backgroundColor = .systemBackground
        
        // Setup progress UI
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.text = "Scanning photos: 0% (0/0)"
        progressLabel.font = .systemFont(ofSize: 14)
        progressLabel.textColor = .secondaryLabel
        
        view.addSubview(progressView)
        view.addSubview(progressLabel)
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.allowsSelection = true
        collectionView.delaysContentTouches = false
        
        collectionView.isPrefetchingEnabled = true
        collectionView.prefetchDataSource = self
        
        collectionView.register(GroupCell.self, forCellWithReuseIdentifier: GroupCell.reuseIdentifier)
        
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(80))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: GroupCell.reuseIdentifier,
                for: indexPath
            ) as! GroupCell
            cell.configure(with: item)
            return cell
        }
    }
    
    private func setupScanner() {
        scanner.delegate = self
    }
    
    private func rebuildSnapshot() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([.main])

            var items: [Item] = []

            // Add non-empty groups
            for (group, count) in store.nonEmptyGroups {
                items.append(Item(title: group.rawValue.uppercased(), count: count, group: group))
            }

            // Add Others if it has items
            if store.others.count > 0 {
                items.append(Item(title: "Others", count: store.others.count, group: nil))
            }

            snapshot.appendItems(items, toSection: .main)
            
            // Use animatingDifferences: false during scanning for better performance
            let shouldAnimate = store.processed < store.total ? false : true
            self.dataSource.apply(snapshot, animatingDifferences: shouldAnimate)
        }
    }
}

// MARK: - UICollectionViewDelegate

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let item = dataSource.itemIdentifier(for: indexPath)!
        let detail = UIHostingController(rootView: GroupDetailView(group: item.group, store: store))
        navigationController?.pushViewController(detail, animated: true)
    }
}

extension HomeViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // Prefetch data if needed
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // Cancel prefetching if needed
    }
}

// MARK: - ScanningServiceDelegate

extension HomeViewController: ScanningServiceDelegate {
    func scanningService(_ service: ScanningService, didUpdate snapshot: Snapshot) {
        store.apply(snapshot: snapshot)
        
        // Update progress UI
        DispatchQueue.main.async {
            let progress = Float(snapshot.processed) / Float(max(1, snapshot.total))
            self.progressView.setProgress(progress, animated: true)
            
            let percentage = Int(100.0 * progress)
            self.progressLabel.text = "Scanning photos: \(percentage)% (\(snapshot.processed)/\(snapshot.total))"
        }
        
        // Debounce UI snapshot updates
        debouncer.schedule { [weak self] in
            self?.rebuildSnapshot()
        }
    }
    
    func scanningServiceDidComplete(_ service: ScanningService, groups: [PhotoGroup: [String]], others: [String]) {
        // Finalize the store with complete data
        store.finalize(groups: groups, others: others)
        
        DispatchQueue.main.async {
            self.progressLabel.text = "Scan complete! (\(self.store.total) photos)"
            self.progressView.setProgress(1.0, animated: true)
        }
        
        // Rebuild snapshot with final data
        rebuildSnapshot()
    }
    
    func scanningService(_ service: ScanningService, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.progressLabel.text = "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - GroupCell

class GroupCell: UICollectionViewCell {
    static let reuseIdentifier = "GroupCell"
    
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let stackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        
        countLabel.font = .systemFont(ofSize: 14, weight: .medium)
        countLabel.textColor = .secondaryLabel
        
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(countLabel)
        
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        countLabel.text = nil
        backgroundColor = .secondarySystemBackground
    }
    
    override var isHighlighted: Bool {
        didSet {
            contentView.alpha = isHighlighted ? 0.95 : 1.0
        }
    }
    
    func configure(with item: HomeViewController.Item) {
        titleLabel.text = item.title
        countLabel.text = "\(item.count) photos"
    }
}
