import ExerlyCore
import SwiftUI

struct OnboardingWizard: View {
    @StateObject private var state = OnboardingState(automaticallySync: true)
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.exBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progressBar
                if state.repairSteps != nil {
                    Text("Finish account setup. Your existing logs are kept; only missing details need attention.")
                        .font(.callout).padding(.horizontal, 24).padding(.top, 12)
                }
                if let message = state.cloudMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message).font(.callout)
                        if state.cloudConflict == nil {
                            Button("Retry draft sync") { Task { await state.syncCloud() } }
                                .frame(minHeight: 44)
                        }
                    }.padding(.horizontal, 24).accessibilityIdentifier("setup.cloudStatus")
                }
                if let error = state.validationError ?? authVM.error {
                    Text(error).font(.callout).foregroundStyle(.exError)
                        .padding(.horizontal, 24).padding(.top, 12)
                        .accessibilityIdentifier("setup.error")
                }
                if state.repairUnavailable {
                    Button("Retry account repair") {
                        Task {
                            await authVM.checkAuth()
                            if let accountID = authVM.currentUser?.id {
                                state.restoreCheckpoint(accountID: accountID, name: authVM.currentUser?.name, repair: authVM.setupStatus)
                            }
                        }
                    }.frame(minHeight: 44)
                }
                stepContent
            }
        }
         .task(id: authVM.setupStatus?.needs_repair) {
            if let accountID = authVM.currentUser?.id {
                state.restoreCheckpoint(accountID: accountID, name: authVM.currentUser?.name, repair: authVM.setupStatus)
                await state.syncCloud()
            }
        }
        .sheet(isPresented: Binding(get: { state.cloudConflict != nil }, set: { _ in })) {
            if let remote = state.cloudConflict {
                NavigationStack {
                    ExList {
                        Section("On this device") {
                            draftSummary(state.request())
                        }
                        Section("Saved on another device") {
                            draftSummary(remote.answers)
                        }
                        Section {
                            Button("Use saved server answers") {
                                Task { await state.resolveCloudConflict(useServer: true) }
                            }.frame(minHeight: 44)
                            Button("Keep these device answers") {
                                Task { await state.resolveCloudConflict(useServer: false) }
                            }.frame(minHeight: 44)
                        }
                    }.navigationTitle("Review setup changes")
                }.interactiveDismissDisabled()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }

    private var topBar: some View {
        HStack {
            if state.visibleSteps.first != state.step {
                Button { state.prevStep() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.exTextPrimary)
                        .frame(width: 44, height: 44)
                }.accessibilityLabel("Previous setup step").disabled(state.isSubmitting)
            } else {
                Spacer().frame(width: 44)
            }

            Spacer()

            Text(state.repairSteps == nil ? "\(state.questionNumber) of \(state.questionCount)" : "Repair \((state.visibleSteps.firstIndex(of: state.step) ?? 0) + 1) of \(state.visibleSteps.count)")
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
                    .fill(Color.exPrimary)
                    .frame(width: geo.size.width * progress)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: state.questionNumber)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 24)
    }

    private var progress: Double {
        if state.repairSteps != nil {
            return Double((state.visibleSteps.firstIndex(of: state.step) ?? 0) + 1) / Double(state.visibleSteps.count)
        }
        return Double(state.questionNumber) / Double(state.questionCount)
    }

    private func draftSummary(_ answers: OnboardingRequest) -> some View {
        let unit: MassUnit = answers.unitSystem == "metric" ? .kilograms : .pounds
        let height = USUnits.feetAndInches(centimeters: answers.height, inchStep: 0.1)
        let heightLabel = unit == .pounds
            ? "\(height.feet) ft \(height.inches.formatted(.number.precision(.fractionLength(0...1)))) in"
            : "\(answers.height.formatted(.number.precision(.fractionLength(0...1)))) cm"
        let weight = Mass.kg(answers.weight).value(in: unit).formatted(.number.precision(.fractionLength(0...2)))
        return VStack(alignment: .leading, spacing: 8) {
            Text(answers.name ?? "Name not entered")
            Text("Age \(answers.age) · \(heightLabel) · \(weight) \(unit.rawValue)")
            Text("Goal: \(answers.goal.replacingOccurrences(of: "_", with: " "))")
            Text("Activity: \(answers.activityLevel)")
        }.font(.body).accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch state.step {
            case 0: Step1Name(state: state)
            case 1: Step2AgeGender(state: state)
            case 2: Step4Goals(state: state)
            case 3: Step5ActivityLevel(state: state)
            default: Step10Results(state: state, onComplete: completeOnboarding)
            }
        }
        .disabled(state.isSubmitting || state.repairUnavailable)
    }

    private func completeOnboarding() {
        guard !state.isSubmitting, !state.repairUnavailable else { return }
        if let invalid = (0..<state.totalSteps).first(where: { state.errorForStep($0) != nil }) {
            state.step = invalid
            state.validationError = state.errorForStep(invalid)
            return
        }
        state.isSubmitting = true
        Task {
            guard await state.syncCloud() else {
                state.isSubmitting = false
                await authVM.checkAuth()
                return
            }
            let data = state.prepareSubmission()
            let success = await authVM.completeOnboarding(data, operationID: state.operationID)
            state.isSubmitting = false
            if success { state.clearCheckpoint() }
        }
    }
}
