//
//  CollectionViewItem.swift
//  Ohia
//
//  Created by iain on 06/10/2023.
//

import Cocoa

class CollectionViewItem: NSCollectionViewItem {
    @IBOutlet weak var titleLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView?.layer?.cornerRadius = 6
    }
}
