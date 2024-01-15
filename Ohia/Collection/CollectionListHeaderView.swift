//
//  CollectionListHeaderView.swift
//  Ohia
//
//  Created by iain on 18/10/2023.
//

import Dependencies
import SwiftUI
import CachedAsyncImage

struct CollectionListHeaderView: View {
    @Dependency(\.downloadService) var downloadService: any DownloadService
    
    @EnvironmentObject var model: OhiaViewModel
    
    var username: String?
    var items: [OhiaItem]
    var state: OhiaViewModel.CollectionState

    var headerText: String {
        if state == .loaded {
            if username != nil {
                return "\(username!)'s Collection - \(items.count) items"
            }
        } 
        
        return "Loading Collection"
    }
    
    var body: some View {
        HStack (alignment: .center) {
            Menu {
                Button("Log Out") {
                    model.logOut()
                }
            } label: {
                CachedAsyncImage(url: model.avatarUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                    } else if phase.error != nil {
                        Color.red
                    } else {
                        Color.clear
                    }
                }
            }
            .clipShape(Circle())
            .menuIndicator(.hidden)
            .menuStyle(.button)
            .buttonStyle(.borderless)

            Text(headerText)
                .font(.title)
                .padding()
            
            if state != .loaded {
                ProgressView()
                    .controlSize(.small)
                    .padding()
            }
            
            Spacer()
            
            if state == .loaded && items.count > 0 {
                Button(action: {
                    do {
                        try model.downloadItems()
                    } catch {
                        print("Error download")
                    }
                }, label: {
                    Text("Download All")
                })
                .disabled(model.currentAction == .downloading)
            }
        }
        .frame(height: 50)
    }
}

#Preview {
    Group {
        CollectionListHeaderView(username: "Jason", items: [], state: .none)
        CollectionListHeaderView(username: "Jason", items: [], state: .loading)
        CollectionListHeaderView(username: "Jason", items: [], state: .loaded)
    }
}
