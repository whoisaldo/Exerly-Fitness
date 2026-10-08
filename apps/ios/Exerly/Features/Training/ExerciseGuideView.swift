import ExerlyCore
import SwiftUI

struct ExerciseTechnique: Sendable {
    let purpose: String
    let setup: String
    let movement: [String]
    let cue: String
    let referenceName: String
    let reference: URL
}

/// Original short cues, checked against the linked primary exercise guides.
/// Keys are catalog IDs, so a similarly named custom exercise never gets a guessed guide.
enum ExerciseGuideCatalog {
    static let guides: [ExerciseID: ExerciseTechnique] = [
        "barbell-bench-press": ExerciseTechnique(
            purpose: "A controlled press for your chest, shoulders and arms.",
            setup: "Lie on the bench with your feet planted. Set your upper back firmly against the pad and take an even grip on the bar. Use the rack's safeties or a spotter.",
            movement: ["Bring the bar over your chest with steady wrists.",
                       "Lower it slowly toward your chest, keeping your shoulders supported by the bench.",
                       "Press back up smoothly. Finish the rep before beginning the next descent."],
            cue: "Keep control on the way down. Avoid bouncing the bar or lifting your hips to finish a rep.",
            referenceName: "NASM", reference: URL(string: "https://www.nasm.org/resource-center/exercise-library/barbell-bench-press")!),
        "back-squat": ExerciseTechnique(
            purpose: "Bend and straighten your hips and knees while supporting a bar on your upper back.",
            setup: "Set the rack just below shoulder height and position its safety bars. Place the bar across your upper back, away from your neck. Stand it out of the rack and take a small step back.",
            movement: ["Plant your feet in a comfortable stance and brace your middle.",
                       "Bend your hips and knees together. Lower only as far as you can keep your feet planted and the bar controlled.",
                       "Push the floor away and let your chest and hips rise together."],
            cue: "Let your knees follow the direction of your toes. Practice the path with an easy load first.",
            referenceName: "ACE", reference: URL(string: "https://www.acefitness.org/resources/everyone/exercise-library/11/back-squat/")!),
        "deadlift": ExerciseTechnique(
            purpose: "Lift a bar from the floor by extending your hips and legs.",
            setup: "Stand with the bar close to your shins. Reach down by bending your hips and knees, grip evenly, and brace before the bar leaves the floor.",
            movement: ["Take tension through your arms while keeping the bar close.",
                       "Press through your feet and stand up, moving your chest and hips together.",
                       "Stand tall, then send your hips back and bend your knees to return the bar to the floor."],
            cue: "Keep the bar near your legs. Finish standing upright without leaning back.",
            referenceName: "ACE", reference: URL(string: "https://www.acefitness.org/resources/everyone/exercise-library/6/deadlift/")!),
        "lat-pulldown": ExerciseTechnique(
            purpose: "Pull an overhead handle toward your upper chest using your back and arms.",
            setup: "Adjust the thigh pad so it holds your legs comfortably. Sit tall, grasp the handle evenly, and settle into a small backward lean.",
            movement: ["Begin by drawing your shoulders down.",
                       "Bring your elbows toward your sides as the handle travels toward your upper chest.",
                       "Let your arms reach overhead again with control before the next pull."],
            cue: "Keep your torso steady. Pull in front of your body, not behind your neck.",
            referenceName: "ACE", reference: URL(string: "https://www.acefitness.org/resources/everyone/exercise-library/158/seated-lat-pulldown/")!),
        "push-up": ExerciseTechnique(
            purpose: "Press your body away from the floor while keeping your trunk steady.",
            setup: "Place your hands around shoulder width and extend your legs behind you. Make a long line through your head, hips and heels, with your middle gently braced.",
            movement: ["Bend your elbows and lower your chest toward the floor.",
                       "Keep your chest and hips moving together rather than dropping your waist.",
                       "Push through your hands to return to the starting position."],
            cue: "Use a range you can control. Keep your neck in line with your back rather than reaching with your chin.",
            referenceName: "ACE", reference: URL(string: "https://www.acefitness.org/resources/everyone/exercise-library/41/push-up/")!),
        "bodyweight-squat": ExerciseTechnique(
            purpose: "Practice the squat pattern using your own bodyweight.",
            setup: "Stand with your feet a little wider than hip width. Turn your toes slightly outward if comfortable and keep your whole foot in contact with the floor.",
            movement: ["Move your hips back and down as your knees bend.",
                       "Lower to a comfortable depth while keeping your heels down and your torso controlled.",
                       "Press through your feet to stand up, with your hips and chest rising together."],
            cue: "Keep your knees pointing in the same direction as your toes. Depth can improve as the movement becomes familiar.",
            referenceName: "ACE", reference: URL(string: "https://www.acefitness.org/resources/everyone/exercise-library/135/bodyweight-squat/")!),
        "plank": ExerciseTechnique(
            purpose: "Hold your body steady while your trunk resists sagging or twisting.",
            setup: "Rest your forearms on the floor with your elbows under your shoulders. Extend your legs and place your toes on the floor.",
            movement: ["Lift your body and gently tighten your middle.",
                       "Keep your hips in line with your shoulders and heels while breathing normally.",
                       "Lower with control when the hold ends or you can no longer keep the position."],
            cue: "Aim for a steady shape. Raising your hips high or letting your waist sag changes the exercise.",
            referenceName: "ACE", reference: URL(string: "https://www.acefitness.org/resources/everyone/exercise-library/32/front-plank/")!)
    ]
}

