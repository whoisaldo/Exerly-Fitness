import SwiftUI

struct OnboardingWizard: View {
    @StateObject private var state = OnboardingState()
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        ZStack {
            Color.exBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progressBar
                stepContent
            }
        }
        .onAppear { state.restoreCheckpoint() }
    }

    private var topBar: some View {
        HStack {
            if state.step > 0 {
                Button { state.prevStep() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.exTextPrimary)
                        .frame(width: 44, height: 44)
                }
            } else {
                Spacer().frame(width: 44)
            }

            Spacer()

            Text("Step \(state.step + 1) of \(state.totalSteps)")
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)

            Spacer()
            Spacer().frame(width: 44)
        }
        .padding(.horizontal, 8)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.exSurface2)
                Capsule()
                    .fill(LinearGradient.exPrimaryGradient)
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(response: 0.4), value: state.step)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 24)
    }

    private var progress: Double {
        Double(state.step + 1) / Double(state.totalSteps)
    }

    @ViewBuilder
    private var stepContent: some View {
        TabView(selection: $state.step) {
            Step0Welcome(state: state).tag(0)
            Step1Name(state: state).tag(1)
            Step2AgeGender(state: state).tag(2)
            Step3HeightWeight(state: state).tag(3)
            Step4Goals(state: state).tag(4)
            Step5ActivityLevel(state: state).tag(5)
            Step6ActivityTypes(state: state).tag(6)
            Step7Diet(state: state).tag(7)
            Step8Sleep(state: state).tag(8)
            Step9Equipment(state: state).tag(9)
            Step10Results(state: state).tag(10)
            Step11Notifications(state: state, onComplete: completeOnboarding).tag(11)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.step)
    }

    private func completeOnboarding() {
        let data = OnboardingRequest(
            age: state.age,
            gender: state.gender.rawValue,
            height: state.heightDisplay,
            weight: state.weightDisplay,
            activityLevel: state.activityLevel.rawValue,
            goal: state.goal.rawValue,
            targetWeight: state.targetWeightKg
        )
        Task {
            await authVM.completeOnboarding(data)
            UserDefaults.standard.removeObject(forKey: "onboarding_step")
        }
    }
}
