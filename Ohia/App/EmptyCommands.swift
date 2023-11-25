//
//  EmptyCommands.swift
//  Ohia
//
//  Created by iain on 24/10/2023.
//

import SwiftUI

struct EmptyCommands: View {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            EmptyView()
        }
        CommandGroup(replacing: ., addition: <#T##() -> View#>)
    }
}

#Preview {
    EmptyCommands()
}
