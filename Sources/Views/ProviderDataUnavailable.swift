import SwiftUI

struct ProviderDataUnavailable: View {
    let message: String
    var body: some View {
        Text(L10n.tr(message))
            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
            .multilineTextAlignment(.center)
            .padding(.horizontal, IslandPanelLayout.columnInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
