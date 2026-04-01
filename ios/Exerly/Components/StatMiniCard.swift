import SwiftUI

struct StatMiniCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.exStatSmall)
                .foregroundStyle(.exTextPrimary)
            Text(label)
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 14)
    }
}
