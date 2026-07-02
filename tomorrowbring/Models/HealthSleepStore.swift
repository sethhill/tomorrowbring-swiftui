//
//  HealthSleepStore.swift
//  tomorrowbring
//
//  Created by Seth Hill on 02.07.2026.
//

#if canImport(HealthKit)
import Foundation
import HealthKit

/// Reads last night's sleep duration from Apple Health.
@MainActor
final class HealthSleepStore {
    private let store = HKHealthStore()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Requests read access to sleep analysis. HealthKit intentionally does not
    /// reveal whether the user granted or denied read access.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard Self.isAvailable,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: [sleepType])
            return true
        } catch {
            return false
        }
    }

    /// Returns total hours of sleep for the most recent night (queries the window
    /// from 6pm yesterday to noon today to capture most sleep schedules).
    /// Sums core, deep, REM, and unspecified sleep stages; ignores "in bed" and
    /// awake segments. Returns nil when Health is unavailable or no data was found.
    func lastNightSleepHours() async -> Double? {
        guard Self.isAvailable,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else { return nil }

        let calendar = Calendar.current
        let now = Date.now
        var noonComponents = calendar.dateComponents([.year, .month, .day], from: now)
        noonComponents.hour = 12
        noonComponents.minute = 0
        let noonToday = calendar.date(from: noonComponents) ?? now
        let sixPmYesterday = calendar.date(byAdding: .hour, value: -18, to: noonToday) ?? now

        let predicate = HKQuery.predicateForSamples(
            withStart: sixPmYesterday,
            end: noonToday,
            options: []
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        do {
            let samples = try await descriptor.result(for: store)
            let sleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            let totalSeconds = samples
                .filter { sleepValues.contains($0.value) }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            return totalSeconds > 0 ? totalSeconds / 3600 : nil
        } catch {
            return nil
        }
    }
}
#endif
