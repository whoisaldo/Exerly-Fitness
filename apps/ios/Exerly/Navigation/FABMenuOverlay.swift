import SwiftUI

struct FABMenuOverlay: View {
    let onLogActivity: () -> Void
    let onLogFood: () -> Void
    let onLogSleep: () -> Void
    let onDismiss: () -> Void

    @State private var showItems = false

    private let items: [(String, String, Color, () -> Void)] = []

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 14) {
                Spacer()

                fabItem(icon: "bed.double.fill", label: "Log Sleep",
                        color: .exInfo, delay: 0.1, action: onLogSleep)

                fabItem(icon: "fork.knife", label: "Log Food",
                        color: .exAccent, delay: 0.05, action: onLogFood)

                fabItem(icon: "figure.run", label: "Log Activity",
                        color: .exSuccess, delay: 0, action: onLogActivity)

                Spacer().frame(height: 90)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showItems = true
            }
        }
    }

    private func fabItem(
        icon: String, label: String, color: Color,
        delay: Double, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(Circle())

                Text(label)
                    .font(.exBodyMedium)
                    .foregroundStyle(.exTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: 22)
        }
        .padding(.horizontal, 60)
        .offset(y: showItems ? 0 : 60)
        .opacity(showItems ? 1 : 0)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.75).delay(delay),
            value: showItems
        )
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3)) {
            showItems = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}
