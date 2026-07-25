//
//  Components.swift
//  TyreTrack
//
//  The bespoke component library. Nothing here is a restyled Apple
//  default: every control is drawn from the tool-panel shape language
//  (12pt panels, 4pt inset wells, 6pt chips), hairline elevation and
//  the machinist tick rule.
//
//  1  TTLabel        — wide-tracked uppercase rail label
//  2  SectionHead    — label + tick rule
//  3  TTPressStyle   — press scale used by every tappable element
//  4  ToolPanel      — the card
//  5  ReadoutWell    — the signature inset measurement well
//  6  StatTile       — mono figure + tracked caption
//  7  TTTextField    — inset well input
//  8  TTNumberField  — mono numeric input with unit
//  9  SelectorRail   — machined segmented control with sliding indicator
//  10 SelectChip     — 6pt chip (+ WrapChips flow layout)
//  11 StatusPill     — the only capsule in the app
//  12 NavRow         — drill-down row with tick-rule leading edge
//  13 TTToggleRow    — switch row
//  14 TTSliderRow    — slider with a tick scale
//  15 TTEmptyState   — designed empty composition
//  16 TTToast        — transient confirmation
//

import SwiftUI

// MARK: - 1 · Rail label

struct TTLabel: View {
    let text: String
    var tint: Color = TT.textTertiary
    var body: some View {
        Text(text.uppercased())
            .font(.ttLabel())
            .kerning(1.4)
            .foregroundColor(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 2 · Section head

struct SectionHead: View {
    let title: String
    var subtitle: String? = nil
    var accent: Color = TT.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Rectangle().fill(accent).frame(width: 3, height: 13)
                Text(title.uppercased())
                    .font(.ttLabel(.caption))
                    .kerning(1.6)
                    .foregroundColor(TT.textPrimary)
                Spacer(minLength: 0)
            }
            TickRule(tint: accent.opacity(0.45))
            if let s = subtitle {
                Text(s)
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 3 · Press style

/// Deliberate press, snappy release — applied to every tappable element.
struct TTPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(TTMotion.press, value: configuration.isPressed)
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { TTHaptics.commit(); action() }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(.footnote, design: .default, weight: .bold))
                }
                Text(title.uppercased())
                    .font(.ttLabel(.footnote))
                    .kerning(1.2)
            }
            .foregroundColor(TT.onAccent)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(TTShape.panelShape().fill(TT.accent))
            .overlay(TTShape.panelShape().stroke(TT.accentDeep, lineWidth: 1))
        }
        .buttonStyle(TTPressStyle())
    }
}

struct SteelButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { TTHaptics.commit(); action() }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(.footnote, design: .default, weight: .bold))
                }
                Text(title.uppercased()).font(.ttLabel(.footnote)).kerning(1.2)
            }
            .foregroundColor(TT.onSteel)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 14).padding(.horizontal, 20)
            .background(TTShape.panelShape().fill(TT.steelBlue))
        }
        .buttonStyle(TTPressStyle())
    }
}

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = TT.steelLight
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { TTHaptics.select(); action() }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(.caption, design: .default, weight: .bold))
                }
                Text(title.uppercased()).font(.ttLabel(.caption)).kerning(1.2)
            }
            .foregroundColor(tint)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 13).padding(.horizontal, 16)
            .background(TTShape.panelShape().fill(TT.surfaceRaised))
            .overlay(TTShape.panelShape().stroke(TT.hairline, lineWidth: 1))
        }
        .buttonStyle(TTPressStyle())
    }
}

struct DangerButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: { TTHaptics.notify(.warning); action() }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(.caption, design: .default, weight: .bold))
                }
                Text(title.uppercased()).font(.ttLabel(.caption)).kerning(1.2)
            }
            .foregroundColor(TT.critical)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(TTShape.panelShape().fill(TT.critical.opacity(0.12)))
            .overlay(TTShape.panelShape().stroke(TT.critical.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(TTPressStyle())
    }
}

// MARK: - 4 · Tool panel (card)

struct ToolPanel<Content: View>: View {
    var padding: CGFloat = 14
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ttPanel(padding: padding)
    }
}

// MARK: - 5 · Readout well (signature component)

/// An inset measurement well: mono figure, unit, tracked caption and an
/// optional tick scale down the trailing edge. Every number the app
/// reports lands in one of these.
struct ReadoutWell: View {
    let caption: String
    let value: String
    var unit: String? = nil
    var tint: Color = TT.accent
    var style: Font.TextStyle = .title2
    /// Set on the single live status readout of a screen.
    var live: Bool = false
    var showScale: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TTLabel(text: caption)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.ttReadout(style, weight: .bold))
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit = unit {
                    Text(unit)
                        .font(.ttReadout(.caption, weight: .medium))
                        .foregroundColor(TT.textTertiary)
                }
                Spacer(minLength: 0)
                if showScale {
                    GaugeScaleShape(divisions: 6, majorEvery: 3)
                        .stroke(TT.hairline, lineWidth: 1)
                        .frame(width: 9, height: 22)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ttWell()
        .ttLiveGlow(live)
    }
}

