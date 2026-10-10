import ExerlyCore
import SwiftUI

/// First-run setup in five pages: about you, goal, everyday activity,
/// training, and the targets they produce.
struct OnboardingWizard: View {
    @StateObject private var state = OnboardingState(automaticallySync: true)
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            topBar
            notices
            stepContent
        }
        .background(Color.exBackground.ignoresSafeArea())
        .task(id: authVM.setupStatus?.needs_repair) {
            if let accountID = authVM.currentUser?.id {
                state.restoreCheckpoint(accountID: accountID, name: authVM.currentUser?.name, repair: authVM.setupStatus)
                await state.syncCloud()
            }
        }
        .onChange(of: state.validationError) { _, error in
            if let error { UIAccessibility.post(notification: .announcement, argument: error) }
        }
        .sheet(isPresented: Binding(get: { state.cloudConflict != nil }, set: { _ in })) {
            if let remote = state.cloudConflict { conflict(remote) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }

    // MARK: Chrome

    private var pageIndex: Int {
        state.repairSteps == nil ? state.questionNumber : (state.visibleSteps.firstIndex(of: state.step) ?? 0) + 1
    }
    private var pageCount: Int { state.repairSteps == nil ? state.questionCount : state.visibleSteps.count }

    private var topBar: some View {
        HStack(spacing: ExSpacing.item) {
            if state.isFirstPage {
                Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
            } else {
                Button { state.prevStep() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.exTextPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.exSurface1, in: Circle())
                }
                .buttonStyle(TodayPressStyle())
                .accessibilityLabel("Previous setup step")
                .disabled(state.isSubmitting)
            }
            HStack(spacing: 4) {
                ForEach(1...max(pageCount, 1), id: \.self) { index in
                    Capsule().fill(index <= pageIndex ? Color.exPrimary : Color.exPrimary.opacity(0.16))
                        .frame(height: 4)
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: pageIndex)
            .accessibilityHidden(true)
            Text(state.repairSteps == nil ? "\(pageIndex) of \(pageCount)" : "Repair \(pageIndex) of \(pageCount)")
                .font(.exCaption.weight(.semibold)).monospacedDigit().foregroundStyle(Color.exTextSecondary)
                .fixedSize()
                .accessibilityLabel(state.repairSteps == nil ? "Step \(pageIndex) of \(pageCount)" : "Repair \(pageIndex) of \(pageCount)")
        }
        .padding(.horizontal, ExSpacing.page)
        .padding(.vertical, ExSpacing.tight)
    }

    @ViewBuilder private var notices: some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            if state.repairSteps != nil {
                notice("Finish account setup. Your logs are kept; only the missing details need an answer.", icon: "wrench.and.screwdriver")
            }
            if let message = state.cloudMessage {
                VStack(alignment: .leading, spacing: ExSpacing.tight) {
                    notice(message, icon: "icloud.slash")
                    if state.cloudConflict == nil {
                        Button("Retry draft sync") { Task { await state.syncCloud() } }
                            .font(.exLabel).foregroundStyle(Color.exPrimaryText).frame(minHeight: 44)
                    }
                }.accessibilityIdentifier("setup.cloudStatus")
            }
            if state.repairUnavailable {
                Button("Retry account repair") {
                    Task {
                        await authVM.checkAuth()
                        if let accountID = authVM.currentUser?.id {
                            state.restoreCheckpoint(accountID: accountID, name: authVM.currentUser?.name, repair: authVM.setupStatus)
                        }
                    }
                }
                .buttonStyle(ExActionStyle(secondary: true))
            }
        }
        .padding(.horizontal, ExSpacing.page)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func notice(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(ExSpacing.item)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.control, style: .continuous))
    }

    // MARK: Pages

    private var pageKey: String { "\(state.step <= 1 ? 0 : state.step)-\(state.step == 3 ? state.planningPage : 0)" }

    private var stepContent: some View {
        ZStack {
            Group {
                switch state.step {
                case 0, 1: SetupAboutYouStep(state: state)
                case 2: SetupGoalStep(state: state)
                case 3: SetupWeekStep(state: state)
                default: SetupReviewStep(state: state, onComplete: completeOnboarding)
                }
            }
            .id(pageKey)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: state.direction).combined(with: .opacity),
                                                             removal: .opacity))
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: pageKey)
        .environment(\.setupError, state.validationError ?? authVM.error)
        .disabled(state.isSubmitting || state.repairUnavailable)
        .frame(maxHeight: .infinity)
    }

    private func conflict(_ remote: SetupCloudDraft) -> some View {
        NavigationStack {
            ExList {
                Section("On this device") { draftSummary(state.request()) }
                Section("Saved on another device") { draftSummary(remote.answers) }
                Section {
                    Button("Use saved server answers") {
                        Task { await state.resolveCloudConflict(useServer: true) }
                    }.frame(minHeight: 44)
                    Button("Keep these device answers") {
                        Task { await state.resolveCloudConflict(useServer: false) }
                    }.frame(minHeight: 44)
                }
            }
            .navigationTitle("Review setup changes").navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
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
        }.font(.exBody).accessibilityElement(children: .combine)
    }

    private func completeOnboarding() {
        guard !state.isSubmitting, !state.repairUnavailable else { return }
        if let invalid = (0..<state.totalSteps).first(where: { state.errorForStep($0) != nil }) {
            state.validationError = state.errorForStep(invalid)
            if invalid != state.step { state.direction = .leading; state.step = invalid }
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
            let repairing = state.repairSteps != nil
            let accountID = authVM.currentUser?.id
            let success = await authVM.completeOnboarding(data, operationID: state.operationID)
            state.isSubmitting = false
            if success {
                // A repair keeps the account's history and adds no weigh-in.
                if !repairing, let accountID {
                    SetupWeighIn.remember(accountID: accountID, kilograms: data.weight, timeZone: data.timezone)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                state.clearCheckpoint()
            }
        }
    }
}
