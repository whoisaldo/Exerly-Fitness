import SwiftUI

struct Step10Results: View {
    @ObservedObject var state: OnboardingState
    @State private var showResults = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if let r = state.results {
                    calorieCard(r)
                    macroCard(r)
                    weeklyCalendar(r)
                    sleepCard(r)
                    bodyCard(r)
                }

                Spacer(minLength: 24)

                ActionButton(title: "Continue") { state.nextStep() }
            }
            .padding(24)
            .padding(.top, 16)
            .opacity(showResults ? 1 : 0)
            .offset(y: showResults ? 0 : 20)
        }
        .onAppear {
            if state.results == nil { state.computeResults() }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) { showResults = true }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Your Plan")
                .font(.exH1)
                .foregroundStyle(.exTextPrimary)
            Text("Here's what we've built for you, \(state.name)")
                .font(.exBody)
                .foregroundStyle(.exTextSecondary)
        }
    }

    private func calorieCard(_ r: WizardResults) -> some View {
        GlassCard {
            VStack(spacing: 8) {
                Text("Daily Calorie Target")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                Text("\(r.calorieTarget)")
                    .font(.exStat)
                    .foregroundStyle(.exPrimary)
                Text("kcal / day")
                    .font(.exCaption)
                    .foregroundStyle(.exTextMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func macroCard(_ r: WizardResults) -> some View {
        GlassCard {
            VStack(spacing: 12) {
                Text("Macro Breakdown")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                HStack(spacing: 16) {
                    macroItem("Protein", value: r.proteinGrams, color: .exPrimary)
                    macroItem("Fat", value: r.fatGrams, color: .exAccent)
                    macroItem("Carbs", value: r.carbGrams, color: .exSuccess)
                }
            }
        }
    }

    private func macroItem(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)g")
                .font(.exStatSmall)
                .foregroundStyle(color)
            Text(label)
                .font(.exCaption)
                .foregroundStyle(.exTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func weeklyCalendar(_ r: WizardResults) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Schedule")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                ForEach(r.weeklyPlan) { day in
                    HStack(spacing: 12) {
                        Text(String(day.day.prefix(3)))
                            .font(.exMono)
                            .foregroundStyle(.exTextMuted)
                            .frame(width: 36)
                        if day.isRestDay {
                            Text("Rest Day")
                                .font(.exCaption)
                                .foregroundStyle(.exTextMuted)
                        } else {
                            Text(day.workoutType ?? "Workout")
                                .font(.exCaption)
                                .foregroundStyle(.exTextPrimary)
                            Spacer()
                            Text("\(day.durationMinutes) min")
                                .font(.exCaption)
                                .foregroundStyle(.exTextSecondary)
                        }
                    }
                }
            }
        }
    }

    private func sleepCard(_ r: WizardResults) -> some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep Schedule")
                        .font(.exLabel)
                        .foregroundStyle(.exTextSecondary)
                    Text("\(r.sleepSchedule.bedtime) → \(r.sleepSchedule.wakeTime)")
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                }
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.exAccent)
            }
        }
    }

    private func bodyCard(_ r: WizardResults) -> some View {
        GlassCard {
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", r.bmi))
                        .font(.exStatSmall)
                        .foregroundStyle(.exTextPrimary)
                    Text("BMI")
                        .font(.exCaption)
                        .foregroundStyle(.exTextMuted)
                }
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", r.bodyFatEstimate))
                        .font(.exStatSmall)
                        .foregroundStyle(.exTextPrimary)
                    Text("Est. Body Fat")
                        .font(.exCaption)
                        .foregroundStyle(.exTextMuted)
                }
                VStack(spacing: 2) {
                    Text("\(Int(r.healthyWeightRange.lowerBound))-\(Int(r.healthyWeightRange.upperBound))")
                        .font(.exStatSmall)
                        .foregroundStyle(.exTextPrimary)
                    Text("Healthy kg")
                        .font(.exCaption)
                        .foregroundStyle(.exTextMuted)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
