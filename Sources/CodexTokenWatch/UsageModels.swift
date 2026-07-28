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

struct UsagePoint: Identifiable, Sendable, Equatable {
    let date: Date
    let tokens: Int
    var id: Date { date }
}

struct RateWindow: Sendable, Equatable {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date

    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }

    var title: String {
        windowMinutes <= 300 ? "5-hour allowance" : "Weekly allowance"
    }

    var resetDescription: String {
        let remaining = max(0, resetsAt.timeIntervalSinceNow)
        if remaining < 3_600 {
            return "Resets in \(max(1, Int(ceil(remaining / 60)))) min"
        }
        if remaining < 86_400 {
            return "Resets in \(max(1, Int(ceil(remaining / 3_600)))) hr"
        }
        return "Resets in \(max(1, Int(ceil(remaining / 86_400)))) days"
    }
}

struct UsageSnapshot: Sendable, Equatable {
    let today: TokenTotals
    let week: TokenTotals
    let allTime: TokenTotals
    let daily: [UsagePoint]
    let fiveHour: RateWindow?
    let weekly: RateWindow?
    let filesScanned: Int
    let eventsCounted: Int
    let updatedAt: Date

    var preferredLimit: RateWindow? { fiveHour ?? weekly }
    var estimatedCredits: Double {
        let inputCost = Double(allTime.uncachedInput) / 1_000_000 * 1.25
        let cachedCost = Double(allTime.cachedInput) / 1_000_000 * 0.125
        let outputCost = Double(allTime.output) / 1_000_000 * 10
        return inputCost + cachedCost + outputCost
    }

    static let empty = UsageSnapshot(
        today: .zero,
        week: .zero,
        allTime: .zero,
        daily: [],
        fiveHour: nil,
        weekly: nil,
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
