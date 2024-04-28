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
            LabeledContent("Download Folder:") {
                FilePickerButton(folder: $settingsModel.selectedDownloadFolder)
            }
            
            Picker("Download Format:", selection: $settingsModel.selectedFileFormat) {
                Text("Flac").tag(FileFormat.flac)
                Text("MP3 v0").tag(FileFormat.mp3_v0)
                Text("MP3 320").tag(FileFormat.mp3_320)
                Text("Wav").tag(FileFormat.wav)
                Text("AAC High").tag(FileFormat.aachi)
                Text("Ogg Vorbis").tag(FileFormat.vorbis)
                Text("ALAC").tag(FileFormat.alac)
                Text("AIFF Lossless").tag(FileFormat.aiff)
            }

            Spacer()
                .frame(height: 20)
            
            // Limit to 30 downloads at once? Dunno. Seems high enough to not annoy anyone.
            TextField("Max concurrent downloads:",
                      value: $settingsModel.maxDownloads,
                      format: .ranged(1...30))
            Toggle("Download pre-orders", isOn: $settingsModel.downloadPreorders)
            
            Spacer()
                .frame(height: 20)
            
            Toggle("Decompress downloads", isOn: $settingsModel.decompressDownloads)
            Picker("Create Folders:", selection: $settingsModel.createFolderStructure) {
                Text("None").tag(FolderStructure.none)
                Text("Artist - Title /").tag(FolderStructure.single)
                Text("Artist / Title /").tag(FolderStructure.multi)
                Text("Artist / Artist - Title /").tag(FolderStructure.bandcamp)
            }.disabled(!settingsModel.decompressDownloads)
        }
        .padding()
    }
}

#Preview {
    SettingsView(settingsModel: SettingsModel())
}
