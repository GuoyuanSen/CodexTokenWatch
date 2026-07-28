import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot.empty
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?
    @Published var automaticRefreshEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                automaticRefreshEnabled,
                forKey: AppSettings.automaticRefreshKey
            )
            onAutomaticRefreshChange?(automaticRefreshEnabled)
        }
    }
    @Published var resetReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(resetReminderEnabled, forKey: AppSettings.resetReminderKey)
            updateResetReminder()
        }
    }
    private let scanner = LocalLogScanner()

    var onSnapshotChange: ((UsageSnapshot) -> Void)?
    var onAutomaticRefreshChange: ((Bool) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        automaticRefreshEnabled = defaults.object(forKey: AppSettings.automaticRefreshKey) == nil
            ? true
            : defaults.bool(forKey: AppSettings.automaticRefreshKey)
        resetReminderEnabled = defaults.bool(forKey: AppSettings.resetReminderKey)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task.detached(priority: .utility) { [scanner] in
            let result = scanner.scan()
            await MainActor.run {
                self.snapshot = result
                self.isRefreshing = false
                self.onSnapshotChange?(result)
                self.updateResetReminder()
            }
        }
    }

    func present(error: String) {
        errorMessage = error
    }

    private func updateResetReminder() {
        guard resetReminderEnabled, let weekly = snapshot.weekly else {
            ResetReminderManager.cancel()
            return
        }
        ResetReminderManager.schedule(
            resetAt: weekly.resetsAt,
            language: AppLanguage.current
        ) { [weak self] success, message in
            guard !success else { return }
            Task { @MainActor in
                self?.resetReminderEnabled = false
                if let message {
                    self?.present(error: message)
                }
            }
        }
    }
}
