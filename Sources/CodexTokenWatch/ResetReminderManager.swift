import Foundation
import UserNotifications

enum ResetReminderManager {
    private static let identifier = "weekly-allowance-reset"

    static func schedule(
        resetAt: Date,
        language: AppLanguage,
        completion: @escaping @Sendable (Bool, String?) -> Void
    ) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                completion(
                    false,
                    error?.localizedDescription
                        ?? language.text(
                            "Notification permission was not granted.",
                            "未获得通知权限。"
                        )
                )
                return
            }

            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            let reminderDate = resetAt.addingTimeInterval(-10 * 60)
            guard reminderDate > .now else {
                completion(
                    false,
                    language.text(
                        "The next reset is less than 10 minutes away.",
                        "距离下次重置不足 10 分钟。"
                    )
                )
                return
            }

            let content = UNMutableNotificationContent()
            content.title = language.text(
                "Codex allowance resets soon",
                "Codex 额度即将重置"
            )
            content.body = language.text(
                "Your weekly allowance is scheduled to reset in 10 minutes.",
                "你的每周额度预计将在 10 分钟后重置。"
            )
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: reminderDate
            )
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: false
                )
            )
            center.add(request) { addError in
                completion(addError == nil, addError?.localizedDescription)
            }
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
