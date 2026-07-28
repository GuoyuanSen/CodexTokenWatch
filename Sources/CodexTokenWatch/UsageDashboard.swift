import SwiftUI

struct UsageDashboard: View {
    @ObservedObject var store: UsageStore
    @AppStorage("appearanceMode") private var appearanceModeValue = AppearanceMode.system.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeValue) ?? .system
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                allowanceSection
                summaryCards
                compositionSection
                footer
            }
            .padding(18)
        }
        .frame(width: 420, height: 500)
        .preferredColorScheme(appearanceMode.colorScheme)
        .alert("CodexTokenWatch", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("CodexTokenWatch")
                    .font(.title2.bold())
                Text("Local-only usage estimate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appearanceModeValue = mode.rawValue
                    } label: {
                        if appearanceMode == mode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }
            } label: {
                Image(systemName: appearanceMode.icon)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Appearance")

            TimelineView(.periodic(from: .now, by: 30)) { context in
                Button(action: store.refresh) {
                    HStack(spacing: 5) {
                        if store.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(
                            store.isRefreshing
                                ? "Updating…"
                                : store.snapshot.updateDescription(reference: context.date)
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(store.isRefreshing)
                .help("Refresh from local Codex logs")
            }
        }
    }

    @ViewBuilder
    private var allowanceSection: some View {
        if store.snapshot.fiveHour != nil || store.snapshot.weekly != nil {
            HStack(spacing: 10) {
                if let limit = store.snapshot.fiveHour {
                    AllowanceCard(limit: limit)
                }
                if let limit = store.snapshot.weekly {
                    AllowanceCard(limit: limit)
                }
            }
        } else {
            Label("No allowance data found in recent local logs", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            MetricCard(
                title: "Today",
                value: store.snapshot.today.total,
                tint: .blue,
                comparison: UsageComparison(
                    current: store.snapshot.today.total,
                    previous: store.snapshot.yesterday.total,
                    currentPeriod: "Today",
                    period: "yesterday",
                    previousPeriodTitle: "Yesterday"
                )
            )
            MetricCard(
                title: "This week",
                value: store.snapshot.week.total,
                tint: .green,
                comparison: UsageComparison(
                    current: store.snapshot.week.total,
                    previous: store.snapshot.previousWeek.total,
                    currentPeriod: "This week",
                    period: "last week",
                    previousPeriodTitle: "Same period last week"
                )
            )
            MetricCard(title: "All local", value: store.snapshot.allTime.total, tint: .purple)
        }
    }

    private var compositionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("All-local composition")
                        .font(.headline)
                    Text("Input, cache, and output share")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "~%.2f credits", store.snapshot.estimatedCredits))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                TokenDonut(
                    total: store.snapshot.allTime.compositionTotal,
                    segments: compositionSegments
                )
                .frame(width: 126, height: 126)

                VStack(spacing: 12) {
                    ForEach(compositionSegments) { segment in
                        CompositionLegendRow(
                            segment: segment,
                            total: store.snapshot.allTime.compositionTotal
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.quaternary.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.07))
                }
        )
    }

    private var compositionSegments: [CompositionSegment] {
        let totals = store.snapshot.allTime
        return [
            CompositionSegment(name: "Input", value: totals.uncachedInput, color: .pink),
            CompositionSegment(name: "Cached", value: totals.cachedInput, color: .purple),
            CompositionSegment(name: "Output", value: totals.output, color: .orange)
        ]
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(store.snapshot.eventsCounted.formatted()) usage events · \(store.snapshot.filesScanned.formatted()) session files")
            Text("Updated \(store.snapshot.updatedAt, style: .relative). Official Codex usage remains authoritative.")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

private enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct CompositionSegment: Identifiable {
    let name: String
    let value: Int
    let color: Color
    var id: String { name }
}

private struct TokenDonut: View {
    let total: Int
    let segments: [CompositionSegment]

    private var nonZeroSegments: [(segment: CompositionSegment, start: Double, end: Double)] {
        guard total > 0 else { return [] }
        var cursor = 0.0
        return segments.compactMap { segment in
            guard segment.value > 0 else { return nil }
            let share = Double(segment.value) / Double(total)
            let start = cursor
            cursor += share
            return (segment, start, cursor)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.12), lineWidth: 17)

            ForEach(Array(nonZeroSegments.enumerated()), id: \.offset) { _, item in
                let gap = min(0.012, max(0, (item.end - item.start) * 0.18))
                Circle()
                    .trim(
                        from: min(1, item.start + gap),
                        to: max(0, item.end - gap)
                    )
                    .stroke(
                        AngularGradient(
                            colors: [
                                item.segment.color.opacity(0.72),
                                item.segment.color
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 17, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: item.segment.color.opacity(0.24), radius: 5)
            }

            Circle()
                .fill(.background.opacity(0.78))
                .frame(width: 82, height: 82)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.06))
                }

            VStack(spacing: 2) {
                Text(TokenFormatter.compact(total))
                    .font(.title3.bold().monospacedDigit())
                    .minimumScaleFactor(0.7)
                Text("total tokens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total tokens")
        .accessibilityValue(total.formatted())
    }
}

