//
//  ContentView.swift
//  Ohia
//
//  Created by iain on 07/10/2023.
//

import BCKit
import SwiftUI

struct CollectionContentView: View {
    @EnvironmentObject var model: OhiaViewModel
    @State var downloadProgressIsVisible = false
    
    let state: OhiaViewModel.CollectionState
    let username: String?
    
    let items: [OhiaItem]
    
    var body: some View {
        VStack {
            CollectionList(state: state, username: username, items: items)
            if downloadProgressIsVisible {
                CollectionDownloadProgress(current: model.currentDownload, total: model.totalDownloads)
                    .transition(.move(edge: .bottom))
            }
        }
        .onReceive(model.$currentAction) { state in
            withAnimation {
                downloadProgressIsVisible = state == .downloading
            }
        }
    }
}

#Preview {
    CollectionContentView(state: .loaded, username: "Jason", items: [])
}
