import SwiftUI

struct Step8Sleep: View {
    @ObservedObject var state: OnboardingState

    private var bedtimePreview: String {
        let schedule = WizardService.calculateSleepSchedule(
            durationHours: state.sleepHours,
            wakeHour: state.wakeHour,
            wakeMinute: state.wakeMinute
        )
        return schedule.bedtime
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Sleep Schedule")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                    Text("Good sleep is essential for recovery")
                        .font(.exBody)
                        .foregroundStyle(.exTextSecondary)
                }

                durationSlider
                wakeTimePicker
                bedtimeCard

                Spacer(minLength: 24)

                ActionButton(title: "Continue") { state.nextStep() }
            }
            .padding(24)
            .padding(.top, 16)
        }
    }

    private var durationSlider: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Sleep Duration")
                        .font(.exLabel)
                        .foregroundStyle(.exTextSecondary)
                    Spacer()
                    Text(String(format: "%.1f hrs", state.sleepHours))
                        .font(.exStatSmall)
                        .foregroundStyle(.exPrimary)
                }
                Slider(value: $state.sleepHours, in: 4...12, step: 0.5)
                    .tint(.exPrimary)
            }
        }
    }

    private var wakeTimePicker: some View {
        GlassCard {
            VStack(spacing: 12) {
                Text("Wake Time")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                HStack(spacing: 16) {
                    Picker("Hour", selection: $state.wakeHour) {
                        ForEach(4...11, id: \.self) { h in
                            Text(String(format: "%d:00", h)).tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100, height: 100)

                    Picker("Minute", selection: $state.wakeMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { m in
                            Text(String(format: ":%02d", m)).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 100)

                    Text("AM")
                        .font(.exLabel)
                        .foregroundStyle(.exTextSecondary)
                }
            }
        }
    }

    private var bedtimeCard: some View {
        GlassCard {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundStyle(.exAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested Bedtime")
                        .font(.exCaption)
                        .foregroundStyle(.exTextSecondary)
                    Text(bedtimePreview)
                        .font(.exStatSmall)
                        .foregroundStyle(.exTextPrimary)
                }
                Spacer()
            }
        }
    }
}
