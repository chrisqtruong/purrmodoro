import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

enum Theme {
    // Day is warm cream; night is a cozy navy.
    // Night colors are kept low-glare: deep navy, soft off-white text, muted accents.
    static let background = Color.dynamic(light: 0xFFF6EA, dark: 0x17162A)
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x252338)
    static let track = Color.dynamic(light: 0xF2E3D0, dark: 0x2F2C45)
    static let ink = Color.dynamic(light: 0x4A3222, dark: 0xE6DDD1)
    static let inkSoft = Color.dynamic(light: 0x8C6E58, dark: 0x9A93AE)

    static let caramel = Color.dynamic(light: 0xC68B59, dark: 0xA8754B)
    static let sage = Color.dynamic(light: 0x7FB58A, dark: 0x66977A)
    static let blush = Color(hex: 0xF4A6A0)

    // Kitty
    static let fur = Color(hex: 0x9A6A44)
    static let furLight = Color(hex: 0xC4966C)
    static let furDark = Color(hex: 0x3A2418)
    static let eyeWhite = Color(hex: 0xFFFBF2)
    static let book = Color(hex: 0xE58C7A)
    static let page = Color(hex: 0xFFFDF6)

    // Day outfit: white coat over scrubs
    static let coat = Color(hex: 0xFBFBF8)
    static let coatShade = Color(hex: 0xD9DDE3)
    static let scrubs = Color(hex: 0x7FB2D6)
    static let hopkinsBlue = Color(hex: 0x1F3F8A)
    static let stethoscope = Color(hex: 0x55606C)
    static let silver = Color(hex: 0xC9CED6)
    static let highlighter = Color(hex: 0xF7DC4A)
    static let pen = Color(hex: 0x3D6FD1)

    // Night outfit: pajamas
    static let pajamas = Color(hex: 0x7C83B5)
    static let pajamaTrim = Color(hex: 0xD9DCF0)
    static let glasses = Color(hex: 0x4A3226)
    static let nightShade = Color(hex: 0x14122B)

    // Desk scene
    static let wallDay = Color(hex: 0xF7E7D2)
    static let wallNight = Color(hex: 0x2B2745)
    static let deskTopDay = Color(hex: 0xE4B684)
    static let deskFrontDay = Color(hex: 0xCB925D)
    static let deskTopNight = Color(hex: 0x7A553B)
    static let deskFrontNight = Color(hex: 0x5A3D2B)
    static let windowFrameDay = Color.white
    static let windowFrameNight = Color(hex: 0x4B4368)
    static let skyDay = Color(hex: 0xBFE4F6)
    static let skyNight = Color(hex: 0x1F2350)
    static let skyGolden = Color(hex: 0xF8B98A)
    static let skyTwilight = Color(hex: 0x7A5C9E)
    static let sunLow = Color(hex: 0xF5875A)
    static let sun = Color(hex: 0xFFD66B)
    static let moon = Color(hex: 0xFFF1C1)
    static let lampShade = Color(hex: 0xE8A94A)
    static let lampMetal = Color(hex: 0x3E3A48)
    static let glow = Color(hex: 0xFFD27A)
    static let coffee = Color(hex: 0x8B5A3C)
    static let coffeeMilk = Color(hex: 0xC99D6E)
    static let mug = Color(hex: 0x9CC8A6)
    static let pot = Color(hex: 0xD98E6B)
    static let leaf = Color(hex: 0x8CC084)

    static func accent(for phase: Phase) -> Color { phase == .focus ? caramel : sage }

    /// Heatmap shades, from "no focus" to "lots of focus".
    static let heat: [Color] = [
        Color.dynamic(light: 0xF8F2EA, dark: 0x2F2C45),  // no focus: pale and neutral, clearly different from a little focus
        Color(hex: 0xF3D9B8),
        Color(hex: 0xE3B383),
        Color(hex: 0xC68B59),
        Color(hex: 0x8E5A33),
    ]
}

extension Font {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}
