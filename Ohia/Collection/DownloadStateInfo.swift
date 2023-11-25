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
            Text(DownloadStateInfo.stringForState(item.state))
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
    static func stringForState(_ state: OhiaItem.State) -> String {
        switch state {
        case .cancelled:
            return "Cancelled"
            
        case .connecting:
            return "Connecting…"
            
        case .downloaded:
            return "Downloaded"
            
        case .error:
            return "Error"
            
        case .waiting:
            return "Waiting…"
            
        case .none, .downloading:
            return ""
        }
    }
}

#Preview {
    DownloadStateInfo(item: OhiaItem.preview(for: .downloaded))
}