struct ExerciseGuideView: View {
    let exercise: ExerlyCore.Exercise

    var body: some View {
        ExScreen {
            ExCard(accent: true) {
                ExEyebrow(technique == nil ? "Movement details" : "Technique guide", color: .exPrimaryText)
                Text(exercise.name).font(.exH1)
                Text(exercise.targetMuscles.map(\.name).joined(separator: " · "))
                    .font(.exLabel).foregroundStyle(Color.exTextSecondary)
                if let technique { Text(technique.purpose).font(.exBody).foregroundStyle(Color.exTextSecondary) }
            }
            if let technique {
                ExCard {
                    ExSectionHeading("Set up")
                    Text(technique.setup).font(.exBody)
                }.accessibilityIdentifier("training.guide.setup")
                ExCard {
                    ExSectionHeading("The movement")
                    ForEach(Array(technique.movement.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: ExSpacing.item) {
                            Text("\(index + 1)").font(.exLabel).foregroundStyle(Color.exPrimaryText)
                                .frame(minWidth: 28, minHeight: 28).background(Color.exPrimary.opacity(0.1), in: Circle())
                            Text(instruction).font(.exBody).frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("training.guide.step.\(index)")
                        }.accessibilityElement(children: .combine)
                    }
                }.accessibilityIdentifier("training.guide.movement")
                ExCard {
                    Label("Keep in mind", systemImage: "lightbulb").font(.exLabel).foregroundStyle(Color.exPrimaryText)
                    Text(technique.cue).font(.exBody)
                    Link("View \(technique.referenceName)'s full guide", destination: technique.reference)
                        .font(.exLabel).frame(minHeight: 44)
                        .accessibilityIdentifier("training.guide.reference")
                        .accessibilityHint("Opens the original guide in your browser. Requires an internet connection.")
                }
            }
            ExCard {
                ExSectionHeading("Equipment")
                Text((exercise.equipment + exercise.support).map { TrainingFormat.words($0.rawValue) }.joined(separator: " · "))
                    .font(.exBody)
            }
            ExCard {
                DisclosureGroup("Muscles & tracking") {
                    VStack(alignment: .leading, spacing: ExSpacing.item) {
                        Text("Target muscles").font(.exLabel)
                        Text(exercise.targetMuscles.map(\.name).joined(separator: ", ")).font(.exBody)
                        if !exercise.synergistMuscles.isEmpty {
                            Text("Assisting muscles").font(.exLabel)
                            Text(exercise.synergistMuscles.map(\.name).joined(separator: ", ")).font(.exBody)
                        }
                        Text("Tracking").font(.exLabel)
                        Text(TrainingFormat.words(exercise.metric.rawValue)).font(.exBody)
                        Text(TrainingFormat.words(exercise.laterality.rawValue)).font(.exBody)
                        ForEach(exercise.actions, id: \.self) { Text(TrainingFormat.words($0.rawValue)).font(.exCaption) }
                    }.padding(.top, ExSpacing.item)
                }.font(.exLabel)
            }
        }
        .navigationTitle("Exercise guide").navigationBarTitleDisplayMode(.inline)
    }

    private var technique: ExerciseTechnique? { ExerciseGuideCatalog.guides[exercise.id] }
}
