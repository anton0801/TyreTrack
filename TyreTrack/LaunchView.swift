//
//  LaunchView.swift
//  TyreTrack
//
//  Splash — a depth check performed on the bench, in five beats of its own.
//
//    1 · rule    the machinist rule draws itself across the bench, ticks
//                stamping in behind the line
//    2 · tread   a tyre cross-section stands up on the rule, blocks
//                extending to full depth
//    3 · probe   the depth-gauge blade descends into the centre groove,
//                seats, and the readout counts up to the measurement;
//                the legal-limit line snaps across the tread
//    4 · mark    the wordmark etches in left-to-right
//    5 · exit    the blade wipes down the screen — this app's signature
//                transition, reused for the onboarding hand-off
//
//  Sequenced by a structured-concurrency task, not a repeating timer:
//  there is no elapsed clock and no thresholds. Nothing loops, so nothing
//  can leak past the exit — and the task is cancelled automatically when
//  the view goes away.
//
//  Total: 2.35s. Reduce Motion gets the settled frame and a crossfade.
//

import SwiftUI

// MARK: - Signature transition

/// The blade wipe: a gauge blade sweeps down the screen and takes the
/// contents with it. Used by the splash exit and the onboarding hand-off.
struct BladeWipe: View {
    /// 0 = blade parked above the screen, 1 = screen fully wiped.
    var progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    TT.surface
                    Rectangle().fill(TT.accent).frame(height: 2)
                }
                .frame(height: geo.size.height * progress)
                Spacer(minLength: 0)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Splash

struct LaunchView: View {
    var onFinish: () -> Void

    private enum Beat { case rule, tread, probe, mark, exit }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ruleProgress: CGFloat = 0
    @State private var treadDepth: Double = 0
    @State private var showLimit = false
    @State private var probeDrop: CGFloat = -260
    @State private var readout: Double = 0
    @State private var markReveal: CGFloat = 0
    @State private var wipe: CGFloat = 0

    private let measuredDepth: Double = 6.4
    private let stageWidth: CGFloat = 230
    private let sectionHeight: CGFloat = 104
    /// Where the blade tip comes to rest: the top of the tread at the
    /// measured depth. carcass (32%) + tread (68%) × depth fraction.
    private var seatedDrop: CGFloat {
        -(sectionHeight * 0.32 + sectionHeight * 0.68 * CGFloat(measuredDepth / 8))
    }

    var body: some View {
        ZStack {
            TT.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Beats 2 + 3 — the tyre on the bench and the gauge blade
                ZStack(alignment: .bottom) {
                    TyreSection(depth: treadDepth,
                                legalMin: 1.6,
                                newDepth: 8,
                                grooveCount: 5,
                                showLimit: showLimit,
                                limitCaption: false)
                        .frame(width: stageWidth, height: sectionHeight)

                    gaugeBlade
                        .offset(y: probeDrop)
                }
                .frame(width: stageWidth, height: 200, alignment: .bottom)
                .clipped()

                // Beat 1 — the bench rule
                TickRuleShape(spacing: 7, majorEvery: 4, minorLength: 4, majorLength: 9)
                    .trim(from: 0, to: ruleProgress)
                    .stroke(TT.hairline, lineWidth: 1)
                    .frame(width: stageWidth, height: 9)
                    .padding(.top, 6)

                // Beat 3 — the readout
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(String(format: "%.1f", readout))
                        .font(.ttReadout(.title, weight: .bold))
                        .foregroundColor(TT.accent)
                    Text("mm")
                        .font(.ttReadout(.footnote, weight: .medium))
                        .foregroundColor(TT.textTertiary)
                }
                .padding(.top, 18)

                Text("TREAD DEPTH")
                    .font(.ttLabel(.caption2))
                    .kerning(2.0)
                    .foregroundColor(TT.textTertiary)
                    .padding(.top, 4)

                Spacer(minLength: 0)

                // Beat 4 — the wordmark, etched in left to right
                VStack(spacing: 6) {
                    Text("TYRETRACK")
                        .font(.ttDisplay(.largeTitle))
                        .kerning(1.0)
                        .foregroundColor(TT.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .mask(
                            Rectangle()
                                .scaleEffect(x: markReveal, y: 1, anchor: .leading)
                        )
                    Text("Tread · pressure · rotation")
                        .font(.ttLabel(.caption))
                        .kerning(1.6)
                        .foregroundColor(TT.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .opacity(Double(markReveal))
                }
                .padding(.bottom, 56)
            }
            .padding(.horizontal, 24)

            // Beat 5 — signature exit
            BladeWipe(progress: wipe)
        }
        .task { await run() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tyre Track")
    }

    // MARK: Gauge blade

    private var gaugeBlade: some View {
        VStack(spacing: 0) {
            // Blade body with its own milled scale
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(TT.steelLight)
                    .frame(width: 7, height: 74)
                GaugeScaleShape(divisions: 7, majorEvery: 2, minorLength: 3, majorLength: 6)
                    .stroke(TT.surfaceSunken.opacity(0.65), lineWidth: 1)
                    .frame(width: 7, height: 74)
            }
            // Tip
            Triangle()
                .fill(TT.steelLight)
                .frame(width: 9, height: 8)
        }
    }

    // MARK: Choreography

    private func run() async {
        if reduceMotion {
            // Settled frame, held, then a crossfade — no movement at all.
            ruleProgress = 1
            treadDepth = measuredDepth
            showLimit = true
            probeDrop = seatedDrop
            readout = measuredDepth
            markReveal = 1
            guard await beat(900) else { return }
            withAnimation(.easeInOut(duration: 0.3)) { wipe = 1 }
            guard await beat(320) else { return }
            onFinish()
            return
        }

        // 1 · rule
        withAnimation(.easeOut(duration: 0.38)) { ruleProgress = 1 }
        guard await beat(400) else { return }

        // 2 · tread stands up
        withAnimation(TTMotion.spring) { treadDepth = measuredDepth }
        guard await beat(560) else { return }

        // 3 · blade descends, seats, reads
        withAnimation(.timingCurve(0.3, 0, 0.2, 1, duration: 0.42)) { probeDrop = seatedDrop }
        guard await beat(300) else { return }
        TTHaptics.select()
        withAnimation(TTMotion.readout) { readout = measuredDepth }
        withAnimation(TTMotion.snap) { showLimit = true }
        guard await beat(250) else { return }

        // 4 · wordmark etches in
        withAnimation(.easeOut(duration: 0.34)) { markReveal = 1 }
        guard await beat(440) else { return }

        // 5 · blade wipe
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)) { wipe = 1 }
        guard await beat(330) else { return }
        onFinish()
    }

    /// Sleep for one beat. Returns false if the view went away mid-beat,
    /// which ends the sequence without ever calling `onFinish`.
    private func beat(_ milliseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

// MARK: - Blade tip

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
