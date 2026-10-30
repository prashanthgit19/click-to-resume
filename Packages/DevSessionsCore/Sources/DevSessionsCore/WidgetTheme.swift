import Foundation

/// The palette shown by the widget in Full Color mode. Clear and Tinted
/// appearances are chosen in System Settings and are handled by the system.
public enum WidgetTheme: String, CaseIterable, Codable, Sendable {
    case system
    case midnight
    case paper
    case graphite
    case coast

    public var displayName: String {
        switch self {
        case .system: return "Match System"
        case .midnight: return "Midnight"
        case .paper: return "Paper"
        case .graphite: return "Graphite"
        case .coast: return "Coast"
        }
    }

    public var summary: String {
        switch self {
        case .system:
            return "Follows your Mac’s light or dark appearance."
        case .midnight:
            return "Deep plum with violet and rose rings."
        case .paper:
            return "Warm paper with ink-dark text."
        case .graphite:
            return "Quiet monochrome with a warm accent."
        case .coast:
            return "Cool teal with bright rings."
        }
    }

    public var swatch: WidgetThemeSwatch {
        switch self {
        case .system:
            return WidgetThemeSwatch(
                top: 0xF2F2F7,
                bottom: 0x1C1C1E,
                accent: 0x8E8E93,
                secondary: 0xC7C7CC
            )
        case .midnight:
            return WidgetThemeSwatch(
                top: 0x1A1128,
                bottom: 0x28163A,
                accent: 0xB4A7FF,
                secondary: 0xC2B7D0
            )
        case .paper:
            return WidgetThemeSwatch(
                top: 0xF7F2E8,
                bottom: 0xEFE7DA,
                accent: 0x5B4BD6,
                secondary: 0x5F544B
            )
        case .graphite:
            return WidgetThemeSwatch(
                top: 0x1C1C1E,
                bottom: 0x2C2C2E,
                accent: 0xFFC29B,
                secondary: 0xC7C7CC
            )
        case .coast:
            return WidgetThemeSwatch(
                top: 0x0B1F2A,
                bottom: 0x123847,
                accent: 0x7CC7FF,
                secondary: 0xB7D1D9
            )
        }
    }
}

public struct WidgetThemeSwatch: Sendable {
    public let top: UInt32
    public let bottom: UInt32
    public let accent: UInt32
    public let secondary: UInt32

    public init(top: UInt32, bottom: UInt32, accent: UInt32, secondary: UInt32) {
        self.top = top
        self.bottom = bottom
        self.accent = accent
        self.secondary = secondary
    }
}
