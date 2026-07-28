import AppKit
import ServiceManagement
import SwiftUI

@main
struct CodexTokenWatchApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBarController

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate, ObservableObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    @Published private var snapshot = UsageSnapshot.empty
    @Published private var isRefreshing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 420)
        popover.contentViewController = NSHostingController(rootView: DashboardView(controller: self))

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }
        refresh()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task.detached(priority: .utility) {
            let result = LocalUsageScanner.scan()
            await MainActor.run {
                self.snapshot = result
                self.isRefreshing = false
                self.updateStatusTitle()
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if #available(macOS 13.0, *) {
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("Unable to update launch-at-login setting: \(error)")
        }
    }

    var launchAtLogin: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    func quit() { NSApp.terminate(nil) }
    var usage: UsageSnapshot { snapshot }
    var refreshing: Bool { isRefreshing }

    private func updateStatusTitle() {
        let week = snapshot.week.total
        let value: String
        if week >= 1_000_000 { value = String(format: "%.1fM", Double(week) / 1_000_000) }
        else if week >= 1_000 { value = String(format: "%.0fk", Double(week) / 1_000) }
        else { value = "\(week)" }
        statusItem.button?.title = " ◉ \(value)"
        statusItem.button?.toolTip = "Codex local usage this week: \(week.formatted()) tokens"
    }
}

struct TokenTotals: Sendable, Equatable {
    var input = 0
    var cached = 0
    var output = 0
    var total: Int { input + cached + output }
    static let zero = TokenTotals()
}

struct UsageSnapshot: Sendable, Equatable {
    var today: TokenTotals
    var week: TokenTotals
    var allTime: TokenTotals
    var filesScanned: Int
    var updatedAt: Date
    static let empty = UsageSnapshot(today: .zero, week: .zero, allTime: .zero, filesScanned: 0, updatedAt: .now)
}

struct TokenRecord: Sendable {
    let date: Date
    let totals: TokenTotals
}

enum LocalUsageScanner {
    static func scan() -> UsageSnapshot {
        let fileManager = FileManager.default
        let root = fileManager.homeDirectoryForCurrentUser.appending(path: ".codex", directoryHint: .isDirectory)
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return .empty
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? startOfToday
        var today = TokenTotals.zero
        var week = TokenTotals.zero
        var allTime = TokenTotals.zero
        var files = 0

        for case let file as URL in enumerator {
            guard ["json", "jsonl"].contains(file.pathExtension.lowercased()),
                  let attributes = try? file.resourceValues(forKeys: [.isRegularFileKey]), attributes.isRegularFile == true,
                  let data = try? Data(contentsOf: file), data.count < 20_000_000 else { continue }
            files += 1
            for record in records(in: data, fallbackDate: file, fileManager: fileManager) {
                allTime.add(record.totals)
                if record.date >= startOfWeek { week.add(record.totals) }
                if record.date >= startOfToday { today.add(record.totals) }
            }
        }
        return UsageSnapshot(today: today, week: week, allTime: allTime, filesScanned: files, updatedAt: .now)
    }

    private static func records(in data: Data, fallbackDate file: URL, fileManager: FileManager) -> [TokenRecord] {
        let fallbackDate = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .now
        let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
        let objects: [[String: Any]]
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { objects = [object] }
        else { objects = lines.compactMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] } }

        return objects.compactMap { object in
            let totals = tokenTotals(in: object)
            guard totals.total > 0 else { return nil }
            return TokenRecord(date: timestamp(in: object) ?? fallbackDate, totals: totals)
        }
    }

    private static func tokenTotals(in object: [String: Any]) -> TokenTotals {
        var values: [String: Int] = [:]
        collectTokenValues(from: object, into: &values)
        return TokenTotals(input: values["input"] ?? 0, cached: values["cached"] ?? 0, output: values["output"] ?? 0)
    }

    private static func collectTokenValues(from value: Any, into values: inout [String: Int]) {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                let normalized = key.lowercased()
                if let number = child as? NSNumber {
                    if normalized == "input_tokens" || normalized == "input" { values["input", default: 0] += number.intValue }
                    if normalized == "cached_input_tokens" || normalized == "cache_read_input_tokens" || normalized == "cached_tokens" { values["cached", default: 0] += number.intValue }
                    if normalized == "output_tokens" || normalized == "output" { values["output", default: 0] += number.intValue }
                } else { collectTokenValues(from: child, into: &values) }
            }
        } else if let array = value as? [Any] {
            for child in array { collectTokenValues(from: child, into: &values) }
        }
    }

    private static func timestamp(in object: [String: Any]) -> Date? {
        let decoder = ISO8601DateFormatter()
        for key in ["timestamp", "created_at", "time", "date"] {
            if let value = object[key] as? String, let date = decoder.date(from: value) { return date }
        }
        return nil
    }
}

private extension TokenTotals {
    mutating func add(_ other: TokenTotals) {
        input += other.input; cached += other.cached; output += other.output
    }
}

struct DashboardView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CodexTokenWatch").font(.title3.bold())
                    Text("Local estimate · no data leaves this Mac").foregroundStyle(.secondary).font(.caption)
                }
                Spacer()
                Button { controller.refresh() } label: {
                    Image(systemName: controller.refreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise")
                }.buttonStyle(.plain).disabled(controller.refreshing)
            }
            HStack(spacing: 10) {
                UsageCard(title: "Today", totals: controller.usage.today, color: .blue)
                UsageCard(title: "This week", totals: controller.usage.week, color: .green)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("All local activity").font(.headline)
                TokenBar(label: "Input", value: controller.usage.allTime.input, total: controller.usage.allTime.total, color: .blue)
                TokenBar(label: "Cached input", value: controller.usage.allTime.cached, total: controller.usage.allTime.total, color: .purple)
                TokenBar(label: "Output", value: controller.usage.allTime.output, total: controller.usage.allTime.total, color: .orange)
            }
            Divider()
            HStack {
                Toggle("Launch at login", isOn: Binding(get: { controller.launchAtLogin }, set: controller.setLaunchAtLogin))
                Spacer()
                Button("Quit", action: controller.quit).buttonStyle(.borderless)
            }
            Text("Scanned \(controller.usage.filesScanned) local JSON/JSONL files · Updated \(controller.usage.updatedAt, style: .time)")
                .foregroundStyle(.secondary).font(.caption2)
        }
        .padding(18)
        .frame(width: 380)
    }
}

struct UsageCard: View {
    let title: String; let totals: TokenTotals; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(totals.total.formatted()).font(.title3.bold())
            Text("tokens").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct TokenBar: View {
    let label: String; let value: Int; let total: Int; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(label).font(.caption); Spacer(); Text(value.formatted()).font(.caption.monospacedDigit()) }
            ProgressView(value: total == 0 ? 0 : Double(value), total: max(1, Double(total))).tint(color)
        }
    }
}
