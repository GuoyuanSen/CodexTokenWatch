import Charts
import SwiftUI

struct UsageDashboard: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                allowanceSection
                summaryCards
                trendSection
                compositionSection
                footer
            }
            .padding(18)
        }
        .frame(width: 420, height: 610)
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
            Button(action: store.refresh) {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(store.isRefreshing ? .degrees(180) : .zero)
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
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
            MetricCard(title: "Today", value: store.snapshot.today.total, tint: .blue)
            MetricCard(title: "This week", value: store.snapshot.week.total, tint: .green)
            MetricCard(title: "All local", value: store.snapshot.allTime.total, tint: .purple)
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("14-day token activity")
                .font(.headline)
            Chart(store.snapshot.daily) { point in
                AreaMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Tokens", point.tokens)
                )
                .foregroundStyle(.blue.opacity(0.16))
                LineMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Tokens", point.tokens)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 105)
        }
        .padding(12)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
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

    private var tint: Color {
        if limit.remainingPercent >= 70 { return .green }
        if limit.remainingPercent > 10 { return .yellow }
        return .red
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
            Text(limit.resetDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(TokenFormatter.compact(value))
                .font(.headline.monospacedDigit())
            Text("tokens")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
