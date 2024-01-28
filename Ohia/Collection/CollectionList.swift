//
//  CollectionList.swift
//  Ohia
//
//  Created by iain on 12/10/2023.
//

import Dependencies
import SwiftUI

struct CollectionList: View {
    @EnvironmentObject var model: OhiaViewModel
    
    var state: OhiaViewModel.CollectionState
    var username: String?
    var items: [OhiaItem]

    var body: some View {
        ZStack (alignment: .topLeading) {
            List(selection: $model.selectedItems) {
                ForEach(items) { item in
                    CollectionItemRow(item: item)
                }
            }
            .padding(EdgeInsets(top: 50, leading: 0, bottom: 0, trailing: 0))
            .scrollContentBackground(.hidden)
            .background(.clear)
            CollectionListHeaderView(username: username, items: items, state: state)
                .padding(8)
                .background(.thinMaterial)
        }
    }
}

#Preview {
    CollectionList(state: .loaded, username: "Jason", items: [])
}
