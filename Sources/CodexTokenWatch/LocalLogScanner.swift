import Foundation

final class LocalLogScanner: @unchecked Sendable {
    private struct ParsedEvent {
        let timestamp: Date
        let tokens: TokenTotals
        let fiveHour: RateWindow?
        let weekly: RateWindow?
        let identity: String
    }

    private struct CachedFile {
        let modifiedAt: Date?
        let size: Int?
        let events: [ParsedEvent]
    }

    private let cacheLock = NSLock()
    private var cache: [URL: CachedFile] = [:]

    func scan() -> UsageSnapshot {
        let fileManager = FileManager.default
        let root = fileManager.homeDirectoryForCurrentUser
            .appending(path: ".codex/sessions", directoryHint: .isDirectory)
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return .empty
        }

        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let startOfPreviousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) ?? startOfWeek
        let previousWeekComparableEnd = startOfPreviousWeek.addingTimeInterval(
            now.timeIntervalSince(startOfWeek)
        )

        var today = TokenTotals.zero
        var yesterday = TokenTotals.zero
        var week = TokenTotals.zero
        var previousWeek = TokenTotals.zero
        var allTime = TokenTotals.zero
        var seen = Set<String>()
        var latestRateTimestamp = Date.distantPast
        var latestFiveHour: RateWindow?
        var latestWeekly: RateWindow?
        var fileCount = 0
        var eventCount = 0
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for case let file as URL in enumerator {
            guard file.pathExtension.lowercased() == "jsonl",
                  let values = try? file.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            fileCount += 1

            let events = events(
                for: file,
                values: values,
                timestampFormatter: timestampFormatter
            )
            for event in events {
                guard seen.insert(event.identity).inserted else { continue }

                eventCount += 1
                allTime.add(event.tokens)
                if event.timestamp >= startOfWeek { week.add(event.tokens) }
                if event.timestamp >= startOfToday { today.add(event.tokens) }
                if event.timestamp >= startOfYesterday, event.timestamp < startOfToday {
                    yesterday.add(event.tokens)
                }
                if event.timestamp >= startOfPreviousWeek,
                   event.timestamp < previousWeekComparableEnd {
                    previousWeek.add(event.tokens)
                }

                if event.timestamp >= latestRateTimestamp,
                   event.fiveHour != nil || event.weekly != nil {
                    latestRateTimestamp = event.timestamp
                    if let fiveHour = event.fiveHour { latestFiveHour = fiveHour }
                    if let weekly = event.weekly { latestWeekly = weekly }
                }
            }
        }

        return UsageSnapshot(
            today: today,
            yesterday: yesterday,
            week: week,
            previousWeek: previousWeek,
            allTime: allTime,
            fiveHour: latestFiveHour,
            weekly: latestWeekly,
            filesScanned: fileCount,
            eventsCounted: eventCount,
            updatedAt: .now
        )
    }

    private func events(
        for file: URL,
        values: URLResourceValues,
        timestampFormatter: ISO8601DateFormatter
    ) -> [ParsedEvent] {
        cacheLock.lock()
        if let cached = cache[file],
           cached.modifiedAt == values.contentModificationDate,
           cached.size == values.fileSize {
            cacheLock.unlock()
            return cached.events
        }
        cacheLock.unlock()

        guard let contents = try? Data(contentsOf: file, options: .mappedIfSafe) else {
            return []
        }

        let tokenMarker = Data(#""type":"token_count""#.utf8)
        var parsed: [ParsedEvent] = []
        var searchStart = contents.startIndex

        while searchStart < contents.endIndex,
              let markerRange = contents.range(
                of: tokenMarker,
                options: [],
                in: searchStart..<contents.endIndex
              ) {
            let lineStart = contents[..<markerRange.lowerBound]
                .lastIndex(of: 0x0A)
                .map { contents.index(after: $0) } ?? contents.startIndex
            let lineEnd = contents[markerRange.upperBound...]
                .firstIndex(of: 0x0A) ?? contents.endIndex
            let line = Data(contents[lineStart..<lineEnd])
            searchStart = lineEnd < contents.endIndex
                ? contents.index(after: lineEnd)
                : contents.endIndex

            if let event = Self.parse(data: line, timestampFormatter: timestampFormatter) {
                parsed.append(event)
            }
        }

        cacheLock.lock()
        cache[file] = CachedFile(
            modifiedAt: values.contentModificationDate,
            size: values.fileSize,
            events: parsed
        )
        cacheLock.unlock()
        return parsed
    }

    private static func parse(
        data: Data,
        timestampFormatter: ISO8601DateFormatter
    ) -> ParsedEvent? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["type"] as? String == "event_msg",
              let payload = root["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let timestampText = root["timestamp"] as? String,
              let timestamp = timestampFormatter.date(from: timestampText),
              let info = payload["info"] as? [String: Any],
              let usage = info["last_token_usage"] as? [String: Any] else { return nil }

        let tokens = TokenTotals(
            input: integer(usage["input_tokens"]),
            cachedInput: integer(usage["cached_input_tokens"]),
            output: integer(usage["output_tokens"])
        )
        guard tokens.total > 0 else { return nil }

        var fiveHour: RateWindow?
        var weekly: RateWindow?
        if let limits = payload["rate_limits"] as? [String: Any] {
            for key in ["primary", "secondary"] {
                guard let raw = limits[key] as? [String: Any],
                      let window = parseRateWindow(raw) else { continue }
                if window.windowMinutes <= 300 {
                    fiveHour = window
                } else {
                    weekly = window
                }
            }
        }

        let identity = [
            timestampText,
            String(tokens.input),
            String(tokens.cachedInput),
            String(tokens.output)
        ].joined(separator: ":")

        return ParsedEvent(
            timestamp: timestamp,
            tokens: tokens,
            fiveHour: fiveHour,
            weekly: weekly,
            identity: identity
        )
    }

    private static func parseRateWindow(_ raw: [String: Any]) -> RateWindow? {
        guard let used = number(raw["used_percent"]),
              let minutes = raw["window_minutes"] as? Int ?? (raw["window_minutes"] as? NSNumber)?.intValue,
              let resetSeconds = raw["resets_at"] as? Int ?? (raw["resets_at"] as? NSNumber)?.intValue else {
            return nil
        }
        return RateWindow(
            usedPercent: used,
            windowMinutes: minutes,
            resetsAt: Date(timeIntervalSince1970: TimeInterval(resetSeconds))
        )
    }

    private static func integer(_ value: Any?) -> Int {
        (value as? Int) ?? (value as? NSNumber)?.intValue ?? 0
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? Double) ?? (value as? NSNumber)?.doubleValue
    }
}
