//
//  AppLock.swift
//  tomorrowbring
//
//  Created by Seth Hill on 01.07.2026.
//

import SwiftUI
import LocalAuthentication

/// Owns the app's locked/unlocked state and biometric authentication. Locks on
/// app-lifecycle events (background, screen lock) and, as a guaranteed backstop,
/// after `autoLockInterval` of being unlocked.
@Observable
@MainActor
final class AppLock {
    private(set) var isUnlocked = false
    var authError: String?

    /// How long the app stays unlocked before auto-locking. A backstop that does
    /// not depend on any app-lifecycle events firing.
    var autoLockInterval: TimeInterval = 5 * 60

    private var isAuthenticating = false
    private var autoLockTask: Task<Void, Never>?

    /// Locks the app, requiring authentication before content is shown again.
    func lock() {
        autoLockTask?.cancel()
        autoLockTask = nil
        isUnlocked = false
    }

    /// Prompts for Face ID / Touch ID, falling back to the device passcode. If
    /// the device has no authentication configured, the app unlocks rather than
    /// locking the person out.
    func authenticate() {
        guard !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true

        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            unlock()
            isAuthenticating = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock tomorrowbring to see your briefing."
        ) { success, _ in
            Task { @MainActor in
                self.isAuthenticating = false
                if success {
                    self.unlock()
                    self.authError = nil
                } else {
                    self.authError = "Couldn’t verify it’s you. Tap to try again."
                }
            }
        }
    }

    /// Marks the app unlocked and (re)starts the auto-lock countdown.
    private func unlock() {
        isUnlocked = true
        scheduleAutoLock()
    }

    /// Schedules a lock after `autoLockInterval`, replacing any pending one.
    private func scheduleAutoLock() {
        autoLockTask?.cancel()
        let interval = autoLockInterval
        autoLockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            self?.lock()
        }
    }
}
