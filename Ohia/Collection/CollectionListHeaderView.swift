//
//  CollectionListHeaderView.swift
//  Ohia
//
//  Created by iain on 18/10/2023.
//

import Dependencies
import PopoverMenu
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
    
    @ViewBuilder var menu : some View {
        MenuItem(image: Image(systemSymbol: .powerCircleFill), action: {
            model.logOut()
        }) {
            Text("Log Out")
        }
    }

    var body: some View {
        HStack (alignment: .center) {
            MenuButton {
                // FIXME: Put this into a separate function
                CachedAsyncImage(url: model.avatarUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .frame(width:36, height: 36)
                            .clipShape(Circle())
                    } else if phase.error != nil {
                        Color.red
                    } else {
                        Color.clear
                    }
                }
                .frame(width:36, height: 36)
            } menu: { context in
                MenuItem(image: Image(systemSymbol: .powerCircleFill), action: {
                    context.closeMenu()
                    model.logOut()
                }) {
                    Text("Log Out")
                }
            }

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
                    model.downloadItems()
                },
                       label: {
                    Text("Download All")
                })
            }
        }
    }
}

extension CollectionListHeaderView {
}

#Preview {
    Group {
        CollectionListHeaderView(username: "Jason", items: [], state: .none)
        CollectionListHeaderView(username: "Jason", items: [], state: .loading)
        CollectionListHeaderView(username: "Jason", items: [], state: .loaded)
    }
}
