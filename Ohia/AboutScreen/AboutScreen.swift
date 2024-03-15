//
//  AboutScreen.swift
//  Ohia
//
//  Created by iain on 15/03/2024.
//

import Foundation
import SwiftUI

struct AboutScreen: View {
    @Binding var displayed: Bool
    
    var body: some View {
        HStack {
            Image(.aboutIcon)
                .frame(width: 250, height: 250)
            VStack {
                VStack {
                    Text("Ohia")
                        .font(.title)
                    Text("By iain")
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))
                    Text("Copyright (C) 2024 False Victories")
                    Text("Feedback: ohiafeedback@falsevictories.com")
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    Text("\"In the sirens and the silences now\"")
                        .font(.subheadline.italic())
                }
                .padding()
                
                HStack {
                    Button(action: {
                        displayed.toggle()
                    }) {
                        Text("Close")
                    }
                }
            }
            .padding()
        }
    }
    
    func getHighResolutionAppIconName() -> String? {
        guard let infoPlist = Bundle.main.infoDictionary else { return nil }
        guard let bundleIcons = infoPlist["CFBundleIcons"] as? NSDictionary else { return nil }
        guard let bundlePrimaryIcon = bundleIcons["CFBundlePrimaryIcon"] as? NSDictionary else { return nil }
        guard let bundleIconFiles = bundlePrimaryIcon["CFBundleIconFiles"] as? NSArray else { return nil }
        guard let appIcon = bundleIconFiles.lastObject as? String else { return nil }
        return appIcon
    }
}
