//
//  OhiaApp.swift
//  Ohia
//
//  Created by iain on 07/10/2023.
//

import BCKit
import OSLog
import SwiftUI

@main
@MainActor
struct OhiaApp: App {
    @ObservedObject private var viewModel = OhiaViewModel()
    
    var body: some Scene {
        Window("Ohia", id: "main") {
            if viewModel.isSignedIn {
                ZStack {
                    VisualEffect()
                    CollectionContentView(state: viewModel.collectionState,
                                          username: viewModel.name,
                                          items: viewModel.items)
                    .environmentObject(viewModel)
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                        viewModel.closeDatabase()
                    }
                }
            } else {
                WebView(webView: WebViewModel().webView)
            }
        }
#if os(macOS)
        Settings {
            SettingsView(settingsModel: viewModel.settings)
        }
#endif
    }
}
