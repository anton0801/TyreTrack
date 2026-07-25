//
//  TyreVisuals.swift
//  TyreTrack
//
//  Signature instrument graphics. Every one of them carries the tick
//  scale, every number on them is monospaced, and none of them uses a
//  shadow — depth is hairlines and sunken fills only.
//

import SwiftUI

// MARK: - Tread gauge

/// Tread blocks eroding against a drawn legal-limit line, with a mm tick
/// scale down the trailing edge. The app's primary instrument.
struct TreadGauge: View {
    /// Measured depth in mm.
    var depth: Double
    var legalMin: Double
    var newDepth: Double
    var status: TreadStatus
    var lugCount: Int = 6
    var height: CGFloat = 96
    var showScale: Bool = true
    /// Set once when a set climbs back above the limit — the gauge sweeps.
    var sweep: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var span: Double { max(newDepth, 0.1) }
    private var fill: Double { min(max(depth / span, 0), 1) }
    private var limitFraction: Double { min(max(legalMin / span, 0), 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .fill(TT.surfaceSunken)
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .stroke(TT.hairlineSoft, lineWidth: 1)

                GeometryReader { geo in
                    let innerH = geo.size.height - 12
                    let lugW = max((geo.size.width - 12 - CGFloat(lugCount - 1) * 5) / CGFloat(lugCount), 2)

                    ZStack(alignment: .bottom) {
                        HStack(alignment: .bottom, spacing: 5) {
                            ForEach(0..<lugCount, id: \.self) { i in
                                lug(width: lugW, maxHeight: innerH, index: i)
                            }
                        }
                        .padding(6)

                        // Legal limit line — drawn on the tyre, always visible.
                        limitLine(width: geo.size.width, innerH: innerH)

                        // Celebration sweep: a light band runs up the gauge once.
                        if sweep && !reduceMotion {
                            Rectangle()
                                .fill(
                                    LinearGradient(colors: [.clear, TT.positive.opacity(0.5), .clear],
                                                   startPoint: .bottom, endPoint: .top)
                                )
                                .frame(height: 30)
                                .offset(y: -innerH * 1.1)
                                .transition(.opacity)
                        }
                    }
                    // Fill the reader and sit on its floor — see TyreSection.
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                }
            }
            .frame(height: height)

            if showScale {
                scaleColumn
            }
        }
    }

    private func lug(width: CGFloat, maxHeight: CGFloat, index: Int) -> some View {
        // Slight per-lug variance so it reads as a real tread block, not a bar chart.
        let variance = 1.0 - (Double((index * 7) % 5) * 0.035)
        let frac = max(0.04, min(1, fill * variance))
        let tint = status == .replace ? TT.critical : TT.accent
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(tint)
                .frame(height: maxHeight * CGFloat(frac))
                .overlay(
                    // Groove hairline down the block centre.
                    Rectangle()
                        .fill(TT.surfaceSunken.opacity(0.55))
                        .frame(width: 1)
                )
        }
        .frame(width: width)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : TTMotion.spring, value: depth)
    }

    /// The limit is drawn as a rule with a marker at each end. It carries
    /// no text: the number lives in the caption row beneath, where it can
    /// grow with Dynamic Type without ever painting over the tread.
    private func limitLine(width: CGFloat, innerH: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(TT.critical)
                .frame(height: 1)
            HStack {
                Triangle()
                    .rotation(.degrees(-90))
                    .fill(TT.critical)
                    .frame(width: 5, height: 6)
                Spacer(minLength: 0)
                Triangle()
                    .rotation(.degrees(90))
                    .fill(TT.critical)
                    .frame(width: 5, height: 6)
            }
        }
        .frame(width: width)
        .offset(y: -(innerH * CGFloat(limitFraction) + 6))
    }

    private var scaleColumn: some View {
        ZStack(alignment: .topTrailing) {
            GaugeScaleShape(divisions: Int(span.rounded()), majorEvery: 2)
                .stroke(TT.hairline, lineWidth: 1)
                .frame(width: 9, height: height)
            Text("mm")
                .font(.ttReadout(.caption2, weight: .medium))
                .foregroundColor(TT.textTertiary)
                .fixedSize()
                .offset(x: 0, y: height + 2)
        }
        .frame(width: 22, height: height, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

// MARK: - Pressure gauge

/// A linear pressure rail: recommended band milled into the track, needle
/// block for the reading, tick scale beneath.
struct PressureGauge: View {
    var actual: Double        // display units
    var recommended: Double   // display units
    var tolerance: Double     // display units
    var status: PressureStatus
    var maxValue: Double = 60
    var live: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                let clamp: (Double) -> CGFloat = { CGFloat(min(max($0 / self.maxValue, 0), 1)) * w }
                let recLo = clamp(recommended - tolerance)
                let recHi = clamp(recommended + tolerance)
                let needle = clamp(actual)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(TT.surfaceSunken)
                        .frame(height: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .stroke(TT.hairlineSoft, lineWidth: 1)
                        )
                    Rectangle()
                        .fill(TT.positive.opacity(0.3))
                        .frame(width: max(recHi - recLo, 3), height: 10)
                        .offset(x: recLo)
                    Rectangle()
                        .fill(status.tint)
                        .frame(width: 3, height: 18)
                        .offset(x: max(min(needle - 1.5, w - 3), 0))
                        .ttLiveGlow(live)
                }
                .frame(height: 18)
            }
            .frame(height: 18)
            TickRule(tint: TT.hairlineSoft, spacing: 7, height: 4)
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : TTMotion.spring, value: actual)
    }
}

