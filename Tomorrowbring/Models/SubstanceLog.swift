//
//  SubstanceLog.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import Foundation
import SwiftData
import SwiftUI

/// A trackable substance and its presentation/measurement details.
enum SubstanceKind: String, CaseIterable, Identifiable {
    case thc = "THC"
    case alcohol = "Alcohol"

    var id: String { rawValue }

    /// The unit a quantity is measured in (always plural form).
    var unit: String {
        switch self {
        case .thc: return "mg"
        case .alcohol: return "drinks"
        }
    }

    /// Returns the correctly pluralized unit for a given amount.
    func unit(for amount: Double) -> String {
        switch self {
        case .thc: return "mg"
        case .alcohol: return amount == 1 ? "drink" : "drinks"
        }
    }

    /// Brand tint used for this substance's charts and accents.
    var tint: Color {
        switch self {
        case .thc: return .brandGold
        case .alcohol: return .brandGold
        }
    }

    var icon: String {
        switch self {
        case .thc: return "leaf.fill"
        case .alcohol: return "wineglass.fill"
        }
    }

    /// A sensible default amount and increment for the logging stepper.
    var defaultAmount: Double {
        switch self {
        case .thc: return 10
        case .alcohol: return 1
        }
    }

    var amountStep: Double {
        switch self {
        case .thc: return 5
        case .alcohol: return 1
        }
    }
}

/// A single logged consumption event, persisted with SwiftData.
@Model
final class SubstanceLog {
    /// Raw value of `SubstanceKind`. Stored as a String to keep `@Query`
    /// predicates straightforward.
    var kindRaw: String
    var amount: Double
    var timestamp: Date

    init(kind: SubstanceKind, amount: Double, timestamp: Date = .now) {
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.timestamp = timestamp
    }

    var kind: SubstanceKind {
        get { SubstanceKind(rawValue: kindRaw) ?? .thc }
        set { kindRaw = newValue.rawValue }
    }
}

/// The total amount consumed on a single calendar day, used by the charts.
struct DayTotal: Identifiable {
    let date: Date
    let amount: Double

    var id: Date { date }
}

#if DEBUG
/// An in-memory model container seeded with random logs, for SwiftUI previews.
@MainActor
enum SubstancePreviewData {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SubstanceLog.self, configurations: configuration)
        let calendar = Calendar.current

        for offset in 0..<90 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            if Bool.random() {
                container.mainContext.insert(
                    SubstanceLog(kind: .thc, amount: Double(Int.random(in: 1...8)) * 5, timestamp: day)
                )
            }
            if Int.random(in: 0...2) == 0 {
                container.mainContext.insert(
                    SubstanceLog(kind: .alcohol, amount: Double(Int.random(in: 1...4)), timestamp: day)
                )
            }
        }
        return container
    }()
}
#endif
