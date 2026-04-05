import SwiftUI

struct LogActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activityType = ""
    @State private var duration: Double = 30
    @State private var intensity = "moderate"
    @State private var isSubmitting = false
    @State private var searchText = ""

    private let intensities = ["light", "moderate", "intense"]

    /// Calories per minute at moderate intensity for each activity.
    private let caloriesPerMinute: [String: Double] = [
        "Running": 10, "Walking": 4, "Cycling": 8, "Swimming": 9,
        "Yoga": 3, "Weightlifting": 6, "HIIT": 12, "Pilates": 4,
        "Boxing": 10, "Rowing": 8, "Basketball": 8, "Soccer": 9,
        "American Football": 8, "Tennis": 7, "Baseball": 5,
        "Volleyball": 6, "Martial Arts": 10, "Dance": 6,
        "Rock Climbing": 9, "Hiking": 6, "Jump Rope": 12,
        "Skateboarding": 5, "Elliptical": 7, "Stair Climbing": 9,
        "Spinning": 10, "CrossFit": 10, "Stretching": 2.5,
        "Badminton": 5, "Table Tennis": 4, "Golf": 3.5,
    ]

    private var estimatedCalories: Int {
        let baseRate = caloriesPerMinute[activityType] ?? 6.5
        let intensityMultiplier: Double = switch intensity {
        case "light": 0.7
        case "intense": 1.4
        default: 1.0
        }
        return Int(duration * baseRate * intensityMultiplier)
    }

    private let suggestions = [
        "Running", "Walking", "Cycling", "Swimming", "Yoga",
        "Weightlifting", "HIIT", "Pilates", "Boxing", "Rowing",
        "Basketball", "Soccer", "American Football", "Tennis",
        "Baseball", "Volleyball", "Martial Arts", "Dance",
        "Rock Climbing", "Hiking", "Jump Rope", "Skateboarding",
        "Elliptical", "Stair Climbing", "Spinning", "CrossFit",
        "Stretching", "Badminton", "Table Tennis", "Golf",
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
