//
//  tomorrowbringApp.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

@main
struct tomorrowbringApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .background(Color.appBackground.ignoresSafeArea())
        }
        .modelContainer(for: [SubstanceLog.self, CheckInEntry.self, WellbeingEntry.self])
    }
}
