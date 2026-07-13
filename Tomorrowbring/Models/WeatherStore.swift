//
//  WeatherStore.swift
//  tomorrowbring
//

import Foundation
import Observation
import WeatherKit
import CoreLocation

struct WeatherInfo {
    /// Short current-conditions string: "18°C · Partly Cloudy"
    let displayLine: String
    /// Today's range + precip chance: "H:22° · L:14° · 30% rain"
    let todayLine: String?
    /// Upcoming change if relevant: "Rain expected around 3:00 PM" / "Clearing around 2:00 PM"
    let forecastNote: String?
    /// Full natural-language paragraph for AI context.
    let contextString: String
}

/// Shared weather state. Inject once at the app root via `.environment(weatherStore)`.
/// Multiple callers can `await load()` concurrently — only one fetch runs.
@Observable
@MainActor
final class WeatherStore: NSObject {
    private(set) var info: WeatherInfo? = nil
    private(set) var diagnostic: String? = nil

    private var loadTask: Task<Void, Never>? = nil
    private let locationManager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    /// Loads weather if not already loaded. Multiple concurrent callers wait for the
    /// same underlying fetch rather than starting independent requests.
    func load() async {
        if info != nil { return }
        if let task = loadTask {
            await task.value
            return
        }
        let task = Task {
            let result = await self.fetch()
            self.info = result.info
            self.diagnostic = result.info == nil ? result.diagnostic : nil
            self.loadTask = nil
        }
        loadTask = task
        await task.value
    }

    /// Forces a fresh fetch, replacing the cached result.
    func reload() async {
        info = nil
        loadTask?.cancel()
        loadTask = nil
        await load()
    }

    // MARK: - Private fetch

    private func fetch() async -> (info: WeatherInfo?, diagnostic: String) {
        let status = await resolvedAuthorizationStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return (nil, "Location permission denied (status: \(status))")
        }
        guard let location = await fetchLocationWithTimeout() else {
            return (nil, "Location fetch timed out or failed")
        }
        let coords = String(format: "%.3f, %.3f", location.coordinate.latitude, location.coordinate.longitude)
        do {
            let info = try await fetchWeatherInfo(for: location)
            return (info, "OK — \(coords)")
        } catch {
            return (nil, "WeatherKit error: \(error) (coords: \(coords))")
        }
    }

    private func resolvedAuthorizationStatus() async -> CLAuthorizationStatus {
        let current = locationManager.authorizationStatus
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            authContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func fetchLocationWithTimeout() async -> CLLocation? {
        await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        self.locationContinuation = continuation
                        self.locationManager.startUpdatingLocation()
                    }
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            Task { @MainActor in
                self.locationManager.stopUpdatingLocation()
                self.locationContinuation?.resume(returning: nil)
                self.locationContinuation = nil
            }
            return result
        }
    }

    private func fetchWeatherInfo(for location: CLLocation) async throws -> WeatherInfo {
        let weather = try await WeatherService.shared.weather(for: location)
        let current = weather.currentWeather
        let daily = weather.dailyForecast
        let hourly = weather.hourlyForecast

        let tempFmt = MeasurementFormatter()
        tempFmt.unitStyle = .short
        tempFmt.numberFormatter.maximumFractionDigits = 0

        let currentTemp = tempFmt.string(from: current.temperature)
        let conditionText = current.condition.description
        let outdoorNow = isOutdoorFriendly(current.condition)

        var todayLine: String? = nil
        var highLowCtx = ""
        var precipCtx = ""
        if let today = daily.first {
            let high = tempFmt.string(from: today.highTemperature)
            let low = tempFmt.string(from: today.lowTemperature)
            let pct = Int(today.precipitationChance * 100)
            todayLine = "H:\(high) · L:\(low) · \(pct)% rain"
            highLowCtx = "Today's high \(high), low \(low)."
            precipCtx = "\(pct)% chance of precipitation today."
        }

        var windCtx = ""
        let speedKmh = current.wind.speed.converted(to: .kilometersPerHour).value
        if speedKmh > 20 {
            let speedStr = tempFmt.string(from: current.wind.speed)
            windCtx = "Wind: \(speedStr)."
        }

        let now = Date.now
        let in12h = now.addingTimeInterval(12 * 3600)
        let upcomingHours = hourly.filter { $0.date > now && $0.date <= in12h }
        var forecastNote: String? = nil
        if outdoorNow {
            if let bad = upcomingHours.first(where: { !isOutdoorFriendly($0.condition) || $0.precipitationChance > 0.5 }) {
                let t = bad.date.formatted(date: .omitted, time: .shortened)
                forecastNote = "\(bad.condition.description) expected around \(t)"
            }
        } else {
            if let clear = upcomingHours.first(where: { isOutdoorFriendly($0.condition) && $0.precipitationChance < 0.2 }) {
                let t = clear.date.formatted(date: .omitted, time: .shortened)
                forecastNote = "Clearing expected around \(t)"
            }
        }

        let outdoorNote = outdoorNow
            ? "Conditions are currently suitable for outdoor activity."
            : "Conditions are currently not suitable for outdoor activity."

        var ctxParts = ["Current weather: \(currentTemp), \(conditionText). \(outdoorNote)"]
        if !highLowCtx.isEmpty { ctxParts.append(highLowCtx) }
        if !precipCtx.isEmpty  { ctxParts.append(precipCtx) }
        if !windCtx.isEmpty    { ctxParts.append(windCtx) }
        if let note = forecastNote { ctxParts.append("\(note).") }

        return WeatherInfo(
            displayLine: "\(currentTemp) · \(conditionText)",
            todayLine: todayLine,
            forecastNote: forecastNote,
            contextString: ctxParts.joined(separator: " ")
        )
    }

    private func isOutdoorFriendly(_ condition: WeatherCondition) -> Bool {
        switch condition {
        case .rain, .heavyRain, .drizzle, .freezingDrizzle, .freezingRain, .sunShowers,
             .snow, .heavySnow, .flurries, .sunFlurries, .blowingSnow, .blizzard,
             .sleet, .wintryMix,
             .thunderstorms, .scatteredThunderstorms, .isolatedThunderstorms, .strongStorms,
             .hail, .tropicalStorm, .hurricane,
             .foggy, .haze, .smoky, .blowingDust:
            return false
        default:
            return true
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherStore: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authContinuation?.resume(returning: manager.authorizationStatus)
            authContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let continuation = locationContinuation else { return }
            locationContinuation = nil
            manager.stopUpdatingLocation()
            continuation.resume(returning: locations.last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorLocationUnknown means the manager is still trying — don't give up yet.
        if let clError = error as? CLError, clError.code == .locationUnknown { return }
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}
