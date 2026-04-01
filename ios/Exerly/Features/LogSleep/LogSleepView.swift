import SwiftUI

struct LogSleepView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hours: Double = 7.5
    @State private var quality = 3
    @State private var bedtime = Calendar.current.date(
        bySettingHour: 23, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var wakeTime = Calendar.current.date(
        bySettingHour: 7, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var isSubmitting = false

    private let tips = [
        "Avoid screens 30 min before bed",
        "Keep your bedroom cool (65-68°F)",
        "Stick to a consistent sleep schedule",
        "Limit caffeine after 2 PM",
        "Try a relaxation technique before bed",
    ]

    @State private var tipIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    durationSection
                    qualitySection
                    timeSection
                    tipCard
                    submitButton
                }
                .padding(20)
            }
            .background(Color.exBackground)
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.exTextSecondary)
                }
            }
            .onAppear { tipIndex = Int.random(in: 0..<tips.count) }
        }
    }

    private var durationSection: some View {
        GlassCard {
            VStack(spacing: 16) {
                Text("Duration")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)

                arcSlider

                Text(String(format: "%.1f hours", hours))
                    .font(.exStatMedium)
                    .foregroundStyle(.exPrimary)
            }
        }
    }

    private var arcSlider: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.exSurface2, lineWidth: 10)
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: hours / 16 * 0.75)
                .stroke(
                    LinearGradient(colors: [.exPrimary, .exAccent],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .animation(.spring(response: 0.3), value: hours)

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 32))
                .foregroundStyle(.exPrimary)
        }
        .frame(width: 160, height: 160)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let center = CGPoint(x: 80, y: 80)
                    let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                    let normalized = (angle + .pi) / (2 * .pi)
                    hours = max(1, min(14, normalized * 16))
                }
        )
    }

    private var qualitySection: some View {
        GlassCard {
            VStack(spacing: 10) {
                Text("Sleep Quality")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.spring(response: 0.3)) { quality = star }
                        } label: {
                            Image(systemName: star <= quality ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundStyle(star <= quality ? .exWarning : .exTextMuted)
                        }
                    }
                }
            }
        }
    }

    private var timeSection: some View {
        HStack(spacing: 12) {
            GlassCard {
                VStack(spacing: 6) {
                    Text("Bedtime")
                        .font(.exCaption)
                        .foregroundStyle(.exTextSecondary)
                    DatePicker("", selection: $bedtime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
            }
            GlassCard {
                VStack(spacing: 6) {
                    Text("Wake Time")
                        .font(.exCaption)
                        .foregroundStyle(.exTextSecondary)
                    DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
            }
        }
    }

    private var tipCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.exWarning)
                Text(tips[tipIndex])
                    .font(.exCaption)
                    .foregroundStyle(.exTextSecondary)
            }
        }
    }

    private var submitButton: some View {
        ActionButton(
            title: "Log Sleep",
            isLoading: isSubmitting
        ) {
            Task { await submit() }
        }
    }

    private func submit() async {
        isSubmitting = true
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let req = SleepRequest(
            hours: hours, quality: quality,
            bedtime: formatter.string(from: bedtime),
            wakeTime: formatter.string(from: wakeTime)
        )
        do {
            let _: SleepDTO = try await APIClient.shared.createSleepLog(req)
            dismiss()
        } catch {
            isSubmitting = false
        }
    }
}
