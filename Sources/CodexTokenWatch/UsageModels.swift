import Foundation

struct TokenTotals: Sendable, Equatable {
    var input = 0
    var cachedInput = 0
    var output = 0

    var uncachedInput: Int { max(0, input - cachedInput) }
    var total: Int { input + output }
    var compositionTotal: Int { uncachedInput + cachedInput + output }

    mutating func add(_ other: TokenTotals) {
        input += other.input
        cachedInput += other.cachedInput
        output += other.output
    }

    static let zero = TokenTotals()
}

struct RateWindow: Sendable, Equatable {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date

    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }

    func resetDescription(reference: Date = .now) -> String {
        let clock = resetsAt.formatted(date: .omitted, time: .shortened)
        let remaining = resetsAt.timeIntervalSince(reference)
        guard remaining > 0 else {
            return "Logged reset passed · waiting for fresh activity"
        }
        return "Logged reset \(Self.durationDescription(remaining)) · \(clock)"
    }

    func resetCountdown(reference: Date = .now) -> String {
        let interval = resetsAt.timeIntervalSince(reference)
        guard interval > 0 else { return "Pending" }
        if interval < 90 { return "1m" }
        if interval < 3_600 { return "\(max(1, Int(ceil(interval / 60))))m" }
        if interval < 86_400 {
            let hours = Int(interval / 3_600)
            let minutes = Int(interval.truncatingRemainder(dividingBy: 3_600) / 60)
            return minutes >= 5 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        let days = Int(interval / 86_400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86_400) / 3_600)
        return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
    }

    func forecast(reference: Date = .now) -> RateForecast {
        let remaining = resetsAt.timeIntervalSince(reference)
        guard remaining > 0 else {
            return RateForecast(
                state: .stale,
                label: "Stale",
                detail: "The logged reset has passed. The estimate updates after the next Codex request."
            )
        }
        if usedPercent >= 100 {
            return RateForecast(
                state: .atRisk,
                label: "At limit",
                detail: "The logged allowance is exhausted until the next reset."
            )
        }

        let duration = TimeInterval(windowMinutes * 60)
        let windowStart = resetsAt.addingTimeInterval(-duration)
        let elapsed = reference.timeIntervalSince(windowStart)
        guard elapsed >= 10 * 60, usedPercent >= 1 else {
            return RateForecast(
                state: .learning,
                label: "Learning",
                detail: "More activity is needed before a useful run-out estimate can be calculated."
            )
        }

        let percentPerSecond = usedPercent / elapsed
        let timeToLimit = (100 - usedPercent) / percentPerSecond
        if timeToLimit < remaining {
            return RateForecast(
                state: .atRisk,
                label: "At risk",
                detail: "At the current average pace, the allowance may run out \(Self.durationDescription(timeToLimit))."
            )
        }
        return RateForecast(
            state: .likelySafe,
            label: "On track",
            detail: "At the current average pace, the allowance is likely to last until the logged reset."
        )
    }

    private static func durationDescription(_ interval: TimeInterval) -> String {
        if interval < 90 {
            return "in about a minute"
        }
        if interval < 3_600 {
            return "in \(max(1, Int(ceil(interval / 60)))) min"
        }
        if interval < 86_400 {
            let hours = Int(interval / 3_600)
            let minutes = Int(interval.truncatingRemainder(dividingBy: 3_600) / 60)
            return minutes >= 10 ? "in \(hours) hr \(minutes) min" : "in \(hours) hr"
        }
        let days = Int(interval / 86_400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86_400) / 3_600)
        return hours > 0 ? "in \(days) d \(hours) hr" : "in \(days) days"
    }
}

struct RateForecast: Sendable, Equatable {
    enum State: Sendable {
        case learning
        case likelySafe
        case atRisk
        case stale
    }

    let state: State
    let label: String
    let detail: String
}

struct UsageSnapshot: Sendable, Equatable {
    let today: TokenTotals
    let yesterday: TokenTotals
    let week: TokenTotals
    let previousWeek: TokenTotals
    let allTime: TokenTotals
    let weekly: RateWindow?
    let account: AccountInfo?
    let filesScanned: Int
    let eventsCounted: Int
    let updatedAt: Date

    var preferredLimit: RateWindow? { weekly }

    func updateDescription(reference: Date = .now) -> String {
        let age = max(0, reference.timeIntervalSince(updatedAt))
        if age < 45 { return "Just updated" }
        if age < 3_600 { return "\(max(1, Int(age / 60))) min ago" }
        if age < 86_400 { return "\(max(1, Int(age / 3_600))) hr ago" }
        return updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var estimatedCredits: Double {
        let inputCost = Double(allTime.uncachedInput) / 1_000_000 * 1.25
        let cachedCost = Double(allTime.cachedInput) / 1_000_000 * 0.125
        let outputCost = Double(allTime.output) / 1_000_000 * 10
        return inputCost + cachedCost + outputCost
    }

    static let empty = UsageSnapshot(
        today: .zero,
        yesterday: .zero,
        week: .zero,
        previousWeek: .zero,
        allTime: .zero,
        weekly: nil,
        account: nil,
        filesScanned: 0,
        eventsCounted: 0,
        updatedAt: .now
    )
}

enum TokenFormatter {
    static func compact(_ value: Int) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return value.formatted()
    }
}
