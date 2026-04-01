import SwiftUI

struct Step11Notifications: View {
    @ObservedObject var state: OnboardingState
    let onComplete: () -> Void

    @State private var isCompleting = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Stay on Track")
                            .font(.exH2)
                            .foregroundStyle(.exTextPrimary)
                        Text("Get reminders for your goals")
                            .font(.exBody)
                            .foregroundStyle(.exTextSecondary)
                    }

                    notificationToggles

                    Spacer(minLength: 32)

                    ActionButton(
                        title: "Finish Setup",
                        isLoading: isCompleting
                    ) {
                        isCompleting = true
                        withAnimation(.spring(response: 0.4)) {
                            state.showConfetti = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            onComplete()
                        }
                    }
                }
                .padding(24)
                .padding(.top, 16)
            }

            if state.showConfetti {
                flashOverlay
                ConfettiView()
            }
        }
    }

    private var notificationToggles: some View {
        VStack(spacing: 12) {
            notifRow(icon: "figure.run", title: "Workout Reminders",
                     subtitle: "Get reminded before your scheduled workouts",
                     isOn: $state.notifyWorkouts)

            notifRow(icon: "fork.knife", title: "Meal Reminders",
                     subtitle: "Track your nutrition throughout the day",
                     isOn: $state.notifyMeals)

            notifRow(icon: "moon.fill", title: "Bedtime Reminder",
                     subtitle: "Wind down and hit your sleep goal",
                     isOn: $state.notifySleep)
        }
    }

    private func notifRow(
        icon: String, title: String,
        subtitle: String, isOn: Binding<Bool>
    ) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.exPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.exPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                    Text(subtitle)
                        .font(.exCaption)
                        .foregroundStyle(.exTextSecondary)
                }

                Spacer()

                Toggle("", isOn: isOn)
                    .tint(.exPrimary)
                    .labelsHidden()
            }
        }
    }

    private var flashOverlay: some View {
        Color.white
            .ignoresSafeArea()
            .opacity(state.showConfetti ? 0 : 0.8)
            .animation(.easeOut(duration: 0.3), value: state.showConfetti)
            .allowsHitTesting(false)
    }
}
