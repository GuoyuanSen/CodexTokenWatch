import Foundation

struct AccountInfo: Sendable, Equatable {
    let name: String
    let email: String
    let plan: String?

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let result = parts.compactMap(\.first).map(String.init).joined()
        return result.isEmpty ? "C" : result.uppercased()
    }
}

enum AccountInfoLoader {
    static func load() -> AccountInfo? {
        let authURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".codex/auth.json")
        guard let data = try? Data(contentsOf: authURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let idToken = tokens["id_token"] as? String,
              let payload = decodeJWTPayload(idToken) else {
            return nil
        }

        let email = payload["email"] as? String ?? ""
        let name = payload["name"] as? String
            ?? email.split(separator: "@").first.map(String.init)
            ?? "Codex"
        let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        let plan = auth?["chatgpt_plan_type"] as? String

        guard !name.isEmpty || !email.isEmpty else { return nil }
        return AccountInfo(name: name, email: email, plan: plan)
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var encoded = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while encoded.count.isMultiple(of: 4) == false {
            encoded.append("=")
        }

        guard let data = Data(base64Encoded: encoded),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return payload
    }
}
