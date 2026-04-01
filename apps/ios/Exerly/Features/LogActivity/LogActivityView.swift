import SwiftUI

struct LogActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activityType = ""
    @State private var duration: Double = 30
    @State private var intensity = "moderate"
    @State private var isSubmitting = false
    @State private var searchText = ""

    private let intensities = ["light", "moderate", "intense"]

    private var estimatedCalories: Int {
        let multiplier: Double = switch intensity {
        case "light": 4.0
        case "intense": 9.0
        default: 6.5
        }
        return Int(duration * multiplier)
    }

    private let suggestions = [
        "Running", "Walking", "Cycling", "Swimming", "Yoga",
        "Weightlifting", "HIIT", "Pilates", "Boxing", "Rowing"
    ]

    private var filteredSuggestions: [String] {
        if searchText.isEmpty { return suggestions }
        return suggestions.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    searchSection
                    durationSection
                    intensitySection
                    caloriePreview
                    submitButton
                }
                .padding(20)
            }
            .background(Color.exBackground)
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.exTextSecondary)
                }
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FloatingLabelTextField(label: "Search activity", text: $searchText)

            if activityType.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(filteredSuggestions, id: \.self) { name in
                        Button {
                            activityType = name
                            searchText = name
                        } label: {
                            Text(name)
                                .font(.exCaption)
                                .foregroundStyle(.exTextSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassCard(cornerRadius: 20)
                        }
                    }
                }
            }
        }
    }

    private var durationSection: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack {
                    Text("Duration")
                        .font(.exLabel)
                        .foregroundStyle(.exTextSecondary)
                    Spacer()
                    Text("\(Int(duration)) min")
                        .font(.exStatSmall)
                        .foregroundStyle(.exPrimary)
                }
                Slider(value: $duration, in: 5...180, step: 5)
                    .tint(.exPrimary)
            }
        }
    }

    private var intensitySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Intensity")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                HStack(spacing: 10) {
                    ForEach(intensities, id: \.self) { level in
                        Button {
                            withAnimation(.spring(response: 0.3)) { intensity = level }
                        } label: {
                            Text(level.capitalized)
                                .font(.exCaption)
                                .foregroundStyle(intensity == level ? .white : .exTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(intensity == level ? Color.exPrimary : Color.exSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    private var caloriePreview: some View {
        GlassCard {
            HStack {
                Text("Estimated Calories")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                Spacer()
                Text("\(estimatedCalories) kcal")
                    .font(.exStatSmall)
                    .foregroundStyle(.exAccent)
            }
        }
    }

    private var submitButton: some View {
        ActionButton(
            title: "Log Activity",
            isLoading: isSubmitting,
            isDisabled: activityType.isEmpty
        ) {
            Task { await submit() }
        }
    }

    private func submit() async {
        isSubmitting = true
        let req = ActivityRequest(
            type: activityType,
            duration: Int(duration),
            calories: estimatedCalories,
            intensity: intensity
        )
        do {
            let _: ActivityDTO = try await APIClient.shared.createActivity(req)
            dismiss()
        } catch {
            isSubmitting = false
        }
    }
}