// MARK: - Wheel badge + set diagram

struct WheelBadge: View {
    let position: TyrePosition
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(position.short)
                .font(.ttLabel(.caption2))
                .kerning(1.2)
                .foregroundColor(TT.textTertiary)
            ZStack {
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .fill(TT.surfaceSunken)
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .stroke(tint, lineWidth: 1.5)
                Text(value)
                    .font(.ttReadout(.footnote, weight: .bold))
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 3)
            }
            .frame(width: 50, height: 62)
        }
    }
}

/// Top-view four-wheel board. Lays out as a plan drawing, not a grid.
struct WheelSetDiagram: View {
    var valueFor: (TyrePosition) -> (String, Color)
    var showSpare: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            HStack { wheel(.frontLeft); Spacer(minLength: 20); wheel(.frontRight) }
            ZStack {
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .fill(TT.surfaceSunken)
                    .overlay(
                        RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                            .stroke(TT.hairline, lineWidth: 1)
                    )
                    .frame(height: 54)
                    .padding(.horizontal, 26)
                VStack(spacing: 4) {
                    Text("FRONT")
                        .font(.ttLabel(.caption2))
                        .kerning(1.6)
                        .foregroundColor(TT.textTertiary)
                    TickRule(tint: TT.hairline, spacing: 5, height: 4)
                        .frame(width: 70)
                }
            }
            HStack { wheel(.rearLeft); Spacer(minLength: 20); wheel(.rearRight) }
            if showSpare {
                HStack { Spacer(); wheel(.spare); Spacer() }
            }
        }
    }

    private func wheel(_ pos: TyrePosition) -> some View {
        let (label, tint) = valueFor(pos)
        return WheelBadge(position: pos, value: label, tint: tint)
    }
}

// MARK: - Tyre cross-section (onboarding + splash)

