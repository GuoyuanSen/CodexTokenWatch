import Foundation

enum AppSettings {
    static let appearanceKey = "appearanceMode"
    static let languageKey = "appLanguage"
    static let automaticRefreshKey = "automaticRefreshEnabled"
    static let resetReminderKey = "resetReminderEnabled"
    static let accountPlanKey = "accountPlanOverride"
}

enum AccountPlanMode: String, CaseIterable, Identifiable {
    case automatic
    case free
    case plus
    case pro

    var id: String { rawValue }

    func title(language: AppLanguage, detectedPlan: String? = nil) -> String {
        switch self {
        case .automatic:
            if let detectedPlan, !detectedPlan.isEmpty {
                return language.text(
                    "Automatic (\(detectedPlan.uppercased()))",
                    "自动（\(detectedPlan.uppercased())）"
                )
            }
            return language.text("Automatic", "自动")
        case .free: return "FREE"
        case .plus: return "PLUS"
        case .pro: return "PRO"
        }
    }

    func resolvedPlan(detectedPlan: String?) -> String? {
        switch self {
        case .automatic: detectedPlan?.uppercased()
        case .free: "FREE"
        case .plus: "PLUS"
        case .pro: "PRO"
        }
    }
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
