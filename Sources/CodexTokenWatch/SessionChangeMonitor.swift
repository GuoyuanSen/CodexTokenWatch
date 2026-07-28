import Darwin
import Foundation

final class SessionChangeMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.guoyuansen.CodexTokenWatch.session-monitor")
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceWorkItem: DispatchWorkItem?
    private let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }

    func start() {
        queue.async { [weak self] in
            self?.rebuildSources()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.cancelSources()
        }
    }

    private func rebuildSources() {
        cancelSources()

        let fileManager = FileManager.default
        let root = fileManager.homeDirectoryForCurrentUser
            .appending(path: ".codex/sessions", directoryHint: .isDirectory)
        let auth = fileManager.homeDirectoryForCurrentUser
            .appending(path: ".codex/auth.json")
        var URLs = [root, auth]

        if let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let URL as URL in enumerator {
                guard let values = try? URL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey]) else {
                    continue
                }
                if values.isDirectory == true || (values.isRegularFile == true && URL.pathExtension == "jsonl") {
                    URLs.append(URL)
                }
            }
        }

        for URL in URLs {
            let descriptor = open(URL.path, O_EVTONLY)
            guard descriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .attrib, .rename, .delete],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.scheduleRefresh()
            }
            source.setCancelHandler {
                close(descriptor)
            }
            source.resume()
            sources.append(source)
        }
    }

    private func scheduleRefresh() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            onChange()
            rebuildSources()
        }
        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }

    private func cancelSources() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        sources.forEach { $0.cancel() }
        sources.removeAll()
    }
}
