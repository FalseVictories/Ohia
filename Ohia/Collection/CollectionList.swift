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
        List(selection: $model.selectedItems) {
            Section(header: CollectionListHeaderView(username: username, items: items, state: state)) {
                ForEach(items) { item in
                    CollectionItemRow(item: item)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.clear)
    }
}

#Preview {
    CollectionList(state: .loaded, username: "Jason", items: [])
}
