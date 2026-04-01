import SwiftUI

struct LoadingStateView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.exPrimary)
                .scaleEffect(1.2)
            Text(message)
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.exBackground)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.exTextMuted)
            Text(title)
                .font(.exH3)
                .foregroundStyle(.exTextPrimary)
            if let message {
                Text(message)
                    .font(.exBody)
                    .foregroundStyle(.exTextSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                ActionButton(title: actionTitle, variant: .secondary, action: action)
                    .frame(width: 200)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.exError)
            Text("Something went wrong")
                .font(.exH3)
                .foregroundStyle(.exTextPrimary)
            Text(message)
                .font(.exBody)
                .foregroundStyle(.exTextSecondary)
                .multilineTextAlignment(.center)
            if let retryAction {
                ActionButton(title: "Try Again", variant: .secondary, action: retryAction)
                    .frame(width: 160)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
