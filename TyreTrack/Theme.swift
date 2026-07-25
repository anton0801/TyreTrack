//
//  Theme.swift
//  TyreTrack
//
//  DESIGN SYSTEM — "workshop instrument" .
//
//  Palette family (owner-fixed): graphite + amber + steel blue.
//  Everything else carries this app's divergence:
//
//  · Typography  — SF Compressed Black display, condensed heavy titles,
//                  wide-tracked uppercase labels, SF Mono for every
//                  measurement. No .rounded anywhere in the app.
//  · Shape       — tool-panel geometry: 12pt outer panels, 4pt inset
//                  readout wells (concentric: 12 − 8pt inset = 4),
//                  6pt chips. Capsules are reserved for status pills.
//  · Texture     — the machinist tick rule: a hairline with minor/major
//                  ticks, repeated as section divider, gauge scale and
//                  progress rail.
//  · Elevation   — ONE strategy: hairlines + tonal fills. Zero shadows.
//                  A single soft glow exists and is spent only on the
//                  one live status readout on screen.
//  · Motion      — spring(response: 0.36, dampingFraction: 0.86):
//                  mechanical, precise, settles without wobble.
//

import SwiftUI

// MARK: - Color hex helpers

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(UIColor(hex: hex, alpha: CGFloat(alpha)))
    }

    /// Adaptive color that flips with the active color scheme.
    static func adaptive(dark: UInt, light: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

// MARK: - Semantic tokens

/// `TT` = Tyre Track theme namespace. Screens never name a raw colour.
enum TT {

    // Surfaces — graphite bench, deeper wells, raised panels.
    static let surface       = Color.adaptive(dark: 0x16181C, light: 0xEDEBE4)
    static let surfaceSunken = Color.adaptive(dark: 0x0C0E11, light: 0xDEDBD2)
    static let surfaceRaised = Color.adaptive(dark: 0x1D2026, light: 0xF9F7F1)
    static let surfaceCard   = Color.adaptive(dark: 0x23272E, light: 0xFFFFFF)

    // Hairlines — the only elevation device in the app.
    static let hairline      = Color.adaptive(dark: 0x353B45, light: 0xD4D0C6)
    static let hairlineSoft  = Color.adaptive(dark: 0x272C33, light: 0xE4E0D6)

    // Brand — constant across modes so identity never shifts.
    static let accent        = Color(hex: 0xE9A231)   // amber — tread
    static let accentDeep    = Color(hex: 0xC8821B)
    static let accentMuted   = Color(hex: 0xE9A231, alpha: 0.16)
    static let steelBlue     = Color(hex: 0x6B87AC)   // steel — pressure
    static let steelLight    = Color(hex: 0x9AB2CD)
    static let steelMuted    = Color(hex: 0x6B87AC, alpha: 0.16)

    // Status
    static let critical      = Color(hex: 0xDE5049)   // below the limit
    static let positive      = Color(hex: 0x4CAE74)
    static let caution       = Color(hex: 0xE0AE3A)

    // Text
    static let textPrimary   = Color.adaptive(dark: 0xF3EFE6, light: 0x191C21)
    static let textSecondary = Color.adaptive(dark: 0xC5CBD3, light: 0x3B4048)
    static let textTertiary  = Color.adaptive(dark: 0x8A9099, light: 0x6C7178)
    static let textDisabled  = Color.adaptive(dark: 0x5A606A, light: 0xA7ABB2)

    // Ink on filled brand surfaces
    static let onAccent      = Color(hex: 0x1A1104)
    static let onSteel       = Color(hex: 0x081220)

    /// The single permitted glow — spent only on the one live status
    /// readout on screen (see `ttLiveGlow`).
    static let liveGlow      = Color(hex: 0xE9A231, alpha: 0.28)
}

// MARK: - Shape language (tool panel)

enum TTShape {
    /// Outer panel / card.
    static let panel: CGFloat = 12
    /// Inset readout well — concentric with `panel` at an 8pt inset.
    static let well: CGFloat = 4
    /// Chips and small controls.
    static let chip: CGFloat = 6
    /// Standard inset between a panel edge and an inner well.
    static let inset: CGFloat = 8

    static func panelShape(_ radius: CGFloat = panel) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

// MARK: - Motion personality

enum TTMotion {
    /// The app spring. Mechanical, precise, settles without overshoot chatter.
    static let spring   = Animation.spring(response: 0.36, dampingFraction: 0.86)
    /// Snappier variant for small state flips (chips, toggles).
    static let snap     = Animation.spring(response: 0.24, dampingFraction: 0.9)
    /// Press feedback — 140ms, inside the 100–160ms band.
    static let press    = Animation.spring(response: 0.14, dampingFraction: 0.9)
    /// Sheets / screen-level moves.
    static let panel    = Animation.spring(response: 0.44, dampingFraction: 0.88)
    /// Numeric readouts counting to a new value.
    static let readout  = Animation.easeOut(duration: 0.22)

    /// List/grid entrance stagger — 40ms per item, capped at 8 items.
    static func stagger(_ index: Int) -> Double { Double(min(index, 7)) * 0.04 }
}

// MARK: - Haptics map
//
// light   — selection (chips, tabs, wheel picks)
// medium  — commit (log a reading, save a record)
// success — a set crosses back above the legal limit / signoff pass
// warning — a reading lands in the caution band
// error   — a reading is at or below the legal minimum

enum TTHaptics {
    static func select() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func commit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Typography
//
// Scalable throughout: every face is built from a Dynamic Type text style,
// so the whole app tracks the user's size setting up to the accessibility
// sizes. Nothing returns a fixed point size.

extension Font {

    /// Screen titles — SF Compressed Black. The app's loudest voice.
    static func ttDisplay(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .default, weight: .black).width(.compressed)
    }

    /// Section and card titles — condensed heavy.
    static func ttTitle(_ style: Font.TextStyle = .title3) -> Font {
        .system(style, design: .default, weight: .heavy).width(.condensed)
    }

    /// Emphasis inside body copy.
    static func ttHeadline(_ style: Font.TextStyle = .headline) -> Font {
        .system(style, design: .default, weight: .semibold)
    }

    static func ttBody(_ style: Font.TextStyle = .subheadline) -> Font {
        .system(style, design: .default, weight: .regular)
    }

    static func ttCaption(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .default, weight: .regular)
    }

    /// Wide-tracked uppercase field/rail labels. Always paired with
    /// `.kerning` via `TTLabel`.
    static func ttLabel(_ style: Font.TextStyle = .caption2) -> Font {
        .system(style, design: .default, weight: .semibold)
    }

    /// EVERY measurement in the app — mm, psi, bar, %, miles, DOT ages.
    /// SF Mono with tabular figures so digits never jitter as they count.
    static func ttReadout(_ style: Font.TextStyle = .title3,
                          weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .monospaced, weight: weight).monospacedDigit()
    }
}

