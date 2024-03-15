//
//  CollectionDownloadProgress.swift
//  Ohia
//
//  Created by iain on 18/10/2023.
//

import SwiftUI

struct CollectionDownloadProgress: View {
    @EnvironmentObject var model: OhiaViewModel
    var current: Int
    var total: Int
    
    var body: some View {
        HStack {
            ProgressView(value: Double(current), 
                         total: Double(total)) {
                Text("Downloaded \(current) / \(total)")
                    .font(.title2)
            }
                .progressViewStyle(.linear)
            
            Button {
                model.cancelAllDownloads()
            } label: {
                Image(systemSymbol: .xCircleFill)
            }
            .buttonStyle(.borderless)
            
        }
        .padding()
        .background(.thickMaterial)
    }
}

#Preview {
    CollectionDownloadProgress(current: 4, total: 186)
}
