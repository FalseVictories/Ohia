//
//  HoverButton.swift
//  Ohia
//
//  Created by iain on 13/10/2023.
//

import SwiftUI
import SFSafeSymbols

struct HoverButton: View {
    @State private var isHovered: Bool = false
    @ObservedObject var item: OhiaItem
    let action: () -> ()
    
    var body: some View {
        Button(action: action,
               label: {
            Image(systemSymbol: symbol(for: item.state))
                .padding(2)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .trim(from: isHovered ? 0 : 1, to: 1)
                        .fill(Color.gray)
                        .opacity(isHovered ? 0.8 : 1)
                }
        })
        .buttonStyle(.borderless)
        .controlSize(.small)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

extension HoverButton {
    private func symbol(for state: OhiaItem.State) -> SFSymbol {
        switch state {
        case .none:
            return SFSymbol.faceSmiling
            
        case .waiting, .connecting, .downloading:
            return SFSymbol.xCircle
            
        case .downloaded:
            return SFSymbol.magnifyingglass
            
        case .maybeDownloaded:
            return SFSymbol.info
            
        case .cancelled, .error, .failed:
            return SFSymbol.arrowClockwise
        }
    }
}

#Preview {
    Group {
        ForEach (OhiaItem.State.allCases) { state in
            HoverButton(item: OhiaItem.preview(for: state)) {
                
            }
        }
    }
}
