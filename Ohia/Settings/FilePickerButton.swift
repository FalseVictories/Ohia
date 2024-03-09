//
//  FilePickerButton.swift
//  Ohia
//
//  Created by iain on 24/10/2023.
//

import SwiftUI

struct FilePickerButton: View {
    @Binding var folder: URL?
    
    var body: some View {
        Button {
            openFilePicker()
        } label: {
            Text(displayUrl(folder))
        }
    }
}

extension FilePickerButton {
    private func displayUrl(_ url: URL?) -> String {
        if let url {
            return (url.abbreviatingWithTildeInPath)
        }
        return "<No folder>"
    }
    
    @MainActor
    private func openFilePicker() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == .OK {
            folder = openPanel.url
        }
    }
}

#Preview {
    Group {
        FilePickerButton(folder: .constant(nil))
        FilePickerButton(folder: .constant(URL(string:"file:///Users/iain/Downloads")))
    }
}
