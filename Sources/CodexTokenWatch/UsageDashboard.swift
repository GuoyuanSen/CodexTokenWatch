import SwiftUI

struct UsageDashboard: View {
    @ObservedObject var store: UsageStore
    @AppStorage(AppSettings.appearanceKey) private var appearanceModeValue = AppearanceMode.dark.rawValue
    @AppStorage(AppSettings.languageKey) private var languageValue = AppLanguage.english.rawValue
    @AppStorage(AppSettings.accountPlanKey) private var accountPlanValue = AccountPlanMode.automatic.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeValue) ?? .dark
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageValue) ?? .english
    }

    private var accountPlanMode: AccountPlanMode {
        AccountPlanMode(rawValue: accountPlanValue) ?? .automatic
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    accountSection
                    allowanceSection
                    summaryCards
                    compositionSection
                    footer
                }
                .padding(18)
            }
        }
        .frame(width: 420, height: 540)
        .preferredColorScheme(appearanceMode.colorScheme)
        .alert("CodexTokenWatch", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button(language.text("OK", "确定"), role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var backgroundColor: Color {
        appearanceMode == .dark
            ? Color(red: 0.075, green: 0.075, blue: 0.085)
            : Color(nsColor: .windowBackgroundColor)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("CodexTokenWatch")
                    .font(.title2.bold())
                Text(language.text("Local-only usage estimate", "仅限本机的用量估算"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            settingsMenu

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
                                ? language.text("Updating…", "正在更新…")
                                : updateDescription(reference: context.date)
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(store.isRefreshing)
                .help(language.text("Refresh from local Codex logs", "读取本机 Codex 日志"))
            }
        }
    }

    private var settingsMenu: some View {
        Menu {
            Text(language.text("Language / 语言", "语言 / Language"))
            ForEach(AppLanguage.allCases) { option in
                Button {
                    languageValue = option.rawValue
                } label: {
                    selectionLabel(option.title, selected: language == option)
                }
            }

            Divider()
            Text(language.text("Account plan", "账号套餐"))
            ForEach(AccountPlanMode.allCases) { mode in
                Button {
                    accountPlanValue = mode.rawValue
                } label: {
                    selectionLabel(
                        mode.title(
                            language: language,
                            detectedPlan: store.snapshot.account?.plan
                        ),
                        selected: accountPlanMode == mode
                    )
                }
            }

            Divider()
            Text(language.text("Appearance", "外观"))
            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    appearanceModeValue = mode.rawValue
                } label: {
                    selectionLabel(mode.title(language: language), selected: appearanceMode == mode)
                }
            }

            Divider()
            Toggle(isOn: $store.automaticRefreshEnabled) {
                Label(
                    language.text("Smart auto-refresh", "智能自动刷新"),
                    systemImage: "bolt.horizontal.circle"
                )
            }
            Toggle(isOn: $store.resetReminderEnabled) {
                Label(
                    language.text("Reset reminder", "重置提醒"),
                    systemImage: "bell"
                )
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(language.text("Settings", "设置"))
    }

    @ViewBuilder
    private func selectionLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if let account = store.snapshot.account {
            HStack(spacing: 10) {
                Text(account.initials)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        LinearGradient(
                            colors: [.orange.opacity(0.9), .brown.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(account.email)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
                if let plan = accountPlanMode.resolvedPlan(detectedPlan: account.plan) {
                    Menu {
                        ForEach(AccountPlanMode.allCases) { mode in
                            Button {
                                accountPlanValue = mode.rawValue
                            } label: {
                                selectionLabel(
                                    mode.title(
                                        language: language,
                                        detectedPlan: account.plan
                                    ),
                                    selected: accountPlanMode == mode
                                )
                            }
                        }
                    } label: {
                        Text(plan)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.primary.opacity(0.08), in: Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help(
                        language.text(
                            "Choose a plan when the local Codex token is stale",
                            "本机 Codex 登录字段过期时可手动选择套餐"
                        )
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .cardBackground()
        } else {
            Label(
                language.text("Local Codex account not found", "未找到本机 Codex 账号"),
                systemImage: "person.crop.circle.badge.questionmark"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
        }
    }

    @ViewBuilder
    private var allowanceSection: some View {
        if let limit = store.snapshot.weekly {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                AllowanceCard(
                    limit: limit,
                    language: language,
                    reminderEnabled: $store.resetReminderEnabled
                )
            }
        } else {
            Label(
                language.text(
                    "No weekly allowance data found in recent local logs",
                    "最近的本机日志中没有每周额度数据"
                ),
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            MetricCard(
                title: language.text("Today", "今日消耗"),
                value: store.snapshot.today.total,
                tint: .green,
                comparison: UsageComparison(
                    current: store.snapshot.today.total,
                    previous: store.snapshot.yesterday.total,
                    currentPeriod: language.text("Today", "今日"),
                    period: language.text("yesterday", "昨日"),
                    previousPeriodTitle: language.text(
                        "Yesterday at the same time",
                        "昨日同期"
                    ),
                    language: language
                ),
                language: language
            )
            MetricCard(
                title: language.text("This week", "本周消耗"),
                value: store.snapshot.week.total,
                tint: .blue,
                comparison: UsageComparison(
                    current: store.snapshot.week.total,
                    previous: store.snapshot.previousWeek.total,
                    currentPeriod: language.text("This week to date", "本周一至今"),
                    period: language.text("last week", "上周"),
                    previousPeriodTitle: language.text("Same period last week", "上周同期"),
                    language: language
                ),
                language: language
            )
            MetricCard(
                title: language.text("All local", "本机总量"),
                value: store.snapshot.allTime.total,
                tint: .purple,
                language: language
            )
        }
    }

    private var compositionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("All-local composition", "本机 Token 构成"))
                        .font(.headline)
                    Text(language.text("Input, cache, and output share", "普通输入、缓存输入与输出占比"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "≈ %.2f credits", store.snapshot.estimatedCredits))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                TokenDonut(
                    total: store.snapshot.allTime.compositionTotal,
                    segments: compositionSegments,
                    language: language
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
        .cardBackground(cornerRadius: 14)
    }

    private var compositionSegments: [CompositionSegment] {
        let totals = store.snapshot.allTime
        return [
            CompositionSegment(
                id: "input",
                name: language.text("Input", "普通输入"),
                value: totals.uncachedInput,
                color: .pink
            ),
            CompositionSegment(
                id: "cached",
                name: language.text("Cached", "缓存输入"),
                value: totals.cachedInput,
                color: .purple
            ),
            CompositionSegment(
                id: "output",
                name: language.text("Output", "输出"),
                value: totals.output,
                color: .orange
            )
        ]
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle()
                    .fill(store.automaticRefreshEnabled ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text(
                    store.automaticRefreshEnabled
                        ? language.text("Smart refresh is active", "智能刷新已开启")
                        : language.text("Smart refresh is off", "智能刷新已关闭")
                )
            }
            Text(
                language.text(
                    "\(store.snapshot.eventsCounted.formatted()) usage events · \(store.snapshot.filesScanned.formatted()) session files",
                    "\(store.snapshot.eventsCounted.formatted()) 条用量记录 · \(store.snapshot.filesScanned.formatted()) 个会话文件"
                )
            )
            Text(
                language.text(
                    "Last refresh: \(updateDescription(reference: .now)). Official Codex usage remains authoritative.",
                    "最近刷新：\(updateDescription(reference: .now))。请以 Codex 官方用量为准。"
                )
            )
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func updateDescription(reference: Date) -> String {
        let age = max(0, reference.timeIntervalSince(store.snapshot.updatedAt))
        if age < 45 { return language.text("Just updated", "刚刚更新") }
        if age < 3_600 {
            return language.text(
                "\(max(1, Int(age / 60))) min ago",
                "\(max(1, Int(age / 60))) 分钟前"
            )
        }
        if age < 86_400 {
            return language.text(
                "\(max(1, Int(age / 3_600))) hr ago",
                "\(max(1, Int(age / 3_600))) 小时前"
            )
        }
        return store.snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

private enum AppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .light: language.text("Light", "浅色")
        case .dark: language.text("Dark", "深色")
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}

private extension View {
    func cardBackground(cornerRadius: CGFloat = 12) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.primary.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.primary.opacity(0.16), lineWidth: 1)
                }
        )
    }
}

private struct CompositionSegment: Identifiable {
    let id: String
    let name: String
    let value: Int
    let color: Color
}

private struct TokenDonut: View {
    let total: Int
    let segments: [CompositionSegment]
    let language: AppLanguage

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
                .stroke(.secondary.opacity(0.14), lineWidth: 17)

            ForEach(Array(nonZeroSegments.enumerated()), id: \.offset) { _, item in
                let gap = min(0.012, max(0, (item.end - item.start) * 0.18))
                Circle()
                    .trim(from: min(1, item.start + gap), to: max(0, item.end - gap))
                    .stroke(
                        AngularGradient(
                            colors: [item.segment.color.opacity(0.72), item.segment.color],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 17, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: item.segment.color.opacity(0.24), radius: 5)
            }

            Circle()
                .fill(.background.opacity(0.92))
                .frame(width: 82, height: 82)
                .overlay {
                    Circle().strokeBorder(.primary.opacity(0.1))
                }

            VStack(spacing: 2) {
                Text(TokenFormatter.compact(total))
                    .font(.title3.bold().monospacedDigit())
                    .minimumScaleFactor(0.7)
                Text(language.text("total tokens", "全部 Token"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text("Total tokens", "Token 总量"))
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
        .help("\(segment.value.formatted()) tokens")
    }
}

private struct AllowanceCard: View {
    let limit: RateWindow
    let language: AppLanguage
    @Binding var reminderEnabled: Bool

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

    private var forecastLabel: String {
        switch forecast.state {
        case .learning: language.text("Learning", "学习中")
        case .likelySafe: language.text("On track", "预计充足")
        case .atRisk: language.text("At risk", "可能用尽")
        case .stale: language.text("Waiting", "等待更新")
        }
    }

    private var forecastHelp: String {
        switch forecast.state {
        case .learning:
            language.text(
                "More activity is needed before a useful estimate can be calculated.",
                "需要更多使用记录才能给出可靠预测。"
            )
        case .likelySafe:
            language.text(
                "At the current pace, the allowance is likely to last until reset.",
                "按照当前速度，额度预计可持续到重置。"
            )
        case .atRisk:
            language.text(
                "At the current pace, the allowance may run out before reset.",
                "按照当前速度，额度可能在重置前用尽。"
            )
        case .stale:
            language.text(
                "The estimate will update after the next Codex request.",
                "下次使用 Codex 后将更新额度信息。"
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("Weekly allowance", "本周剩余"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(Int(limit.remainingPercent.rounded()))%")
                        .font(.title.bold().monospacedDigit())
                }
                Spacer()
                HStack(spacing: 7) {
                    Button {
                        reminderEnabled.toggle()
                    } label: {
                        Image(systemName: reminderEnabled ? "bell.fill" : "bell")
                            .foregroundStyle(reminderEnabled ? Color.orange : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(
                        reminderEnabled
                            ? language.text("Reset reminder is on", "重置提醒已开启")
                            : language.text("Remind me 10 minutes before reset", "重置前 10 分钟提醒")
                    )

                    Label(forecastLabel, systemImage: forecastIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(forecastTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(forecastTint.opacity(0.12), in: Capsule())
                }
            }

            ProgressView(value: limit.remainingPercent, total: 100)
                .tint(tint)

            Label(
                resetText,
                systemImage: "clock.arrow.circlepath"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(tint.opacity(0.075))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.primary.opacity(0.18), lineWidth: 1)
                }
        )
        .help(forecastHelp)
    }

    private var resetText: String {
        let remaining = limit.resetsAt.timeIntervalSince(.now)
        guard remaining > 0 else {
            return language.text("Waiting for fresh reset data", "等待新的重置数据")
        }
        return language.text(
            "Resets in \(limit.resetCountdown())",
            "\(limit.resetCountdown()) 后重置"
        )
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let tint: Color
    var comparison: UsageComparison?
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(TokenFormatter.compact(value))
                .font(.headline.monospacedDigit())
            if let comparison {
                Label(comparison.label, systemImage: comparison.icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(comparison.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(comparison.tint.opacity(0.12), in: Capsule())
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
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(tint.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(.primary.opacity(0.13))
                }
        )
        .help(comparison?.help ?? "\(title): \(value.formatted()) tokens")
    }
}

private struct UsageComparison {
    let current: Int
    let previous: Int
    let currentPeriod: String
    let period: String
    let previousPeriodTitle: String
    let language: AppLanguage

    private var change: Double? {
        guard previous > 0 else { return nil }
        return (Double(current - previous) / Double(previous)) * 100
    }

    var label: String {
        guard let change else {
            return current > 0
                ? language.text("New", "新增")
                : language.text("No change", "无变化")
        }
        let rounded = Int(abs(change).rounded())
        let percent = rounded > 999 ? "999%+" : "\(rounded)%"
        return language == .chinese
            ? "\(percent) 较\(period)"
            : "\(percent) vs \(period)"
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
        \(language.text("Difference", "差值")): \(sign)\(difference.formatted()) tokens
        """
    }
}
