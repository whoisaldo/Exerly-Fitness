import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = ExRadius.card
    var padding: CGFloat = ExSpacing.page
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .glassCard(cornerRadius: cornerRadius)
    }
}
