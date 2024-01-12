//
//  RingBuffer.swift
//  decompressor
//
//  Created by iain on 28/12/2023.
//

import Foundation

/// A very simple 4 byte ringbuffer
class RingBuffer {
    private var buffer: [UInt8] = [0, 0, 0, 0]
    private var currentIndex = 0
    private var size = 4
    
    public private(set) var count = 0
}

extension RingBuffer {
    /// Puts a value into the ringbuffer at the current position and moves to the next position
    func push(_ value: UInt8) {
        buffer[currentIndex] = value
        currentIndex = (currentIndex + 1) % size

        count = min(count + 1, size)
    }
    
    /// Returns the value at the current position of the buffer
    func peek() -> UInt8 {
        buffer[currentIndex]
    }

    /// Calculates a 32bit integer from the 4 bytes of the ringbuffer
    func totalValue() -> UInt32 {
        var value = UInt32(buffer[bufferIndex(for: 3)]) << 24
        value |= UInt32(buffer[bufferIndex(for: 2)]) << 16
        value |= UInt32(buffer[bufferIndex(for: 1)]) << 8
        value |= UInt32(buffer[bufferIndex(for: 0)])
        
        return value
    }    
    
    /// Clears the buffer
    func clear() {
        currentIndex = 0
        count = 0
    }
}

private extension RingBuffer {
    /// Converts an index to a buffer position
    func bufferIndex(for index: Int) -> Int {
        (currentIndex + index) % size
    }
}
