import SwiftUI

struct UpdateProgressView: View {
    var body: some View {
        HStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Updating collection")
                .font(.title2)
        }
        .padding()
        .background(.thickMaterial)
    }
}

#Preview {
    UpdateProgressView()
}
