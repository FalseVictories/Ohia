//
//  Queue.swift
//  Ohia
//
//  Created by iain on 11/10/2023.
//

import Foundation

struct Queue<T> {
    var queue: [T] = []
    
    var isEmpty: Bool {
        queue.isEmpty
    }
    
    mutating func enqueue(element: T) {
        queue.append(element)
    }
    
    mutating func dequeue() -> T? {
        return queue.removeFirst()
    }
}
