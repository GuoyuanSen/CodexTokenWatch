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
    @Published var periodicRefreshEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                periodicRefreshEnabled,
                forKey: AppSettings.periodicRefreshEnabledKey
            )
            onPeriodicRefreshChange?(periodicRefreshEnabled, periodicRefreshMinutes)
        }
    }
    @Published var periodicRefreshMinutes: Int {
        didSet {
            let validValue = min(
                AppSettings.maximumPeriodicRefreshMinutes,
                max(AppSettings.minimumPeriodicRefreshMinutes, periodicRefreshMinutes)
            )
            guard periodicRefreshMinutes == validValue else {
                periodicRefreshMinutes = validValue
                return
            }
            UserDefaults.standard.set(
                periodicRefreshMinutes,
                forKey: AppSettings.periodicRefreshMinutesKey
            )
            onPeriodicRefreshChange?(periodicRefreshEnabled, periodicRefreshMinutes)
        }
    }
    @Published var resetReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(resetReminderEnabled, forKey: AppSettings.resetReminderKey)
            updateResetReminder()
        }
    }
    private let scanner = LocalLogScanner()
    private var refreshPending = false

    var onSnapshotChange: ((UsageSnapshot) -> Void)?
    var onAutomaticRefreshChange: ((Bool) -> Void)?
    var onPeriodicRefreshChange: ((Bool, Int) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        automaticRefreshEnabled = defaults.object(forKey: AppSettings.automaticRefreshKey) == nil
            ? true
            : defaults.bool(forKey: AppSettings.automaticRefreshKey)
        periodicRefreshEnabled = defaults.object(
            forKey: AppSettings.periodicRefreshEnabledKey
        ) == nil
            ? true
            : defaults.bool(forKey: AppSettings.periodicRefreshEnabledKey)
        let savedMinutes = defaults.object(forKey: AppSettings.periodicRefreshMinutesKey) == nil
            ? AppSettings.defaultPeriodicRefreshMinutes
            : defaults.integer(forKey: AppSettings.periodicRefreshMinutesKey)
        periodicRefreshMinutes = min(
            AppSettings.maximumPeriodicRefreshMinutes,
            max(AppSettings.minimumPeriodicRefreshMinutes, savedMinutes)
        )
        resetReminderEnabled = defaults.bool(forKey: AppSettings.resetReminderKey)
    }

    func refresh() {
        guard !isRefreshing else {
            refreshPending = true
            return
        }
        isRefreshing = true
        Task.detached(priority: .utility) { [scanner] in
            let result = scanner.scan()
            await MainActor.run {
                self.snapshot = result
                self.isRefreshing = false
                self.onSnapshotChange?(result)
                self.updateResetReminder()
                if self.refreshPending {
                    self.refreshPending = false
                    self.refresh()
                }
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