// MARK: - 6 · Stat tile

struct StatTile: View {
    let label: String
    let value: String
    var tint: Color = TT.accent
    /// Values that are measurements get mono; words get the condensed face.
    var numeric: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(numeric ? .ttReadout(.title2, weight: .bold) : .ttTitle(.title3))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            TickRule(tint: TT.hairlineSoft, spacing: 5, height: 5)
            TTLabel(text: label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12).padding(.horizontal, 12)
        .background(TTShape.panelShape().fill(TT.surfaceRaised))
        .overlay(TTShape.panelShape().stroke(TT.hairline, lineWidth: 1))
    }
}

// MARK: - 7 · Text field

struct TTTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TTLabel(text: title)
            TextField(placeholder, text: $text)
                .font(.ttBody())
                .foregroundColor(TT.textPrimary)
                .padding(.vertical, 11).padding(.horizontal, 12)
                .background(TTShape.panelShape(TTShape.well).fill(TT.surfaceSunken))
                .overlay(TTShape.panelShape(TTShape.well).stroke(TT.hairline, lineWidth: 1))
        }
    }
}

// MARK: - 8 · Numeric field

struct TTNumberField: View {
    let title: String
    @Binding var value: Double
    var unit: String = ""
    var decimals: Int = 1
    @State private var proxy: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TTLabel(text: title)
            HStack(spacing: 8) {
                TextField("0", text: $proxy)
                    .keyboardType(.decimalPad)
                    .font(.ttReadout(.body, weight: .semibold))
                    .foregroundColor(TT.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.ttReadout(.caption, weight: .medium))
                        .foregroundColor(TT.textTertiary)
                }
            }
            .padding(.vertical, 11).padding(.horizontal, 12)
            .background(TTShape.panelShape(TTShape.well).fill(TT.surfaceSunken))
            .overlay(TTShape.panelShape(TTShape.well).stroke(TT.hairline, lineWidth: 1))
        }
        .onAppear { proxy = trimmed(value) }
        .onChange(of: proxy) { newVal in
            let cleaned = newVal.replacingOccurrences(of: ",", with: ".")
            if let d = Double(cleaned) { value = d }
            else if cleaned.isEmpty { value = 0 }
        }
        // Re-sync when the bound value changes from outside. Guarded so it
        // never interrupts live typing.
        .onChange(of: value) { newVal in
            let current = Double(proxy.replacingOccurrences(of: ",", with: ".")) ?? 0
            if abs(current - newVal) > 0.0001 { proxy = trimmed(newVal) }
        }
    }

    private func trimmed(_ v: Double) -> String {
        if v == 0 { return "" }
        return String(format: "%.\(decimals)f", v)
    }
}

// MARK: - 9 · Selector rail

/// A machined segmented control: options sit in a sunken rail, the
/// selection is a milled block that slides between them.
struct SelectorRail<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    var tint: Color = TT.accent
    var label: (Item) -> String
    var icon: (Item) -> String? = { _ in nil }

    @Namespace private var rail

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let selected = item == selection
                Button {
                    TTHaptics.select()
                    withAnimation(TTMotion.snap) { selection = item }
                } label: {
                    HStack(spacing: 5) {
                        if let name = icon(item) {
                            Image(systemName: name)
                                .font(.system(.caption2, design: .default, weight: .bold))
                        }
                        Text(label(item).uppercased())
                            .font(.ttLabel(.caption2))
                            .kerning(1.1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundColor(selected ? TT.onAccent : TT.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        ZStack {
                            if selected {
                                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                                    .fill(tint)
                                    .matchedGeometryEffect(id: "railBlock", in: rail)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(TTPressStyle(scale: 0.98))
            }
        }
        .padding(3)
        .background(TTShape.panelShape(TTShape.chip).fill(TT.surfaceSunken))
        .overlay(TTShape.panelShape(TTShape.chip).stroke(TT.hairline, lineWidth: 1))
    }
}

// MARK: - 10 · Chip + flow layout

struct SelectChip: View {
    let title: String
    var icon: String? = nil
    let selected: Bool
    var tint: Color = TT.accent
    let action: () -> Void

    var body: some View {
        Button(action: { TTHaptics.select(); action() }) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(.caption2, design: .default, weight: .bold))
                }
                Text(title.uppercased()).font(.ttLabel(.caption2)).kerning(1.1)
            }
            .foregroundColor(selected ? TT.onAccent : TT.textSecondary)
            .padding(.vertical, 8).padding(.horizontal, 11)
            .background(
                RoundedRectangle(cornerRadius: TTShape.chip, style: .continuous)
                    .fill(selected ? tint : TT.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TTShape.chip, style: .continuous)
                    .stroke(selected ? tint : TT.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(TTPressStyle())
    }
}

/// Hand-rolled flow layout so chips wrap at any Dynamic Type size.
struct WrapChips<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    var spacing: CGFloat = 8
    let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            self.generate(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generate(in geo: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        let maxWidth = geo.size.width
        let items = Array(data)
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > maxWidth {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last { width = 0 } else { width -= d.width }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last { height = 0 }
                        return result
                    }
            }
        }
        .background(heightReader($totalHeight))
    }

    private func heightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo -> Color in
            let h = geo.frame(in: .local).size.height
            DispatchQueue.main.async { binding.wrappedValue = h }
            return Color.clear
        }
    }
}

