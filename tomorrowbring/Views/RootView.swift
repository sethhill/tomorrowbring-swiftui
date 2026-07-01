//
//  RootView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

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
            // Prompt at first launch.
            if !lock.isUnlocked { lock.authenticate() }
        }
        #if canImport(UIKit)
        // Lock when the app is backgrounded.
        .task { await lockOnEvent(UIApplication.didEnterBackgroundNotification) }
        // Lock when the device screen locks (protected data becomes unavailable).
        .task { await lockOnEvent(UIApplication.protectedDataWillBecomeUnavailableNotification) }
        // Re-authenticate when the app returns to the foreground.
        .task { await reauthOnEvent(UIApplication.willEnterForegroundNotification) }
        #endif
    }

    #if canImport(UIKit)
    /// Locks the app each time the given notification is posted.
    private func lockOnEvent(_ name: Notification.Name) async {
        for await _ in NotificationCenter.default.notifications(named: name) {
            lock.lock()
        }
    }

    /// Prompts for authentication (when locked) each time the notification posts.
    private func reauthOnEvent(_ name: Notification.Name) async {
        for await _ in NotificationCenter.default.notifications(named: name) {
            if !lock.isUnlocked { lock.authenticate() }
        }
    }
    #endif
}

/// Shown while the app is locked, with a button to (re)try authentication.
private struct LockScreen: View {
    let error: String?
    let onUnlock: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("appSplash")
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if let error {
                    Text(error)
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Unlock", action: onUnlock)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appBackground)
                    .foregroundStyle(.black)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}
