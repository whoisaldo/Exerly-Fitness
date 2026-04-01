import SwiftUI
import Charts
import SwiftData

struct MeasurementsTab: View {
    @Query(sort: \Measurement.date, order: .reverse) private var measurements: [Measurement]
    @State private var showAddSheet = false

    private var weightMeasurements: [Measurement] {
        measurements.filter { $0.type == "weight" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !weightMeasurements.isEmpty {
                    chartSection
                }
                historySection
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .overlay(alignment: .bottomTrailing) { addButton }
        .sheet(isPresented: $showAddSheet) { AddMeasurementSheet() }
    }

    private var chartSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weight Trend")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)

                Chart(weightMeasurements) { m in
                    LineMark(
                        x: .value("Date", m.date),
                        y: .value("Weight", m.value)
                    )
                    .foregroundStyle(Color.exPrimary)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", m.date),
                        y: .value("Weight", m.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.exPrimary.opacity(0.3), .exPrimary.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel().foregroundStyle(Color.exTextMuted)
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)

            if measurements.isEmpty {
                EmptyStateView(icon: "ruler", title: "No measurements",
                               message: "Track your progress by adding measurements")
            } else {
                ForEach(measurements) { m in
                    GlassCard(padding: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.type.capitalized)
                                    .font(.exBodyMedium)
                                    .foregroundStyle(.exTextPrimary)
                                Text(m.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.exCaption)
                                    .foregroundStyle(.exTextMuted)
                            }
                            Spacer()
                            Text(String(format: "%.1f %@", m.value, m.unit))
                                .font(.exStatSmall)
                                .foregroundStyle(.exPrimary)
                        }
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button { showAddSheet = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(LinearGradient.exPrimaryGradient)
                .clipShape(Circle())
                .primaryGlow()
        }
        .padding(20)
        .padding(.bottom, 80)
    }
}

struct AddMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var type = "weight"
    @State private var value = ""
    @State private var unit = "kg"

    private let types = ["weight", "waist", "chest", "hips", "arms", "thighs"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) { Text($0.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)

                FloatingLabelTextField(label: "Value", text: $value, keyboardType: .decimalPad)

                ActionButton(title: "Save", isDisabled: value.isEmpty) {
                    let m = Measurement(type: type, value: Double(value) ?? 0, unit: unit)
                    modelContext.insert(m)
                    dismiss()
                }

                Spacer()
            }
            .padding(20)
            .background(Color.exBackground)
            .navigationTitle("Add Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.exTextSecondary)
                }
            }
        }
    }
}
