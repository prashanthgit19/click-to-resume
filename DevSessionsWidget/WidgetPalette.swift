import AppKit
import DevSessionsCore
import SwiftUI
import WidgetKit

struct WidgetPalette {
    let background: [Color]
    let glow: Color
    let glowSecondary: Color
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let separator: Color
    let ringTrack: Color
    let brandStart: Color
    let brandEnd: Color
    let brandDot: Color
    let chartStart: Color
    let chartEnd: Color
    let arrowBackground: Color
    let agentAccents: [AgentKind: Color]
    let isTransparent: Bool

    func accent(for agent: AgentKind) -> Color {
        agentAccents[agent] ?? primary
    }
}

extension WidgetPalette {
    static func resolve(
        theme: WidgetTheme,
        colorScheme: ColorScheme,
        renderingMode: WidgetRenderingMode
    ) -> WidgetPalette {
        if renderingMode == .accented || renderingMode == .vibrant {
            return accented
        }

        switch theme {
        case .system:
            return system
        case .midnight:
            return midnight
        case .paper:
            return paper
        case .graphite:
            return graphite
        case .coast:
            return coast
        }
    }

    private static let accented = WidgetPalette(
        background: [.clear, .clear],
        glow: .clear,
        glowSecondary: .clear,
        primary: .white,
        secondary: .white.opacity(0.68),
        tertiary: .white.opacity(0.48),
        separator: .white.opacity(0.16),
        ringTrack: .white.opacity(0.18),
        brandStart: .white,
        brandEnd: .white.opacity(0.55),
        brandDot: .white,
        chartStart: .white.opacity(0.9),
        chartEnd: .white.opacity(0.45),
        arrowBackground: .white.opacity(0.14),
        agentAccents: Dictionary(
            uniqueKeysWithValues: AgentKind.allCases.map {
                ($0, Color.white.opacity(0.9))
            }
        ),
        isTransparent: true
    )

    private static var system: WidgetPalette {
        WidgetPalette(
            background: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor)
            ],
            glow: .clear,
            glowSecondary: .clear,
            primary: Color(nsColor: .labelColor),
            secondary: Color(nsColor: .secondaryLabelColor),
            tertiary: Color(nsColor: .tertiaryLabelColor),
            separator: Color(nsColor: .separatorColor),
            ringTrack: Color(nsColor: .separatorColor).opacity(0.7),
            brandStart: Color.accentColor,
            brandEnd: Color.accentColor.opacity(0.55),
            brandDot: Color.orange,
            chartStart: Color.accentColor,
            chartEnd: Color.accentColor.opacity(0.45),
            arrowBackground: Color.primary.opacity(0.06),
            agentAccents: [
                .opencode: .indigo,
                .claude: .orange,
                .codex: .teal,
                .pi: .brown,
                .omp: .pink
            ],
            isTransparent: false
        )
    }

    private static let midnight = WidgetPalette(
        background: [Color(hex: 0x1A1128), Color(hex: 0x28163A)],
        glow: Color(hex: 0x8B5CF6),
        glowSecondary: Color(hex: 0xE879B9),
        primary: Color(hex: 0xF7F3FC),
        secondary: Color(hex: 0xC2B7D0),
        tertiary: Color(hex: 0x9E92AD),
        separator: Color.white.opacity(0.08),
        ringTrack: Color.white.opacity(0.10),
        brandStart: Color(hex: 0x9B8CFF),
        brandEnd: Color(hex: 0xF3A6C8),
        brandDot: Color(hex: 0xFFC29B),
        chartStart: Color(hex: 0x9B8CFF),
        chartEnd: Color(hex: 0xF3A6C8),
        arrowBackground: Color.white.opacity(0.09),
        agentAccents: [
            .opencode: Color(hex: 0xB4A7FF),
            .claude: Color(hex: 0xFFC29B),
            .codex: Color(hex: 0x8BE8D6),
            .pi: Color(hex: 0xFFE08A),
            .omp: Color(hex: 0xF5A8C8)
        ],
        isTransparent: false
    )

    private static let paper = WidgetPalette(
        background: [Color(hex: 0xF7F2E8), Color(hex: 0xEFE7DA)],
        glow: Color(hex: 0xD8B98C),
        glowSecondary: .clear,
        primary: Color(hex: 0x2B2520),
        secondary: Color(hex: 0x5F544B),
        tertiary: Color(hex: 0x7A6C60),
        separator: Color.black.opacity(0.08),
        ringTrack: Color.black.opacity(0.12),
        brandStart: Color(hex: 0x7C5CE0),
        brandEnd: Color(hex: 0xD15C8A),
        brandDot: Color(hex: 0xD97745),
        chartStart: Color(hex: 0x7C5CE0),
        chartEnd: Color(hex: 0xD15C8A),
        arrowBackground: Color.black.opacity(0.05),
        agentAccents: [
            .opencode: Color(hex: 0x4F3FC4),
            .claude: Color(hex: 0x9A3F00),
            .codex: Color(hex: 0x0B635C),
            .pi: Color(hex: 0x6F5500),
            .omp: Color(hex: 0x8E2F58)
        ],
        isTransparent: false
    )

    private static let graphite = WidgetPalette(
        background: [Color(hex: 0x1C1C1E), Color(hex: 0x2C2C2E)],
        glow: .clear,
        glowSecondary: .clear,
        primary: Color(hex: 0xF5F5F7),
        secondary: Color(hex: 0xC7C7CC),
        tertiary: Color(hex: 0x8E8E93),
        separator: Color.white.opacity(0.10),
        ringTrack: Color.white.opacity(0.12),
        brandStart: Color(hex: 0x8E8E93),
        brandEnd: Color(hex: 0xF5F5F7),
        brandDot: Color(hex: 0xFFC29B),
        chartStart: Color(hex: 0x8E8E93),
        chartEnd: Color(hex: 0xF5F5F7),
        arrowBackground: Color.white.opacity(0.08),
        agentAccents: [
            .opencode: Color(hex: 0xFFC29B),
            .claude: Color(hex: 0xFFC29B),
            .codex: Color(hex: 0xFFC29B),
            .pi: Color(hex: 0xFFC29B),
            .omp: Color(hex: 0xFFC29B)
        ],
        isTransparent: false
    )

    private static let coast = WidgetPalette(
        background: [Color(hex: 0x0B1F2A), Color(hex: 0x123847)],
        glow: Color(hex: 0x2BB3C0),
        glowSecondary: Color(hex: 0x2D5BFF),
        primary: Color(hex: 0xF2FAFC),
        secondary: Color(hex: 0xB7D1D9),
        tertiary: Color(hex: 0x86A6B0),
        separator: Color.white.opacity(0.10),
        ringTrack: Color.white.opacity(0.12),
        brandStart: Color(hex: 0x57C7D4),
        brandEnd: Color(hex: 0x7FA8FF),
        brandDot: Color(hex: 0xFFC29B),
        chartStart: Color(hex: 0x57C7D4),
        chartEnd: Color(hex: 0x7FA8FF),
        arrowBackground: Color.white.opacity(0.08),
        agentAccents: [
            .opencode: Color(hex: 0x7CC7FF),
            .claude: Color(hex: 0xFFC29B),
            .codex: Color(hex: 0x7FE0C3),
            .pi: Color(hex: 0xFFE08A),
            .omp: Color(hex: 0xF5A8C8)
        ],
        isTransparent: false
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
