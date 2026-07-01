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
    @State private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

    /// Tracks a real backgrounding so we only re-prompt when returning from the
    /// background — not from the biometric overlay (which only makes us inactive).
    @State private var wasInBackground = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lock)
                .background(Color.appBackground.ignoresSafeArea())
        }
        .modelContainer(for: [SubstanceLog.self, CheckInEntry.self, WellbeingEntry.self])
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lock.lock()
                wasInBackground = true
            case .active:
                if wasInBackground {
                    wasInBackground = false
                    lock.authenticate()
                }
            default:
                break
            }
        }
    }
}
