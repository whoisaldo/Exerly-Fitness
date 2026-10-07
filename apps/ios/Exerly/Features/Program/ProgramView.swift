import SwiftUI

private struct ProgramChoice: Identifiable {
    let id: String
    let label: String
}

@MainActor
final class ProgramViewModel: ObservableObject {
    @Published private(set) var program: ProgramDTO?
    @Published private(set) var checkins: [CheckinDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published private(set) var isCheckingIn = false
    @Published var error: String?
    @Published var notice: String?

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        error = nil
        do {
            async let programTask = api.getProgram()
            async let historyTask = api.getCheckins(limit: 12)
            let (loadedProgram, loadedHistory) = try await (programTask, historyTask)
            program = loadedProgram
            checkins = loadedHistory
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func setGoal(_ goal: String) async {
        guard let program else { return }
        var update = ProgramUpdateRequest()
        update.goalType = goal
        update.rateKgPerWeek = goal == "maintain" ? 0 : abs(program.rateKgPerWeek)
        await save(update)
    }

    func setDiet(_ diet: String) async {
        var update = ProgramUpdateRequest()
        update.dietType = diet
        await save(update)
    }

    func setRate(_ rateKgPerWeek: Double) async {
        var update = ProgramUpdateRequest()
        update.rateKgPerWeek = rateKgPerWeek
        await save(update)
    }

    func checkIn() async {
        isCheckingIn = true
        error = nil
        notice = nil
        do {
            let response = try await api.runCheckin()
            program = response.program
            checkins = (try? await api.getCheckins(limit: 12)) ?? checkins
            notice = response.message
        } catch {
            self.error = error.localizedDescription
        }
        isCheckingIn = false
    }

    private func save(_ update: ProgramUpdateRequest) async {
        isUpdating = true
        error = nil
        notice = nil
        do {
            let updated = try await api.updateProgram(update)
            program = (try? await api.getProgram()) ?? updated
        } catch {
            self.error = error.localizedDescription
        }
        isUpdating = false
    }
}

struct ProgramView: View {
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @StateObject private var viewModel = ProgramViewModel()
    @State private var rateDraft = 0.25

    private let goals = [
        ProgramChoice(id: "lose", label: "Lose fat"),
        ProgramChoice(id: "maintain", label: "Maintain"),
        ProgramChoice(id: "gain", label: "Gain muscle"),
    ]

    private let diets = [
        ProgramChoice(id: "balanced", label: "Balanced"),
        ProgramChoice(id: "low_carb", label: "Lower carb"),
        ProgramChoice(id: "low_fat", label: "Lower fat"),
        ProgramChoice(id: "high_protein", label: "High protein"),
        ProgramChoice(id: "keto", label: "Keto"),
    ]

    var body: some View {
        ScrollView {
            Group {
                if viewModel.isLoading && viewModel.program == nil {
                    LoadingStateView(message: "Loading your program…")
                        .frame(minHeight: 420)
                } else if let program = viewModel.program {
                    programContent(program)
                } else if let error = viewModel.error {
                    ErrorStateView(message: error) {
                        Task { await viewModel.load() }
                    }
                    .frame(minHeight: 420)
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Color.exBackground)
        .navigationTitle("Program")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .onChange(of: viewModel.program?.rateKgPerWeek) { _, value in
            if let value { rateDraft = abs(value) }
        }
    }

    private func programContent(_ program: ProgramDTO) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your targets follow what you actually eat and how your trend weight moves.")
                    .font(.exBody)
                    .foregroundStyle(.exTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            expenditureCard(program)
            targetsCard(program)
            planCard(program)

            if !viewModel.checkins.isEmpty {
                historyCard
            }
        }
    }

    private func expenditureCard(_ program: ProgramDTO) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MEASURED EXPENDITURE")
                            .font(.exSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(.exTextMuted)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(program.expenditure.value.map(String.init) ?? "—")
                                .font(.exStat)
                                .foregroundStyle(.exTextPrimary)
                            Text("kcal/day")
                                .font(.exCaption)
                                .foregroundStyle(.exTextMuted)
                        }
                    }
                    Spacer()
                    confidenceBadge(program.expenditure.confidence)
                }

                Text(confidenceExplanation(program.expenditure))
                    .font(.exCaption)
                    .foregroundStyle(.exTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if program.expenditure.measured != nil {
                    Divider().overlay(Color.exBorder)
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        alignment: .leading,
                        spacing: 14
                    ) {
                        detail(
                            "Raw measurement",
                            value: calorieValue(program.expenditure.measured)
                        )
                        detail("Formula says", value: calorieValue(program.expenditure.formula))
                        detail("Mean intake", value: calorieValue(program.expenditure.meanIntake))
                        detail(
                            "Days logged",
                            value: daysValue(
                                logged: program.expenditure.daysLogged,
                                window: program.expenditure.windowDays
                            )
                        )
                    }
                }

                ActionButton(
                    title: program.needsCheckin == true ? "Run check-in" : "Check in again",
                    variant: program.needsCheckin == true ? .primary : .secondary,
                    isLoading: viewModel.isCheckingIn
                ) {
                    Task { await viewModel.checkIn() }
                }

                if let notice = viewModel.notice {
                    Text(notice)
                        .font(.exCaption)
                        .foregroundStyle(.exSuccess)
                }
            }
        }
    }

    private func targetsCard(_ program: ProgramDTO) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Current targets")
                    .font(.exH3)
                    .foregroundStyle(.exTextPrimary)

                if program.targets.calories == nil {
                    Text("Run a check-in to set your targets.")
                        .font(.exBody)
                        .foregroundStyle(.exTextMuted)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        target("Calories", value: program.targets.calories, unit: "kcal", color: .exTextPrimary)
                        target("Protein", value: program.targets.proteinG, unit: "g", color: .exPrimary)
                        target("Carbs", value: program.targets.carbsG, unit: "g", color: .exSuccess)
                        target("Fat", value: program.targets.fatG, unit: "g", color: .exWarning)
                    }
                }

                if let suggested = program.suggestedTargets,
                   let nextCalories = suggested.calories,
                   nextCalories != program.targets.calories {
                    let current = program.targets.calories ?? nextCalories
                    let delta = nextCalories - current
                    Text(
                        "Your next check-in would set \(nextCalories) kcal "
                            + "(\(delta > 0 ? "+" : "")\(delta))."
                    )
                    .font(.exCaption)
                    .foregroundStyle(.exTextSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.exPrimary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.exPrimary.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func planCard(_ program: ProgramDTO) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Plan")
                        .font(.exH3)
                        .foregroundStyle(.exTextPrimary)
                    Spacer()
                    if viewModel.isUpdating {
                        ProgressView().tint(.exPrimary)
                    }
                }

                choiceSection(title: "Goal", choices: goals, selected: program.goalType) { goal in
                    Task { await viewModel.setGoal(goal) }
                }

                if program.goalType != "maintain" {
                    rateSection(program)
                }

                choiceSection(title: "Macro split", choices: diets, selected: program.dietType) { diet in
                    Task { await viewModel.setDiet(diet) }
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(.exCaption)
                        .foregroundStyle(.exError)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func choiceSection(
        title: String,
        choices: [ProgramChoice],
        selected: String,
        action: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.exSmall)
                .fontWeight(.semibold)
                .foregroundStyle(.exTextMuted)
            FlowLayout(spacing: 8) {
                ForEach(choices) { choice in
                    Button { action(choice.id) } label: {
                        Text(choice.label)
                            .font(.exCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(selected == choice.id ? .white : .exTextSecondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(selected == choice.id ? Color.exPrimary : Color.exSurface2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(selected == choice.id ? .clear : Color.exBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .disabled(viewModel.isUpdating)
                }
            }
        }
    }

    private func rateSection(_ program: ProgramDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("TARGET RATE")
                    .font(.exSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.exTextMuted)
                Spacer()
                Text(rateLabel(rateDraft, goal: program.goalType))
                    .font(.exMono)
                    .foregroundStyle(.exTextPrimary)
            }
            Slider(
                value: $rateDraft,
                in: 0...1.5,
                step: 0.05,
                onEditingChanged: { editing in
                    guard !editing else { return }
                    Task { await viewModel.setRate(rateDraft) }
                }
            )
            .tint(.exPrimary)
            .disabled(viewModel.isUpdating)

            Text(rateExplanation(rateDraft))
                .font(.exCaption)
                .foregroundStyle(.exTextMuted)
        }
    }

    private var historyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Check-in history")
                    .font(.exH3)
                    .foregroundStyle(.exTextPrimary)
                    .padding(.bottom, 8)

                ForEach(viewModel.checkins) { checkin in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formattedDay(checkin.entryDate))
                                .font(.exBodyMedium)
                                .foregroundStyle(.exTextPrimary)
                            Text(historyDetail(checkin))
                                .font(.exSmall)
                                .foregroundStyle(.exTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(checkin.calories) kcal")
                                .font(.exMono)
                                .foregroundStyle(.exTextPrimary)
                            if let previous = checkin.previousCalories,
                               checkin.calories != previous {
                                let delta = checkin.calories - previous
                                Text("\(delta > 0 ? "+" : "")\(delta)")
                                    .font(.exSmall.monospacedDigit())
                                    .foregroundStyle(delta > 0 ? .exSuccess : .exWarning)
                            }
                        }
                    }
                    .padding(.vertical, 10)

                    if checkin.id != viewModel.checkins.last?.id {
                        Divider().overlay(Color.exBorder)
                    }
                }
            }
        }
    }

    private func confidenceBadge(_ confidence: String) -> some View {
        Text(confidence.capitalized)
            .font(.exSmall)
            .fontWeight(.semibold)
            .foregroundStyle(confidenceColor(confidence))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(confidenceColor(confidence).opacity(0.1))
            .clipShape(Capsule())
    }

    private func detail(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
            Text(value)
                .font(.exMono)
                .foregroundStyle(.exTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func target(_ label: String, value: Int?, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.exSmall)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value.map(String.init) ?? "—")
                    .font(.exStatMedium)
                    .foregroundStyle(.exTextPrimary)
                Text(unit)
                    .font(.exSmall)
                    .foregroundStyle(.exTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func confidenceExplanation(_ expenditure: ExpenditureDTO) -> String {
        let copy: String = switch expenditure.confidence {
        case "low": "Measured from 14–20 days of data. Expect it to move as you log more."
        case "medium": "Measured from 21–27 days of logging and reasonably stable."
        case "high": "Measured from at least four weeks with consistent food logging."
        default: "Estimated from your profile. Log food and weight for two weeks to measure it."
        }
        guard let reason = expenditure.reason, !reason.isEmpty else { return copy }
        return "\(copy) \(reason)."
    }

    private func confidenceColor(_ confidence: String) -> Color {
        switch confidence {
        case "high": .exSuccess
        case "medium": .exInfo
        case "low": .exWarning
        default: .exTextMuted
        }
    }

    private func calorieValue(_ value: Int?) -> String {
        value.map { "\($0) kcal" } ?? "—"
    }

    private func daysValue(logged: Int?, window: Int?) -> String {
        guard let logged, let window else { return "—" }
        return "\(logged) of \(window)"
    }

    private func rateLabel(_ kilograms: Double, goal: String) -> String {
        let displayed = unitSystem == "imperial" ? kilograms * 2.20462262 : kilograms
        let unit = unitSystem == "imperial" ? "lb" : "kg"
        let direction = goal == "lose" ? "down" : "up"
        return "\(displayed.formatted(.number.precision(.fractionLength(2)))) \(unit)/week \(direction)"
    }

    private func rateExplanation(_ rate: Double) -> String {
        switch rate {
        case 0: "No planned weight change."
        case ...0.35: "Slow and sustainable, with the easiest recovery."
        case ...0.7: "A moderate pace that suits most people."
        default: "Aggressive. Expect more hunger or a larger recovery cost."
        }
    }

    private func formattedDay(_ day: String) -> String {
        CalendarDay(rawValue: day)?.formatted() ?? day
    }

    private func historyDetail(_ checkin: CheckinDTO) -> String {
        var parts = ["expenditure \(checkin.expenditure) · \(checkin.expenditureConfidence)"]
        if let weight = checkin.trendWeightKg {
            let displayed = unitSystem == "imperial" ? weight * 2.20462262 : weight
            let unit = unitSystem == "imperial" ? "lb" : "kg"
            parts.append("trend \(displayed.formatted(.number.precision(.fractionLength(1)))) \(unit)")
        }
        return parts.joined(separator: " · ")
    }
}