/// A tyre cross-section with tread grooves and the legal-limit line
/// drawn across it. Used where the user has to *see* what the limit means.
struct TyreSection: View {
    /// Current tread depth in mm.
    var depth: Double
    var legalMin: Double
    var newDepth: Double = 8
    var grooveCount: Int = 5
    var showLimit: Bool = true
    /// The numeric caption under the drawing. Turned off where the screen
    /// already reports the limit itself (the splash).
    var limitCaption: Bool = true
    var tint: Color = TT.accent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fill: Double { min(max(depth / max(newDepth, 0.1), 0), 1) }
    private var limitFraction: Double { min(max(legalMin / max(newDepth, 0.1), 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            drawing
            if showLimit && limitCaption {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(TT.critical)
                        .frame(width: 14, height: 1)
                    Text("\(String(format: "%.1f", legalMin)) mm legal limit")
                        .font(.ttReadout(.caption2, weight: .medium))
                        .foregroundColor(TT.critical)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var drawing: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let carcassH = h * 0.32
            let treadH = h - carcassH
            let blockW = (w - CGFloat(grooveCount - 1) * 6) / CGFloat(grooveCount)

            ZStack(alignment: .bottom) {
                // Carcass / sidewall body
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .fill(TT.surfaceSunken)
                    .frame(height: carcassH)
                    .overlay(
                        RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                            .stroke(TT.hairline, lineWidth: 1)
                            .frame(height: carcassH),
                        alignment: .bottom
                    )

                // Tread blocks standing on the carcass
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<grooveCount, id: \.self) { i in
                        let variance = 1.0 - (Double((i * 3) % 4) * 0.03)
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(tint)
                            .frame(width: blockW,
                                   height: max(2, treadH * CGFloat(fill * variance)))
                    }
                }
                .frame(height: treadH, alignment: .bottom)
                .offset(y: -carcassH + 2)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : TTMotion.spring, value: depth)

                if showLimit {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(TT.critical)
                            .frame(height: 1)
                        HStack {
                            Triangle()
                                .rotation(.degrees(-90))
                                .fill(TT.critical)
                                .frame(width: 5, height: 7)
                            Spacer(minLength: 0)
                            Triangle()
                                .rotation(.degrees(90))
                                .fill(TT.critical)
                                .frame(width: 5, height: 7)
                        }
                    }
                    .offset(y: -(carcassH + treadH * CGFloat(limitFraction)) + 2)
                    .animation(reduceMotion ? .easeOut(duration: 0.2) : TTMotion.spring, value: legalMin)
                }
            }
            // A GeometryReader sizes its child to the child's own ideal
            // height and pins it to the top, so the drawing has to be told
            // to fill the box and sit on its floor — otherwise the tyre
            // floats with dead space under it and every offset below is
            // measured from the wrong baseline.
            .frame(width: w, height: h, alignment: .bottom)
        }
    }
}

// MARK: - Sweep gauge

/// Arc gauge with a milled tick bezel. Replaces the plain ring: the
/// needle arc sweeps and the figure counts.
struct SweepGauge: View {
    var fraction: Double   // 0…1
    var tint: Color
    var label: String
    var caption: String
    var lineWidth: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sweepDegrees: Double = 260

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side / 2

            ZStack {
                // Milled bezel — ticks sit on the rim, outside the arc.
                ForEach(0..<21, id: \.self) { i in
                    let major = i % 5 == 0
                    Rectangle()
                        .fill(major ? TT.hairline : TT.hairlineSoft)
                        .frame(width: 1, height: major ? 7 : 4)
                        .offset(y: -(radius - (major ? 3.5 : 2)))
                        .rotationEffect(.degrees(-sweepDegrees / 2 + Double(i) / 20 * sweepDegrees))
                }
                .accessibilityHidden(true)

                Circle()
                    .trim(from: 0, to: sweepDegrees / 360)
                    .stroke(TT.surfaceSunken, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(90 + (360 - sweepDegrees) / 2))
                    .padding(lineWidth / 2 + 11)

                Circle()
                    .trim(from: 0, to: CGFloat(min(max(fraction, 0), 1)) * sweepDegrees / 360)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(90 + (360 - sweepDegrees) / 2))
                    .padding(lineWidth / 2 + 11)
                    .animation(reduceMotion ? .easeOut(duration: 0.2) : TTMotion.spring,
                               value: fraction)

                VStack(spacing: 1) {
                    Text(label)
                        .font(.ttReadout(.title3, weight: .bold))
                        .foregroundColor(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(caption.uppercased())
                        .font(.ttLabel(.caption2))
                        .kerning(1.0)
                        .foregroundColor(TT.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, lineWidth + 14)
                // The dial face is part of the drawing: it keeps its own
                // proportions instead of scaling into an ellipsis. The same
                // figure is repeated as full-size text beside the gauge.
                .dynamicTypeSize(...DynamicTypeSize.large)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
