import SwiftUI
import ExerlyCore

/// What a finished workout added up to: time, sets, volume and records.
struct WorkoutFinishSummary: View {
    let result: TrainingStore.FinishedSession
    let library: ExerlyCore.ExerciseLibrary
    let unit: MassUnit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let session = result.session
        let summary = WorkoutSummary(session: session, library: library, at: session.endedAt ?? Date())
        // One record per exercise, so a lighter day doesn't read as three.
        let records = PersonalRecord.headlines(result.records)
        NavigationStack {
            ExScreen {
                VStack(spacing: ExSpacing.item) {
                    Image(systemName: "checkmark").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(LinearGradient(colors: [.exPrimary, .exAccent], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: Circle())
                        .accessibilityHidden(true)
                    ExEyebrow("Workout saved", color: .exPrimaryText)
                    Text(session.name).font(.exH1).foregroundStyle(Color.exTextPrimary).multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(TrainingFormat.date(session)).font(.exLabel).foregroundStyle(Color.exTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ExSpacing.small)
                let columns = Array(repeating: GridItem(.flexible(), spacing: ExSpacing.item), count: typeSize.isAccessibilitySize ? 1 : 2)
                LazyVGrid(columns: columns, spacing: ExSpacing.item) {
                    stat("Time", TrainingFormat.minutes(summary.duration), icon: "clock")
                    stat("Working sets", "\(summary.workingSets)", icon: "checkmark.circle")
                    stat("Volume", TrainingFormat.volume(summary.tonnage, unit: unit), icon: "scalemass")
                    stat("Records", "\(records.count)", icon: "trophy")
                }
                if !records.isEmpty {
                    VStack(alignment: .leading, spacing: ExSpacing.small) {
                        Text("Personal records").font(.exH3).foregroundStyle(Color.exTextPrimary).accessibilityAddTraits(.isHeader)
                        TrainingGroupedRows {
                            ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                                if index > 0 { Divider().overlay(Color.exBorder.opacity(0.4)).padding(.leading, ExSpacing.content) }
                                recordRow(record)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    Text("Exercises").font(.exH3).foregroundStyle(Color.exTextPrimary).accessibilityAddTraits(.isHeader)
                    TrainingGroupedRows {
                        ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, performed in
                            if index > 0 { Divider().overlay(Color.exBorder.opacity(0.4)).padding(.leading, ExSpacing.content) }
                            exerciseRow(performed)
                        }
                    }
                }
            }
            // Scrolled content goes under a solid edge, not through the title.
            .scrollEdgeEffectStyle(.hard, for: .top)
            .navigationTitle("Summary").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Always in reach, however long the summary.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("training.summaryDone")
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.tight) {
            Label(title, systemImage: icon).font(.exCaption.weight(.medium)).foregroundStyle(Color.exTextSecondary)
            Text(value).font(.exStatMedium).foregroundStyle(Color.exTextPrimary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ExSpacing.content)
        .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func recordRow(_ record: PersonalRecord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ExSpacing.item) {
            Image(systemName: "trophy.fill").foregroundStyle(Color.exAccent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(library.exercise(record.exerciseID)?.name ?? TrainingFormat.words(record.exerciseID.rawValue))
                    .font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                Text(describe(record)).font(.exLabel).foregroundStyle(Color.exTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ExSpacing.content).padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func describe(_ record: PersonalRecord) -> String {
        func mass(_ kilograms: Double) -> String {
            "\(Mass.kg(kilograms).value(in: unit).formatted(.number.precision(.fractionLength(0...1)))) \(TrainingFormat.unitSymbol(unit))"
        }
        switch record.kind {
        case .oneRepMax: return "Estimated 1RM \(mass(record.value)), up from \(mass(record.previous))"
        case .heaviestLoad: return "Heaviest \(mass(record.value)), up from \(mass(record.previous))"
        case .setVolume: return "Best set volume \(mass(record.value)), up from \(mass(record.previous))"
        case .repsAtLoad:
            return "\(Int(record.value)) reps\(record.load.map { " at \(TrainingFormat.mass($0, unit: unit))" } ?? ""), up from \(Int(record.previous))"
        case .duration: return "Longest set \(TrainingFormat.number(record.value)) s, up from \(TrainingFormat.number(record.previous)) s"
        case .distance: return "Longest distance \(TrainingFormat.number(record.value)) m, up from \(TrainingFormat.number(record.previous)) m"
        }
    }

    private func exerciseRow(_ performed: PerformedExercise) -> some View {
        let exercise = library.exercise(performed.exerciseID)
        return VStack(alignment: .leading, spacing: 2) {
            Text(exercise?.name ?? TrainingFormat.words(performed.exerciseID.rawValue))
                .font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
            Text(performed.sets.map { set in
                (TrainingFormat.badge(set.kind).map { $0 + " " } ?? "") +
                    (exercise.map { TrainingFormat.compact(set, metric: $0.metric, unit: unit) } ?? TrainingFormat.set(set, unit: unit))
            }.joined(separator: ",  "))
            .font(.system(.subheadline, design: .rounded)).foregroundStyle(Color.exTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ExSpacing.content).padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