// MARK: - 11 · Status pill (the only capsule)

struct StatusPill: View {
    let text: String
    let tint: Color
    /// The one live pill on a screen may carry the glow.
    var live: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(tint).frame(width: 5, height: 5)
            Text(text.uppercased())
                .font(.ttLabel(.caption2))
                .kerning(1.1)
                .foregroundColor(tint)
                .lineLimit(1)
        }
        .padding(.vertical, 5).padding(.horizontal, 10)
        .background(Capsule().fill(tint.opacity(0.13)))
        .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
        .ttLiveGlow(live)
    }
}

// MARK: - 12 · Navigation row

struct NavRow: View {
    let title: String
    let icon: String
    var tint: Color = TT.steelLight

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(.footnote, design: .default, weight: .bold))
                    .foregroundColor(tint)
            }
            Text(title.uppercased())
                .font(.ttLabel(.footnote))
                .kerning(1.2)
                .foregroundColor(TT.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(.caption2, design: .default, weight: .bold))
                .foregroundColor(TT.textTertiary)
        }
        .padding(.vertical, 12).padding(.horizontal, 12)
        .background(TTShape.panelShape().fill(TT.surfaceCard))
        .overlay(TTShape.panelShape().stroke(TT.hairline, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

// MARK: - 13 · Toggle row

struct TTToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var tint: Color = TT.accent

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ttBody()).foregroundColor(TT.textSecondary)
                if let s = subtitle {
                    Text(s).font(.ttCaption()).foregroundColor(TT.textTertiary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: tint))
    }
}

// MARK: - 14 · Slider row with tick scale

struct TTSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    var unit: String = ""
    var decimals: Int = 1
    var tint: Color = TT.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                TTLabel(text: title)
                Spacer(minLength: 8)
                Text(String(format: "%.\(decimals)f", value) + (unit.isEmpty ? "" : " \(unit)"))
                    .font(.ttReadout(.footnote, weight: .semibold))
                    .foregroundColor(tint)
            }
            VStack(spacing: 2) {
                Group {
                    if let step = step {
                        Slider(value: $value, in: range, step: step)
                    } else {
                        Slider(value: $value, in: range)
                    }
                }
                .tint(tint)
                TickRule(tint: TT.hairlineSoft, spacing: 8, height: 4)
            }
        }
    }
}

// MARK: - 15 · Empty state

/// A designed composition, not a grey glyph: a blanked instrument panel
/// with its scale still drawn, a reason, and the next action.
struct TTEmptyState: View {
    let title: String
    let message: String
    var icon: String = "ruler"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                        .fill(TT.surfaceSunken)
                        .frame(width: 56, height: 56)
                    RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                        .stroke(TT.hairline, lineWidth: 1)
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(.title3, design: .default, weight: .light))
                        .foregroundColor(TT.textDisabled)
                    GaugeScaleShape(divisions: 6, majorEvery: 3)
                        .stroke(TT.hairline, lineWidth: 1)
                        .frame(width: 8, height: 40)
                        .offset(x: 28)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.ttTitle(.headline)).foregroundColor(TT.textPrimary)
                    Text(message)
                        .font(.ttCaption())
                        .foregroundColor(TT.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            TickRule(tint: TT.hairlineSoft)
            if let actionTitle = actionTitle, let action = action {
                GhostButton(title: actionTitle, icon: "plus", action: action)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ttPanel()
    }
}

// MARK: - 16 · Toast

struct TTToast: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(TT.positive).frame(width: 3, height: 14)
            Text(text.uppercased())
                .font(.ttLabel(.caption))
                .kerning(1.2)
                .foregroundColor(TT.textPrimary)
        }
        .padding(.vertical, 11).padding(.horizontal, 16)
        .background(TTShape.panelShape().fill(TT.surfaceCard))
        .overlay(TTShape.panelShape().stroke(TT.hairline, lineWidth: 1))
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
            if let msg = message {
                VStack {
                    Spacer()
                    TTToast(text: msg).padding(.bottom, 90)
                }
                .transition(reduceMotion
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(TTMotion.spring) { message = nil }
                    }
                }
            }
        }
        .animation(TTMotion.spring, value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
