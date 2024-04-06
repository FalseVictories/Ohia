//
//  DownloadStateInfo.swift
//  Ohia
//
//  Created by iain on 18/10/2023.
//

import SwiftUI

struct DownloadStateInfo: View {
    @ObservedObject var item: OhiaItem
    @State var showErrorPopover = false
    
    var body: some View {
        HStack {
            Text(DownloadStateInfo.text(for: item))

            if item.state == .error {
                Button(action: {
                    showErrorPopover.toggle()
                }, label: {
                    Image(systemSymbol: .infoCircleFill)
                        .frame(width: 16, height: 16)
                })
                .buttonStyle(.borderless)
                .popover(isPresented: $showErrorPopover, content: {
                    if let error = item.lastError {
                        Text(DownloadStateInfo.string(for: error))
                            .padding()
                    }
                })
            }
        }
    }
}

extension DownloadStateInfo {
    static func string(for error: Error) -> String {
        return "\(error)"
    }
    
    static func text(for item: OhiaItem) -> String {
        if let error = item.lastError {
            return NSLocalizedString("Error:", comment: "") + " \(error.localizedDescription)"
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
            
        case .maybeDownloaded:
            return NSLocalizedString("Maybe already downloaded", comment: "")
            
        case .error:
            return NSLocalizedString("Error", comment: "")
            
        case .waiting:
            return NSLocalizedString("Waiting…", comment: "")
            
        case .failed:
            return NSLocalizedString("Failed", comment: "")
            
        case .none, .downloading:
            return ""
        }
    }
}

#Preview {
    DownloadStateInfo(item: OhiaItem.preview(for: .error))
}
