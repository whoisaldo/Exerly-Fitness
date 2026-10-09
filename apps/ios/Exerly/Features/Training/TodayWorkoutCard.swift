import SwiftUI
import ExerlyCore

/// The Train tab's hero: what to do today, with Start one tap away.
struct TodayWorkoutCard: View {
    let plan: WorkoutPlan
    let position: ProgramSchedule.Position
    let program: Program
    let library: ExerlyCore.ExerciseLibrary
    let restPolicy: RestPolicy
    let unit: MassUnit
    let start: () -> Void
    let preview: () -> Void
    let empty: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private let shown = 5

    var body: some View {
        TrainingHeroSurface {
            HStack(alignment: .firstTextBaseline) {
                ExEyebrow(position.isDeload ? "Today · Deload" : "Today's workout", color: .exPrimaryText)
                Spacer(minLength: ExSpacing.small)
                Text("Cycle \(position.cycle + 1) of \(program.cycles)")
                    .font(.exCaption.weight(.medium)).foregroundStyle(Color.exTextSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.exPrimary.opacity(0.12), in: Capsule())
            }
            VStack(alignment: .leading, spacing: ExSpacing.tight) {
                Text(position.day.name).font(.exH1).foregroundStyle(Color.exTextPrimary)
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("training.todayName")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) { Text(program.name); Text(" · " + details) }
                    VStack(alignment: .leading, spacing: 2) { Text(program.name); Text(details) }
                }
                .font(.exLabel).foregroundStyle(Color.exTextSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(plan.exercises.prefix(shown).enumerated()), id: \.offset) { index, planned in
                    if index > 0 { Divider().overlay(Color.exBorder.opacity(0.35)) }
                    exerciseRow(planned)
                }
                if plan.exercises.count > shown {
                    Divider().overlay(Color.exBorder.opacity(0.35))
                    Text("+\(plan.exercises.count - shown) more").font(.exLabel).foregroundStyle(Color.exTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                }
            }
            Button(action: start) {
                Label("Start workout", systemImage: "play.fill").font(.exBodyMedium.weight(.semibold))
            }
            .buttonStyle(ExActionStyle())
            .accessibilityIdentifier("training.startToday")
            .accessibilityHint("Starts \(position.day.name) with your planned weights")
            secondaryActions
        }
    }

    private var details: String {
        let minutes = TrainingFormat.minutes(plan.estimatedDuration(library: library, policy: restPolicy))
        let count = plan.exercises.count == 1 ? "1 exercise" : "\(plan.exercises.count) exercises"
        return "\(count) · about \(minutes)"
    }

    private func exerciseRow(_ planned: ExerlyCore.PlannedExercise) -> some View {
        let exercise = library.exercise(planned.exerciseID)
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: ExSpacing.small))
        let load = planned.recommendation.sets.first?.effort.load
        return layout {
            Text(exercise?.name ?? TrainingFormat.words(planned.exerciseID.rawValue))
                .font(.exBody).foregroundStyle(Color.exTextPrimary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            if !typeSize.isAccessibilitySize { Spacer(minLength: ExSpacing.small) }
            HStack(spacing: ExSpacing.small) {
                Text(setsAndReps(planned, exercise: exercise)).foregroundStyle(Color.exTextSecondary)
                if let load {
                    Text(TrainingFormat.mass(load, unit: unit)).foregroundStyle(Color.exPrimaryText)
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .fixedSize()
        }
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func setsAndReps(_ planned: ExerlyCore.PlannedExercise, exercise: ExerlyCore.Exercise?) -> String {
        let target = planned.target
        guard exercise?.metric.tracksReps == true else { return target.sets == 1 ? "1 set" : "\(target.sets) sets" }
        return target.minReps == target.maxReps ? "\(target.sets) × \(target.minReps)" : "\(target.sets) × \(target.minReps)–\(target.maxReps)"
    }

    private var secondaryActions: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: ExSpacing.content))
        return layout {
            Button(action: preview) { Label("Preview", systemImage: "list.bullet.rectangle") }
                .accessibilityIdentifier("program.nextWorkout")
                .accessibilityHint("Shows the targets and how they were chosen")
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Button(action: empty) { Label("Empty workout", systemImage: "plus") }
                .accessibilityIdentifier("training.start")
        }
        .buttonStyle(TrainingTextButtonStyle())
    }
}

/// The hero when there's no plan to follow, or the plan is finished.
struct TrainingPromptCard<Primary: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    @ViewBuilder let primary: Primary
    let empty: () -> Void

    var body: some View {
        TrainingHeroSurface {
            ExEyebrow(eyebrow, color: .exPrimaryText)
            Text(title).font(.exH1).foregroundStyle(Color.exTextPrimary).accessibilityAddTraits(.isHeader)
            Text(message).font(.exBody).foregroundStyle(Color.exTextSecondary)
            primary
            Button(action: empty) { Label("Start an empty workout", systemImage: "plus") }
                .buttonStyle(TrainingTextButtonStyle())
                .accessibilityIdentifier("training.start")
        }
    }
}

/// A content surface with a purple-to-pink wash. Content, so no glass.
struct TrainingHeroSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ExSpacing.content) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                ZStack {
                    Color.exSurface1
                    LinearGradient(colors: [Color.exPrimary.opacity(0.26), Color.exAccent.opacity(0.08), Color.exPrimary.opacity(0.02)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.exPrimary.opacity(0.3), lineWidth: 0.75)
            }
    }
}

struct TrainingTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.exLabel.weight(.semibold))
            .foregroundStyle(Color.exPrimaryText)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
