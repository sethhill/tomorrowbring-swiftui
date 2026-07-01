//
//  RootView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import SwiftUI
import SwiftData
import LocalAuthentication

/// The app's entry gate: requires biometric (or device passcode) authentication,
/// then routes to the check-in or briefing depending on whether the person has
/// already checked in today.
struct RootView: View {
    @Query(sort: \CheckInEntry.timestamp, order: .reverse) private var checkIns: [CheckInEntry]

    @State private var isUnlocked = false
    @State private var authError: String?

    /// Whether the most recent check-in was recorded today.
    private var checkedInToday: Bool {
        guard let latest = checkIns.first else { return false }
        return Calendar.current.isDateInToday(latest.timestamp)
    }

    var body: some View {
        Group {
            if isUnlocked {
                ContentView(initialSection: checkedInToday ? .briefing : .checkIn)
            } else {
                LockScreen(error: authError, onUnlock: authenticate)
            }
        }
        .task {
            if !isUnlocked { authenticate() }
        }
    }

    /// Prompts for Face ID / Touch ID, falling back to the device passcode.
    /// If the device has no authentication configured, the app unlocks rather
    /// than locking the person out.
    private func authenticate() {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            isUnlocked = true
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock tomorrowbring to see your briefing."
        ) { success, _ in
            Task { @MainActor in
                if success {
                    isUnlocked = true
                    authError = nil
                } else {
                    authError = "Couldn’t verify it’s you. Tap to try again."
                }
            }
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
