import Foundation

/// GitHub's default canvas and contribution palettes, verified against the
/// site's dark/light CSS on 2026-10-14 (contribution-default-bgColor-0...4).
public enum GitHubColors {
    public static let darkBackground: UInt32 = 0x0D1117
    public static let darkBorder: UInt32 = 0x30363D
    public static let darkText: UInt32 = 0x8B949E
    public static let darkSecondary: UInt32 = 0x6E7681
    public static let darkLevels: [UInt32] = [0x151B23, 0x033A16, 0x196C2E, 0x2EA043, 0x56D364]
    public static let lightBackground: UInt32 = 0xFFFFFF
    public static let lightBorder: UInt32 = 0xD0D7DE
    public static let lightText: UInt32 = 0x57606A
    public static let lightSecondary: UInt32 = 0x6E7781
    public static let lightLevels: [UInt32] = [0xEFF2F5, 0xACEEBB, 0x4AC26B, 0x2DA44E, 0x116329]
}
