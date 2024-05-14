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
    @StateObject private var viewModel = OhiaViewModel()

    var body: some Scene {
        Window("Ohia", id: "main") {
            ZStack {
                VisualEffect()
                if viewModel.showErrorScreen {
                    ErrorScreen()
                        .environmentObject(viewModel)
                } else if viewModel.showAboutScreen {
                    AboutScreen(displayed: $viewModel.showAboutScreen)
                } else if viewModel.isSignedIn {
                    CollectionContentView(state: viewModel.collectionState,
                                          username: viewModel.name,
                                          items: viewModel.items)
                    .environmentObject(viewModel)
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                        viewModel.closeDatabase()
                    }
                } else {
                    WebView(webView: viewModel.webModel.webView)
                        .frame(width: 800, height: 600)
                        .onAppear {
                            viewModel.webModel.loadUrl()
                        }
                }
            }
        }
        .commands {
            CommandGroup(before: .newItem) {
                Button("Update Collection") {
                    viewModel.updateCollection()
                }
            }
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button("About Ohia") { viewModel.showAboutScreen.toggle() }
            }
        }
#if os(macOS)
        Settings {
            SettingsView(settingsModel: viewModel.settings)
        }
#endif
    }
}
