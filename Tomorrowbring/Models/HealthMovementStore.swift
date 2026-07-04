//
//  HealthMovementStore.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

#if canImport(HealthKit)
import Foundation
import HealthKit

/// Reads workouts from Apple Health and maps them to `MovementActivity`.
@MainActor
final class HealthMovementStore {
    private let store = HKHealthStore()

    /// Whether HealthKit data is available on this device.
    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Requests read access to workouts. Returns `false` only if the request
    /// couldn't be made (unavailable or errored) — HealthKit intentionally does
    /// not reveal whether the user granted read access.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
            return true
        } catch {
            return false
        }
    }

    /// Fetches workouts started on or after `since`, most recent first.
    func recentWorkouts(since: Date) async -> [MovementActivity] {
        guard Self.isAvailable else { return [] }

        let datePredicate = HKQuery.predicateForSamples(
            withStart: since,
            end: nil,
            options: [.strictStartDate]
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(datePredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 50
        )

        do {
            let workouts = try await descriptor.result(for: store)
            return workouts.map { workout in
                MovementActivity(
                    id: "health-\(workout.uuid.uuidString)",
                    type: MovementType(workout.workoutActivityType),
                    date: workout.startDate,
                    durationMinutes: workout.duration / 60,
                    distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
                    source: .health
                )
            }
        } catch {
            return []
        }
    }
}

extension MovementType {
    /// Maps a HealthKit activity type to our simplified movement type.
    init(_ hkType: HKWorkoutActivityType) {
        switch hkType {
        case .running: self = .running
        case .cycling: self = .cycling
        case .walking: self = .walking
        case .hiking: self = .hiking
        case .yoga: self = .yoga
        case .traditionalStrengthTraining, .functionalStrengthTraining: self = .strength
        case .swimming: self = .swimming
        default: self = .other
        }
    }
}
#endif
