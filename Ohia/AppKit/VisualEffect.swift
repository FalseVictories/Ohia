//
//  VisualEffect.swift
//  Ohia
//
//  Created by iain on 07/10/2023.
//

import SwiftUI

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> some NSView {
        let view = NSVisualEffectView()
        view.autoresizingMask = [.width, .height]
        return view
    }
        
    func updateNSView(_ nsView: NSViewType, context: Context) {
    }
}

#Preview {
    VisualEffect()
}
