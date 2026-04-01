import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: MainTab
    @Binding var showFABMenu: Bool

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.library)
            fabButton
            tabButton(.progress)
            tabButton(.profile)
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(tabBarBackground)
    }

    private func tabButton(_ tab: MainTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .medium))
                    .symbolEffect(.bounce, value: selectedTab == tab)
                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? .exPrimary : .exTextMuted)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                if selectedTab == tab {
                    Capsule()
                        .fill(Color.exPrimary)
                        .frame(width: 24, height: 3)
                        .offset(y: -10)
                        .shadow(color: .exPrimary.opacity(0.5), radius: 6)
                }
            }
        }
    }

    private var fabButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showFABMenu.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(LinearGradient.exPrimaryGradient)
                    .frame(width: 56, height: 56)
                    .primaryGlow(radius: 12, opacity: 0.5)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(showFABMenu ? 45 : 0))
            }
        }
        .offset(y: -16)
        .frame(maxWidth: .infinity)
    }

    private var tabBarBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(Color.exSurface1.opacity(0.7))
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.exGlassBorder)
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .bottom)
    }
}
