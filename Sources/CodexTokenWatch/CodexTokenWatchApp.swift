import AppKit
import ServiceManagement
import SwiftUI

@main
enum CodexTokenWatchMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--snapshot") {
            let scanner = LocalLogScanner()
            let snapshot = scanner.scan()
            print(
                "today=\(snapshot.today.total) " +
                "week=\(snapshot.week.total) " +
                "all=\(snapshot.allTime.total) " +
                "events=\(snapshot.eventsCounted) " +
                "files=\(snapshot.filesScanned)"
            )
            return
        }

        let application = NSApplication.shared
        let coordinator = MenuBarCoordinator()
        application.delegate = coordinator
        application.run()
    }
}

@MainActor
final class MenuBarCoordinator: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store = UsageStore()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 610)
        popover.contentViewController = NSHostingController(rootView: UsageDashboard(store: store))

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemPressed)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        store.onSnapshotChange = { [weak self] snapshot in
            self?.updateStatusItem(with: snapshot)
        }
        store.refresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.store.refresh() }
        }
    }

    @objc private func statusItemPressed() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let refresh = NSMenuItem(title: "Refresh now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let launch = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(launch)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit CodexTokenWatch", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshNow() {
        store.refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            store.present(error: "Unable to change launch-at-login: \(error.localizedDescription)")
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private var launchAtLoginEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    private func updateStatusItem(with snapshot: UsageSnapshot) {
        let remaining = snapshot.preferredLimit?.remainingPercent
        statusItem.button?.image = StatusLightImage.make(for: remaining)
        statusItem.button?.imagePosition = .imageLeft

        if let remaining {
            statusItem.button?.title = "\(Int(remaining.rounded()))%"
            statusItem.button?.toolTip = "Codex allowance remaining"
        } else {
            statusItem.button?.title = TokenFormatter.compact(snapshot.week.total)
            statusItem.button?.toolTip = "Codex tokens recorded this week"
        }
    }
}

enum StatusLightImage {
    static func make(for remaining: Double?) -> NSImage {
        let level = LimitLevel(remainingPercent: remaining)
        let size = NSSize(width: 34, height: 12)
        let image = NSImage(size: size, flipped: false) { _ in
            let colors: [NSColor] = [.systemGreen, .systemYellow, .systemRed]
            for index in 0..<3 {
                let rect = NSRect(x: CGFloat(index * 11) + 1, y: 1, width: 9, height: 9)
                let active = level.activeIndex == index
                (active ? colors[index] : colors[index].withAlphaComponent(0.2)).setFill()
                NSBezierPath(ovalIn: rect).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}

private enum LimitLevel {
    case healthy, warning, critical, unknown

    init(remainingPercent: Double?) {
        guard let remainingPercent else { self = .unknown; return }
        if remainingPercent >= 70 { self = .healthy }
        else if remainingPercent > 10 { self = .warning }
        else { self = .critical }
    }

    var activeIndex: Int? {
        switch self {
        case .healthy: 0
        case .warning: 1
        case .critical: 2
        case .unknown: nil
        }
    }
}
