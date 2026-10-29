import AppKit
import Foundation

enum TerminalKind: String, CaseIterable, Identifiable {
    case terminal
    case ghostty

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal: return "Terminal"
        case .ghostty: return "Ghostty"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .ghostty: return "com.mitchellh.ghostty"
        }
    }

    var applicationURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    var isInstalled: Bool {
        applicationURL != nil
    }
}

enum TerminalPreferences {
    private static let key = "DevSessions.terminal"

    static var selected: TerminalKind {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: key),
                  let value = TerminalKind(rawValue: rawValue) else {
                return .terminal
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    static var installed: [TerminalKind] {
        TerminalKind.allCases.filter(\.isInstalled)
    }

    static var effective: TerminalKind {
        let selected = selected
        return selected.isInstalled ? selected : .terminal
    }
}