// MARK: - Texture — the machinist tick rule
//
// One repeated tyre-shop detail, used app-wide: under section heads, along
// gauge edges, and as the onboarding progress rail.

struct TickRuleShape: Shape {
    var spacing: CGFloat = 6
    var majorEvery: Int = 5
    var minorLength: CGFloat = 3
    var majorLength: CGFloat = 7
    /// Ticks hang below the rule when true, above when false.
    var descending: Bool = true

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let baseline: CGFloat = descending ? 0 : rect.height
        p.move(to: CGPoint(x: 0, y: baseline))
        p.addLine(to: CGPoint(x: rect.width, y: baseline))

        var x: CGFloat = 0
        var i = 0
        while x <= rect.width {
            let len = (i % majorEvery == 0) ? majorLength : minorLength
            p.move(to: CGPoint(x: x, y: baseline))
            p.addLine(to: CGPoint(x: x, y: descending ? len : baseline - len))
            x += spacing
            i += 1
        }
        return p
    }
}

/// Section divider drawn as a machinist rule.
struct TickRule: View {
    var tint: Color = TT.hairline
    var spacing: CGFloat = 6
    var height: CGFloat = 7

    var body: some View {
        TickRuleShape(spacing: spacing, majorLength: height)
            .stroke(tint, lineWidth: 1)
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

/// Vertical tick scale used along the edge of a gauge.
struct GaugeScaleShape: Shape {
    var divisions: Int = 8
    var majorEvery: Int = 2
    var minorLength: CGFloat = 4
    var majorLength: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard divisions > 0 else { return p }
        let step = rect.height / CGFloat(divisions)
        for i in 0...divisions {
            let y = rect.height - CGFloat(i) * step
            let len = (i % majorEvery == 0) ? majorLength : minorLength
            p.move(to: CGPoint(x: rect.width, y: y))
            p.addLine(to: CGPoint(x: rect.width - len, y: y))
        }
        return p
    }
}

// MARK: - Surface helpers

extension View {

    /// The app's one elevation device: tonal fill + hairline. No shadows.
    func ttPanel(padding: CGFloat = 14, radius: CGFloat = TTShape.panel) -> some View {
        self
            .padding(padding)
            .background(TTShape.panelShape(radius).fill(TT.surfaceCard))
            .overlay(TTShape.panelShape(radius).stroke(TT.hairline, lineWidth: 1))
    }

    /// Inset readout well — concentric 4pt inside a 12pt panel.
    func ttWell(padding: CGFloat = 10) -> some View {
        self
            .padding(padding)
            .background(TTShape.panelShape(TTShape.well).fill(TT.surfaceSunken))
            .overlay(TTShape.panelShape(TTShape.well).stroke(TT.hairlineSoft, lineWidth: 1))
    }

    /// The single glow in the design system. Reserve it for the one live
    /// status element on screen — never decoration.
    func ttLiveGlow(_ active: Bool = true) -> some View {
        self.shadow(color: active ? TT.liveGlow : .clear, radius: active ? 10 : 0)
    }

    /// Entrance stagger for lists and grids. Never blocks interaction.
    func ttStagger(_ index: Int, appeared: Bool, reduceMotion: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: (appeared || reduceMotion) ? 0 : 8)
            .animation(reduceMotion
                       ? .easeOut(duration: 0.2)
                       : TTMotion.spring.delay(TTMotion.stagger(index)),
                       value: appeared)
    }
}
