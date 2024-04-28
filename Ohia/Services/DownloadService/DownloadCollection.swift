//
//  DownloadCollection.swift
//  Ohia
//
//  Created by iain on 27/04/2024.
//

import Foundation

final actor DownloadCollection<T> {
    var items: [T]
    
    var count: Int {
        items.count
    }
    
    init(items: [T]) {
        self.items = items
    }
    
    func next() -> T? {
        if items.count == 0 {
            return nil
        }
        
        return items.remove(at: 0)
    }
    
    func reschedule(element: T) {
        items.insert(element, at: 0)
    }
}
