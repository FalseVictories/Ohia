//
//  AppDelegate.swift
//  Bandcamp Collection Manager
//
//  Created by iain on 02/10/2023.
//

import Cocoa
import Dependencies
import OSLog

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @Dependency(\.collectionService) var collectionService: any CollectionService
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !collectionService.isLoggedIn {
            // Show login controller
            Logger.Main.info("Not logged in")
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            if let loginWindow = storyboard.instantiateController(withIdentifier: "LoginWindowController") as? NSWindowController {
                loginWindow.showWindow(self)
            }
        } else {
            Logger.Main.info("Logged in - \(String(describing: Bundle.main.bundleIdentifier))")
            Task {
                await collectionService.listCollection()
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