private struct CompositionLegendRow: View {
    let segment: CompositionSegment
    let total: Int

    private var percent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(segment.value) / Double(total) * 100).rounded())
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(segment.color.gradient)
                .frame(width: 10, height: 10)
                .shadow(color: segment.color.opacity(0.25), radius: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(segment.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(TokenFormatter.compact(segment.value))
                    .font(.callout.bold().monospacedDigit())
            }
            Spacer()
            Text("\(percent)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }
}

private struct AllowanceCard: View {
    let limit: RateWindow

    private var forecast: RateForecast {
        limit.forecast()
    }

    private var tint: Color {
        if limit.remainingPercent >= 70 { return .green }
        if limit.remainingPercent > 10 { return .yellow }
        return .red
    }

    private var forecastTint: Color {
        switch forecast.state {
        case .learning, .stale: .secondary
        case .likelySafe: .green
        case .atRisk: .orange
        }
    }

    private var forecastIcon: String {
        switch forecast.state {
        case .learning: "waveform.path.ecg"
        case .likelySafe: "checkmark.circle.fill"
        case .atRisk: "exclamationmark.triangle.fill"
        case .stale: "clock.badge.questionmark"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(limit.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int(limit.remainingPercent.rounded()))%")
                .font(.title2.bold().monospacedDigit())
            ProgressView(value: limit.remainingPercent, total: 100)
                .tint(tint)
            HStack(spacing: 6) {
                Label(limit.resetCountdown(), systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Label(forecast.label, systemImage: forecastIcon)
                    .foregroundStyle(forecastTint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(forecastTint.opacity(0.11), in: Capsule())
            }
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .help("\(limit.resetDescription())\n\(forecast.detail)")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let tint: Color
    var comparison: UsageComparison?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(TokenFormatter.compact(value))
                .font(.headline.monospacedDigit())
            if let comparison {
                Label(comparison.label, systemImage: comparison.icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(comparison.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(comparison.tint.opacity(0.11), in: Capsule())
                    .help(comparison.help)
            } else {
                Text("tokens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .help(comparison?.help ?? "\(title): \(value.formatted()) tokens")
    }
}

private struct UsageComparison {
    let current: Int
    let previous: Int
    let currentPeriod: String
    let period: String
    let previousPeriodTitle: String

    private var change: Double? {
        guard previous > 0 else { return nil }
        return (Double(current - previous) / Double(previous)) * 100
    }

    var label: String {
        guard let change else {
            return current > 0 ? "New vs \(period)" : "No change"
        }
        return "\(Int(abs(change).rounded()))% vs \(period)"
    }

    var icon: String {
        guard let change else { return current > 0 ? "sparkles" : "minus" }
        if change > 0.5 { return "arrow.up" }
        if change < -0.5 { return "arrow.down" }
        return "minus"
    }

    var tint: Color {
        guard let change else { return current > 0 ? .green : .secondary }
        if change > 0.5 { return .green }
        if change < -0.5 { return .blue }
        return .secondary
    }

    var help: String {
        let difference = current - previous
        let sign = difference > 0 ? "+" : ""
        return """
        \(currentPeriod): \(current.formatted()) tokens
        \(previousPeriodTitle): \(previous.formatted()) tokens
        Difference: \(sign)\(difference.formatted()) tokens
        """
    }
}
