//
//  ErrorScreen.swift
//  Ohia
//
//  Created by iain on 12/02/2024.
//

import Dependencies
import SwiftUI

struct ColorButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? color : Color.white)
            .background(configuration.isPressed ? Color.white : color)
            .cornerRadius(6.0)
            .padding()
    }
}

struct ErrorScreen: View {
    @Dependency(\.dataStorageService) var dataStorageService: any DataStorageService
    @EnvironmentObject var model: OhiaViewModel

    var body: some View {
        VStack {
            Image(.defaultIcon)
            Text("An Error Occurred")
                .font(.title)
            if let lastError = model.lastError {
                VStack(alignment: .leading) {
                    Text(lastError.description)
                    
                    Spacer()
                        .frame(height: 24)
                    
                    if let suggestion = lastError.localizedRecoverySuggestion {
                        Text("It may be possible to fix this by:")
                        Text(suggestion)
                    }
                }
            }
            
            HStack {
                if model.lastError is DataStorageServiceError {
                    Button(action: {
                        _ = dataStorageService.resetDatabase()
                        
                        model.lastError = nil
                        model.errorShown = false
                    }) {
                        Text("Reset Database")
                            .padding(8)
                    }
                    .buttonStyle(ColorButtonStyle(color: .red))
                }
                Spacer()
                
                if model.lastErrorIsFatal {
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Text("Quit")
                            .padding(8)
                    }
                    
                    Button(action: {
                        model.resetError()
                    }) {
                        Text("Log In")
                            .padding(8)
                    }
                    .buttonStyle(ColorButtonStyle(color: .accentColor))
                } else {
                    Button(action: {
                        model.resetError()
                    }) {
                        Text("Close")
                            .padding(8)
                    }
                    .buttonStyle(ColorButtonStyle(color: .accentColor))
                }
            }
            .frame(maxWidth: 400)
        }
    }
}

#Preview {
    ErrorScreen()
}
