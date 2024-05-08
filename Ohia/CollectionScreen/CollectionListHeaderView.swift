//
//  CollectionListHeaderView.swift
//  Ohia
//
//  Created by iain on 18/10/2023.
//

import CachedAsyncImage
import Dependencies
import OSLog
import SwiftUI

struct CollectionListHeaderView: View {
    @Dependency(\.downloadService) var downloadService: any DownloadService
    
    @EnvironmentObject var model: OhiaViewModel
    
    var username: String?
    var items: [OhiaItem]
    var state: OhiaViewModel.CollectionState
    
    var headerText: String {
        if state == .loaded {
            if username != nil {
                return String(format: NSLocalizedString("%@'s Collection - %d items", comment: ""), username!, items.count)
            }
        } 
        
        return NSLocalizedString("Loading Collection", comment: "")
    }
    
    var body: some View {
        HStack (alignment: .center) {
            Menu {
                Button("Log Out") {
                    model.logOut()
                }
            } label: {
                if model.avatarUrl == nil {
                    Image(.defaultIcon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
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
                MenuButton(title: "Download All") {
                    Button("Download Selected") {
                        model.downloadItemsOf(type: .selected)
                    }
                    .disabled(model.selectedItems.isEmpty)
                    Button("Download New") {
                        model.downloadItemsOf(type: .new)
                    }
                } action: {
                    model.downloadItemsOf(type: .all)
                }
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
    .environmentObject(OhiaViewModel())
}
