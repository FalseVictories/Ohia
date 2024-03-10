//
//  RangeIntegerStyle.swift
//  Ohia
//
//  Created by iain on 10/03/2024.
//

import Foundation

// From https://www.avanderlee.com/swiftui/formatstyle-formatter-restrict-textfield-input/
struct RangeIntegerStyle: ParseableFormatStyle {
    var parseStrategy: RangeIntegerStrategy = .init()
    let range: ClosedRange<Int>
    
    func format(_ value: Int) -> String {
        let constrainedValue = min(max(value, range.lowerBound), range.upperBound)
        return "\(constrainedValue)"
    }
}

/// Allow writing `.ranged(0...5)` instead of `RangeIntegerStyle(range: 0...5)`.
extension FormatStyle where Self == RangeIntegerStyle {
    static func ranged(_ range: ClosedRange<Int>) -> RangeIntegerStyle {
        return RangeIntegerStyle(range: range)
    }
}

struct RangeIntegerStrategy: ParseStrategy {
    func parse(_ value: String) throws -> Int {
        return Int(value) ?? 1
    }
}
