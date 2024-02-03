//
//  CollectionItemRow.swift
//  Ohia
//
//  Created by iain on 07/10/2023.
//

import SFSafeSymbols
import SwiftUI

struct CollectionItemRow: View {
    @ObservedObject var item: OhiaItem
    
    @EnvironmentObject var model: OhiaViewModel
    
    var body: some View {
        HStack (alignment: .center) {
            ZStack(alignment: .bottomTrailing) {
                item.thumbnail
                    .resizable()
                    .cornerRadius(6)
                    .frame(width:64, height: 64)

                if item.isNew {
                    Text("New")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .background(Color.accentColor.opacity(0.4))
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                }
                
                if item.isPreorder {
                    Text("Preorder")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .background(Color.accentColor.opacity(0.4))
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                }
            }
            VStack (alignment: .leading, spacing: 0) {
                Text(item.artist)
                Text(item.title)
                if item.state == .downloading {
                    DownloadProgress(progress: item.downloadProgress)
                } else {
                    DownloadStateInfo(item: item)
                }
            }
        }
        .padding(8)
        .contextMenu(menuItems: {
            Button("Mark As Not Downloaded") {
                model.markItem(item, downloaded: false)
            }
            .disabled(item.state == .none)
            Button("Reveal in Finder") {
                model.open(item: item)
            }
            .disabled(item.state != .downloaded)
        })
    }
}

extension CollectionItemRow {
    
}
    
#Preview {
    Group {
        ForEach (OhiaItem.State.allCases) { state in
            CollectionItemRow(item: OhiaItem.preview(for: state))
        }
        CollectionItemRow(item: OhiaItem.new())
    }
}

