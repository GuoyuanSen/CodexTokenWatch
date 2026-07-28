import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot.empty
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?
    private let scanner = LocalLogScanner()

    var onSnapshotChange: ((UsageSnapshot) -> Void)?

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task.detached(priority: .utility) { [scanner] in
            let result = scanner.scan()
            await MainActor.run {
                self.snapshot = result
                self.isRefreshing = false
                self.onSnapshotChange?(result)
            }
        }
    }

    func present(error: String) {
        errorMessage = error
    }
}
