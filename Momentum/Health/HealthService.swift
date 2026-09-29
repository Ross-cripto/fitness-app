import Foundation
import HealthKit

/// Apple Health integration.
///
/// Writes: finished workouts (with energy burned) and body weight.
/// Reads: today's steps and active energy (which includes Apple Watch data) and the latest body weight.
/// Nothing is sent anywhere except Apple Health on the same device.
@MainActor
final class HealthService: ObservableObject {
    @Published private(set) var steps = 0
    @Published private(set) var activeCalories = 0
    @Published private(set) var lastError: String?

    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private enum HealthError: Error { case failed }

    // MARK: Types

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.bodyMass)]
    }

    private var readTypes: Set<HKObjectType> {
        [HKObjectType.workoutType(), HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned), HKQuantityType(.bodyMass)]
    }

    // MARK: Authorization

    /// Shows the Apple Health permission sheet. Returns `false` if Health isn't available or the request failed.
    /// (Apple deliberately doesn't reveal whether read access was granted.)
    func requestAccess() async -> Bool {
        guard Self.isAvailable else {
            lastError = "Apple Health isn't available on this device."
            return false
        }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: Reading

    func refreshToday() async {
        guard Self.isAvailable else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let stepCount = await sum(.stepCount, unit: .count(), from: start)
        let energy = await sum(.activeEnergyBurned, unit: .kilocalorie(), from: start)
        steps = Int(stepCount.rounded())
        activeCalories = Int(energy.rounded())
    }

    /// Most recent body weight recorded in Health, in kilograms.
    func latestBodyWeightKg() async -> Double? {
        guard Self.isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKQuantityType(.bodyMass),
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date) async -> Double {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(identifier),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    // MARK: Writing

    func saveBodyWeight(kg: Double, date: Date = Date()) async {
        guard Self.isAvailable else { return }
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date,
            end: date
        )
        do {
            try await store.save(sample)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Saves a finished session as a strength-training workout with its energy burned.
    func saveWorkout(_ session: WorkoutSession) async {
        guard Self.isAvailable, session.completedSets > 0 else { return }
        let end = session.date
        let start = end.addingTimeInterval(-Double(max(60, session.durationSeconds)))

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        do {
            try await begin(builder, at: start)
            if session.calories > 0 {
                let energy = HKQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(session.calories)),
                    start: start,
                    end: end
                )
                try await add(builder, samples: [energy])
            }
            try await finish(builder, at: end)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Workout builder (completion handlers wrapped for async/await)

    private func begin(_ builder: HKWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthError.failed)
                }
            }
        }
    }

    private func add(_ builder: HKWorkoutBuilder, samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthError.failed)
                }
            }
        }
    }

    private func finish(_ builder: HKWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard success else {
                    continuation.resume(throwing: HealthError.failed)
                    return
                }
                builder.finishWorkout { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}
