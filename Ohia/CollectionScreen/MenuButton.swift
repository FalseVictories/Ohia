//
//  MenuButton.swift
//  Ohia
//
//  Created by iain on 18/01/2024.
//

import SwiftUI

struct MenuButton<Content: View>: View {
    var title: String
    
    @ViewBuilder var content: () -> Content
    var action: () -> ()
    
    var body: some View {
        HStack(spacing: 0){
            Button("Download All") {
                action()
            }
            
            Menu {
                content()
            } label: {
                Image(systemSymbol: .arrowtriangleDownFill)
            }
            .menuIndicator(.hidden)
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    MenuButton (title: "Download All") {
        Text("Test menu 1")
        Text("Test menu 2")
    } action: {
        print("Click")
    }
        .padding(50)
}
