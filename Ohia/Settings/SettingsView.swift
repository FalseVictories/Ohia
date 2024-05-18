//
//  SettingsView.swift
//  Ohia
//
//  Created by iain on 24/10/2023.
//

import BCKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsModel: SettingsModel
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Download Folder:") {
                    FilePickerButton(folder: $settingsModel.selectedDownloadFolder)
                }
                
                Picker(selection: $settingsModel.selectedFileFormat, content: {
                    Text("Flac").tag(FileFormat.flac)
                    Text("MP3 v0").tag(FileFormat.mp3_v0)
                    Text("MP3 320").tag(FileFormat.mp3_320)
                    Text("Wav").tag(FileFormat.wav)
                    Text("AAC High").tag(FileFormat.aachi)
                    Text("Ogg Vorbis").tag(FileFormat.vorbis)
                    Text("ALAC").tag(FileFormat.alac)
                    Text("AIFF Lossless").tag(FileFormat.aiff)
                    
                }, label: {
                    Text("Download Format")
                })
                
                // Limit to 30 downloads at once? Dunno. Seems high enough to not annoy anyone.
                
                LabeledContent(content: {
                    Text("\(settingsModel.maxDownloads)")
                    Stepper(value: $settingsModel.maxDownloads,
                            label: {})
                }, label: {
                    Text("Maximum concurrent downloads")
                })
                
                Toggle(isOn: $settingsModel.downloadPreorders, label: {
                    Text("Download pre-orders")
                })
                
            } header: {
            }
            
            Section {
                Toggle(isOn: $settingsModel.overwrite, label: {
                    Text("Overwrite existing downloads")
                })
                
                Toggle(isOn: $settingsModel.decompressDownloads, label: {
                    Text("Decompress downloads")
                })
                
                Picker(selection: $settingsModel.createFolderStructure, content: {
                    Text("None").tag(FolderStructure.none)
                    Text("Artist - Title /").tag(FolderStructure.single)
                    Text("Artist / Title /").tag(FolderStructure.multi)
                    Text("Artist / Artist - Title /").tag(FolderStructure.bandcamp)
                    
                }, label: {
                    Text("Create Folders:")
                })
                .disabled(!settingsModel.decompressDownloads)
            } header: {
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView(settingsModel: SettingsModel())
}
