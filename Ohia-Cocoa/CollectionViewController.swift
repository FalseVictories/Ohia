//
//  CollectionViewController.swift
//  Ohia
//
//  Created by iain on 06/10/2023.
//

import AppKit
import Foundation

final class CollectionViewController: NSViewController {
    @IBOutlet weak var collectionView: NSCollectionView!
    
    @IBOutlet weak var scrollView: NSScrollView!
    
    override func viewDidLoad() {
        configureCollectionView()
    }
    
    fileprivate func configureCollectionView() {
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 128, height: 168)
        flowLayout.minimumLineSpacing = 20.0
        flowLayout.minimumInteritemSpacing = 20.0
        collectionView.collectionViewLayout = flowLayout
        
        scrollView.wantsLayer = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = NSColor.clear
        scrollView.layer?.backgroundColor = NSColor.clear.cgColor
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }
}

extension NSUserInterfaceItemIdentifier {
    static let collectionViewItem = NSUserInterfaceItemIdentifier("CollectionViewItem")
}

extension CollectionViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        40
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: .collectionViewItem, for: indexPath)
        guard let item = item as? CollectionViewItem else {
            return item
        }
        
        return item
    }
}
