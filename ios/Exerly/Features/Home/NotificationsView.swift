import SwiftUI

struct NotificationsView: View {
    var body: some View {
        EmptyStateView(
            icon: "bell.slash",
            title: "No Notifications",
            message: "You're all caught up! Check back later."
        )
        .background(Color.exBackground)
        .navigationTitle("Notifications")
    }
}
