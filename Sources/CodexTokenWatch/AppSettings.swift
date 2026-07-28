import Foundation

enum AppSettings {
    static let appearanceKey = "appearanceMode"
    static let languageKey = "appLanguage"
    static let automaticRefreshKey = "automaticRefreshEnabled"
    static let resetReminderKey = "resetReminderEnabled"
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case chinese

    var id: String { rawValue }

    static var current: AppLanguage {
        AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: AppSettings.languageKey) ?? ""
        ) ?? .english
    }

    var title: String {
        switch self {
        case .english: "English"
        case .chinese: "中文"
        }
    }

    func text(_ english: String, _ chinese: String) -> String {
        self == .chinese ? chinese : english
    }
}
