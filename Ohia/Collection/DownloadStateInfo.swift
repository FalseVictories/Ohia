//
//  DownloadStateInfo.swift
//  Ohia
//
//  Created by iain on 18/10/2023.
//

import SwiftUI

struct DownloadStateInfo: View {
    @ObservedObject var item: OhiaItem
    
    var body: some View {
        HStack {
            Text(DownloadStateInfo.text(for: item))

            /* - Button looks ugly
            if item.state != .none {
                HoverButton(item: item) {
                    
                }
            }
             */
        }
    }
}

extension DownloadStateInfo {
    static func text(for item: OhiaItem) -> String {
        if let error = item.lastError {
            return NSLocalizedString("Error: \(error)", comment: "")
        } else {
            return stringForState(item.state)
        }
    }
    
    static func stringForState(_ state: OhiaItem.State) -> String {
        switch state {
        case .cancelled:
            return NSLocalizedString("Cancelled", comment: "")
            
        case .connecting:
            return NSLocalizedString("Connecting…", comment: "")
            
        case .downloaded:
            return NSLocalizedString("Downloaded", comment: "")
            
        case .error:
            return NSLocalizedString("Error", comment: "")
            
        case .waiting:
            return NSLocalizedString("Waiting…", comment: "")
            
        case .none, .downloading:
            return ""
        }
    }
}

#Preview {
    DownloadStateInfo(item: OhiaItem.preview(for: .downloaded))
}
