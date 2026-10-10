import Foundation
import HealthKit
import Observation

/// Records the workout in progress as a Health workout session, for live heart
/// rate and, once saved, activity credit. The saved workout carries the
/// phone's record ID and sync identifier (`HealthMetadata` in ExerlyCore), and
/// the phone skips writing a workout the watch records, so Health gets one.
@MainActor
@Observable
final class WorkoutRecorder: NSObject {
    static let shared = WorkoutRecorder()

    /// The Exerly workout being recorded.
    private(set) var workoutID: UUID?
    /// The latest heart rate, in beats per minute.
    private(set) var heartRate: Double?
    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    /// The change running now; the next waits for it.
    @ObservationIgnored private var running: Task<Void, Never>?
    private static let recordKey = "ExerlyRecordID"

    /// Brings recording in line with the workout in progress: ends the one
    /// that's over, saved when `saving` says so, then starts `workout`.
    /// `onRecording` runs once Health is collecting.
    func follow(_ workout: (id: UUID, startedAt: Date)?, saving: @escaping (UUID) -> Bool,
                onRecording: @escaping (UUID) -> Void) {
        let previous = running
        running = Task {
            await previous?.value
            if let id = workoutID, id != workout?.id { await end(saving: saving(id)) }
            if let workout, workoutID == nil, await record(workout.id, startedAt: workout.startedAt) { onRecording(workout.id) }
        }
    }

    private func record(_ id: UUID, startedAt: Date) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)],
                                                 read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)])
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            attach(session, builder, id: id)
            // From when it started on the phone, so Health's duration matches Exerly's.
            let start = min(startedAt, .now)
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            try await builder.addMetadata([
                Self.recordKey: id.uuidString,
                HKMetadataKeySyncIdentifier: "exerly.workout.\(id.uuidString.lowercased())",
                HKMetadataKeySyncVersion: NSNumber(value: Int64(Date().timeIntervalSince1970 * 1000)),
                HKMetadataKeyTimeZone: TimeZone.current.identifier,
            ])
            return true
        } catch {
            // Without Health the workout still runs, and the phone writes it.
            await end(saving: false)
            return false
        }
    }

    private func end(saving: Bool) async {
        guard let session, let builder else { return detach() }
        detach()
        session.end()
        do {
            try await builder.endCollection(at: .now)
            if saving { _ = try await builder.finishWorkout() } else { builder.discardWorkout() }
        } catch {
            builder.discardWorkout()
        }
    }

    /// Picks up a recording the system kept running after the app quit.
    func recover() async {
        guard let session = try? await store.recoverActiveWorkoutSession() else { return }
        let builder = session.associatedWorkoutBuilder()
        attach(session, builder, id: (builder.metadata[Self.recordKey] as? String).flatMap(UUID.init))
    }

    private func attach(_ session: HKWorkoutSession, _ builder: HKLiveWorkoutBuilder, id: UUID?) {
        self.session = session
        self.builder = builder
        workoutID = id
        builder.delegate = self
    }

    private func detach() {
        session = nil
        builder = nil
        workoutID = nil
        heartRate = nil
    }
}

extension WorkoutRecorder: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ builder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        let type = HKQuantityType(.heartRate)
        guard types.contains(type),
              let bpm = builder.statistics(for: type)?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
        else { return }
        Task { @MainActor in
            if self.builder === builder { self.heartRate = bpm }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ builder: HKLiveWorkoutBuilder) {}
}
