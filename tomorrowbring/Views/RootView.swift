//
//  RootView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import SwiftUI
import SwiftData

/// The app's entry gate: shows the lock screen until `AppLock` is unlocked, then
/// routes to the check-in or briefing depending on whether the person has
/// already checked in today.
struct RootView: View {
    @Environment(AppLock.self) private var lock
    @Query(sort: \CheckInEntry.timestamp, order: .reverse) private var checkIns: [CheckInEntry]

    /// Whether the most recent check-in was recorded today.
    private var checkedInToday: Bool {
        guard let latest = checkIns.first else { return false }
        return Calendar.current.isDateInToday(latest.timestamp)
    }

    var body: some View {
        Group {
            if lock.isUnlocked {
                ContentView(initialSection: checkedInToday ? .briefing : .checkIn)
            } else {
                LockScreen(error: lock.authError, onUnlock: { lock.authenticate() })
            }
        }
        .task {
            // Prompt at first launch (scene-phase changes handle later returns).
            if !lock.isUnlocked { lock.authenticate() }
        }
    }
}

/// Shown while the app is locked, with a button to (re)try authentication.
private struct LockScreen: View {
    let error: String?
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.brandGreen)

            Text("tomorrowbring")
                .font(.title)
                .bold()

            if let error {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Unlock", action: onUnlock)
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
                .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }
}
