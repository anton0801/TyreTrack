//
//  OnboardingView.swift
//  TyreTrack
//
//  FIVE-STATION WALKTHROUGH.
//
//  Four stations explain what the app is for, then the fifth takes the
//  car in. No station is an icon over a headline: each one runs a real
//  component from the app with live numbers, and each one sets a real
//  preference that visibly changes what the next station shows.
//
//    01 · TREAD     drag a live tyre section past the limit and watch the
//                   verdict flip — sets the legal minimum, which redraws
//                   the limit line then and everywhere after
//    02 · PRESSURE  drag the real pressure gauge in and out of its band —
//                   sets the units, and the gauge relabels as you switch
//    03 · ROTATION  pick a pattern and the move map draws itself — sets
//                   your monthly distance, and the projected next-rotation
//                   date recalculates live from the real engine
//    04 · KEEPING   what gets remembered and what never leaves the phone —
//                   sets the reminder preference (iOS is only asked for
//                   permission later, when a reminder is actually created)
//    05 · VEHICLE   the intake: a spec card that fills in as you type, and
//                   becomes the first vehicle in the garage
//
//  Paging is driven by the buttons and the station rail rather than a
//  swipe, because four of the five stations carry sliders that a
//  horizontal swipe would fight with. Skip is silent: it keeps the
//  preferences the user already set and creates nothing.
//

import SwiftUI

// MARK: - Model

final class OnboardingModel: ObservableObject {
    // Preferences collected by stations 01–04
    @Published var minLimit: Double = 1.6
    @Published var units: Units = .imperial
    @Published var milesPerMonth: Double = RotationEngine.defaultMilesPerMonth
    @Published var wantsReminders: Bool = true

    // Station 05 — the vehicle
    @Published var vehicleTitle = ""
    @Published var type: VehicleType = .car
    @Published var tyreSize = "205/55 R16"
    @Published var loadIndex = "91V"
    @Published var season: TyreSeason = .summer
    @Published var tread: Double = 8
    @Published var pressure: Double = 32
    @Published var priority: Priority = .normal
    @Published var photoImage: UIImage? = nil

    var resolvedTitle: String {
        let trimmed = vehicleTitle.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "My Car" : trimmed
    }

    func buildVehicle(date: Date = Date()) -> Vehicle {
        var v = Vehicle()
        v.title = resolvedTitle
        v.type = type
        v.tyreSize = tyreSize
        v.season = season
        v.loadIndex = loadIndex
        v.units = units
        v.legalMinTread = minLimit
        v.recommendedPressure = pressure
        v.priority = priority
        v.createdAt = date
        if let image = photoImage {
            v.photoFile = PhotoStore.save(image)
        }
        // The user's own first measurements — not sample content.
        v.treadReadings = [TreadReading(date: date, depths: WheelValue.full(tread))]
        v.pressureReadings = [PressureReading(date: date,
                                              pressures: WheelValue.full(pressure),
                                              coldCheck: true)]
        v.rotation = RotationPlan(pattern: .forwardCross, intervalMiles: 6000, lastRotated: date)
        v.swap = SeasonalSwap(currentSeason: season, lastSwapDate: date,
                              storageLocation: "", history: [])
        return v
    }
}

// MARK: - Container

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var model = OnboardingModel()

    @State private var station = 0
    @State private var showPicker = false
    @State private var wipe: CGFloat = 0

    private let stationCount = 5

    var body: some View {
        ZStack {
            TT.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                stationRail
                pager
                bottomBar
            }

            BladeWipe(progress: wipe)
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker { image in model.photoImage = image }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TYRETRACK")
                    .font(.ttDisplay(.title))
                    .kerning(0.5)
                    .foregroundColor(TT.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(stationTitle(station))
                    .font(.ttLabel(.caption2))
                    .kerning(1.6)
                    .foregroundColor(TT.accent)
            }
            Spacer(minLength: 12)
            Button(action: skip) {
                Text("SKIP")
                    .font(.ttLabel(.caption))
                    .kerning(1.4)
                    .foregroundColor(TT.textTertiary)
                    .padding(.vertical, 8).padding(.horizontal, 10)
            }
            .buttonStyle(TTPressStyle())
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    // MARK: Station rail

    /// The tick rule doubling as progress: five machined segments, the
    /// ones you have been through filled. Tappable to go back.
    private var stationRail: some View {
        HStack(spacing: 5) {
            ForEach(0..<stationCount, id: \.self) { i in
                Button {
                    guard i <= station else { return }
                    TTHaptics.select()
                    withAnimation(pageAnimation) { station = i }
                } label: {
                    VStack(spacing: 4) {
                        Text(String(format: "%02d", i + 1))
                            .font(.ttReadout(.caption2, weight: .bold))
                            .foregroundColor(i == station ? TT.accent
                                             : (i < station ? TT.textSecondary : TT.textDisabled))
                        Rectangle()
                            .fill(i <= station ? TT.accent : TT.hairline)
                            .frame(height: i == station ? 3 : 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(TTPressStyle(scale: 0.96))
                .disabled(i > station)
                .accessibilityLabel("Station \(i + 1) of \(stationCount)")
            }
        }
        .animation(pageAnimation, value: station)
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private var pageAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : TTMotion.panel
    }

    // MARK: Pager

    private var pager: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<stationCount, id: \.self) { i in
                    ScrollView(showsIndicators: false) {
                        stationContent(i)
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                            .padding(.bottom, 24)
                    }
                    .frame(width: geo.size.width)
                }
            }
            .frame(width: geo.size.width * CGFloat(stationCount), alignment: .leading)
            .offset(x: -CGFloat(station) * geo.size.width)
            .animation(pageAnimation, value: station)
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            TickRule(tint: TT.hairline, spacing: 7, height: 5)
            HStack(spacing: 10) {
                if station > 0 {
                    GhostButton(title: "Back", icon: "chevron.left", fullWidth: false) {
                        withAnimation(pageAnimation) { station -= 1 }
                    }
                }
                if station < stationCount - 1 {
                    PrimaryButton(title: nextTitle, icon: "chevron.right") {
                        withAnimation(pageAnimation) { station += 1 }
                    }
                } else {
                    PrimaryButton(title: "Add vehicle", icon: "checkmark") {
                        finish()
                    }
                }
            }
            if station == stationCount - 1 {
                Button(action: skip) {
                    Text("Start with an empty garage instead")
                        .font(.ttCaption())
                        .foregroundColor(TT.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(TTPressStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var nextTitle: String {
        switch station {
        case 0:  return "Then pressure"
        case 1:  return "Then rotation"
        case 2:  return "Then keeping records"
        default: return "Add your car"
        }
    }

    private func stationTitle(_ index: Int) -> String {
        switch index {
        case 0:  return "Station 01 · Tread"
        case 1:  return "Station 02 · Pressure"
        case 2:  return "Station 03 · Rotation"
        case 3:  return "Station 04 · Keeping records"
        default: return "Station 05 · Your vehicle"
        }
    }

    // MARK: Stations

    @ViewBuilder
    private func stationContent(_ index: Int) -> some View {
        switch index {
        case 0:  TreadStation(model: model)
        case 1:  PressureStation(model: model)
        case 2:  RotationStation(model: model)
        case 3:  KeepingStation(model: model)
        default: VehicleStation(model: model, showPicker: $showPicker)
        }
    }

    // MARK: Flow

    /// Preferences the user set during the walkthrough are kept in both
    /// paths — they are answers, not a side effect of finishing.
    private func applyPreferences() {
        appState.units = model.units
        appState.defaultLegalMin = model.minLimit
        appState.milesPerMonth = model.milesPerMonth
        appState.notificationsEnabled = model.wantsReminders
        hasCompletedOnboarding = true
    }

    private func finish() {
        applyPreferences()
        store.add(model.buildVehicle())
        store.flush()
        appState.selectedVehicleID = store.vehicles.last?.id
        TTHaptics.notify(.success)
        exitToMain()
    }

    /// Silent: no vehicle, no seeded data, no permission prompt.
    private func skip() {
        applyPreferences()
        exitToMain()
    }

    private func exitToMain() {
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3)) { wipe = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.phase = .main
        }
    }
}

// MARK: - Shared station chrome

private struct StationHeader: View {
    let title: String
    let body_: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.ttTitle(.title2))
                .foregroundColor(TT.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(body_)
                .font(.ttBody())
                .foregroundColor(TT.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Marks the one control on a station that changes the app for good,
/// so an explanation never reads as decoration.
private struct SetsPreference: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(TT.accent).frame(width: 3, height: 11)
            Text(text.uppercased())
                .font(.ttLabel(.caption2))
                .kerning(1.2)
                .foregroundColor(TT.accent)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 01 · Tread

private struct TreadStation: View {
    @ObservedObject var model: OnboardingModel
    /// A tyre to play with. Nothing here is stored.
    @State private var demoTread: Double = 6.5

    private var status: TreadStatus {
        TreadEngine.status(depth: demoTread, legalMin: model.minLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StationHeader(
                title: "Tread is the only thing touching the road",
                body_: "Below the legal minimum a tyre stops clearing water and braking distances climb fast. Tyre Track reads every corner against the limit — drag the tread down and watch the verdict change."
            )

            ToolPanel {
                TyreSection(depth: demoTread, legalMin: model.minLimit, newDepth: 8)
                    .frame(height: 108)
                TTSliderRow(title: "Drag the tread down",
                            value: $demoTread,
                            range: 0...8, unit: "mm", decimals: 1)
                HStack {
                    Text("This tyre reads")
                        .font(.ttCaption())
                        .foregroundColor(TT.textTertiary)
                    Spacer(minLength: 6)
                    StatusPill(text: status.label, tint: status.tint, live: true)
                }
            }

            ToolPanel {
                SetsPreference(text: "Sets your legal minimum")
                SelectorRail(items: [1.6, 2.0, 3.0],
                             selection: $model.minLimit,
                             label: { String(format: "%.1f mm", $0) })
                Text("1.6 mm is the legal floor in the UK and most of the EU. Many garages advise replacing at 3 mm. The line you pick is drawn on every reading from here on, and each vehicle can override it later.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 02 · Pressure

private struct PressureStation: View {
    @ObservedObject var model: OnboardingModel
    /// Demo pressure in psi. Nothing here is stored.
    @State private var demoPSI: Double = 33

    private let recommendedPSI: Double = 33
    private let tolerancePSI: Double = 2

    private var status: PressureStatus {
        PressureEngine.status(actualPSI: demoPSI,
                              recommendedPSI: recommendedPSI,
                              tolerance: tolerancePSI)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StationHeader(
                title: "Most tyres die a few psi low",
                body_: "Under-inflation wears the shoulders away, heats the carcass and costs fuel — and it is invisible until the damage is done. Drag the needle out of the green band to see how the app scores a reading."
            )

            ToolPanel {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Fmt.number(model.units.pressureValue(fromPSI: demoPSI),
                                    decimals: model.units == .metric ? 2 : 0))
                        .font(.ttReadout(.title, weight: .bold))
                        .foregroundColor(status.tint)
                    Text(model.units.pressureUnit)
                        .font(.ttReadout(.footnote, weight: .medium))
                        .foregroundColor(TT.textTertiary)
                    Spacer(minLength: 6)
                    StatusPill(text: status.label, tint: status.tint, live: true)
                }
                PressureGauge(actual: model.units.pressureValue(fromPSI: demoPSI),
                              recommended: model.units.pressureValue(fromPSI: recommendedPSI),
                              tolerance: model.units.pressureValue(fromPSI: tolerancePSI),
                              status: status,
                              maxValue: model.units == .metric ? 4 : 60,
                              live: true)
                TTSliderRow(title: "Drag the pressure",
                            value: $demoPSI,
                            range: 20...45, unit: "psi", decimals: 0,
                            tint: TT.steelBlue)
                Text("Green is the recommended band for this tyre — \(Fmt.number(model.units.pressureValue(fromPSI: recommendedPSI), decimals: model.units == .metric ? 2 : 0)) \(model.units.pressureUnit), give or take \(Fmt.number(model.units.pressureValue(fromPSI: tolerancePSI), decimals: model.units == .metric ? 2 : 0)). Always measure cold, before you drive.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ToolPanel {
                SetsPreference(text: "Sets your units")
                SelectorRail(items: Units.allCases,
                             selection: $model.units,
                             tint: TT.steelBlue,
                             label: { $0.short })
                Text("The gauge above just relabelled. Every pressure, distance and readout in the app follows this choice.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 03 · Rotation

private struct RotationStation: View {
    @ObservedObject var model: OnboardingModel
    @State private var pattern: RotationPattern = .forwardCross

    private let demoInterval: Double = 6000

    private var nextDate: Date {
        RotationEngine.nextDate(lastRotated: Date(),
                                intervalMiles: demoInterval,
                                milesPerMonth: model.milesPerMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StationHeader(
                title: "Fronts wear about twice as fast",
                body_: "Moving the tyres around on a schedule evens that out and buys a set thousands of extra miles. Pick the pattern your car needs and the app draws the move map."
            )

            ToolPanel {
                WrapChips(data: RotationPattern.allCases) { p in
                    SelectChip(title: p.label, selected: pattern == p) {
                        withAnimation(TTMotion.snap) { pattern = p }
                    }
                }
                Text(pattern.hint)
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                TickRule(tint: TT.hairlineSoft)
                TTLabel(text: "Move map")
                ForEach(RotationEngine.moves(for: pattern)) { m in
                    HStack(spacing: 10) {
                        Text(m.from.short)
                            .font(.ttReadout(.footnote, weight: .bold))
                            .foregroundColor(TT.steelLight)
                            .frame(width: 30, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .font(.system(.caption2, design: .default, weight: .bold))
                            .foregroundColor(TT.textTertiary)
                        Text(m.to.short)
                            .font(.ttReadout(.footnote, weight: .bold))
                            .foregroundColor(TT.accent)
                            .frame(width: 30, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                }
            }

            ToolPanel {
                SetsPreference(text: "Sets your monthly distance")
                HStack(spacing: 10) {
                    ReadoutWell(caption: "Next rotation",
                                value: Fmt.relative(nextDate),
                                tint: TT.accent,
                                style: .subheadline,
                                live: true,
                                showScale: false)
                    ReadoutWell(caption: "Which is",
                                value: Fmt.date(nextDate),
                                tint: TT.steelLight,
                                style: .subheadline,
                                showScale: false)
                }
                TTSliderRow(title: "You drive about",
                            value: $model.milesPerMonth,
                            range: 100...3000, step: 50,
                            unit: "mi/month", decimals: 0)
                Text("Worked from a typical \(Fmt.number(demoInterval, decimals: 0)) mile interval. Rotation intervals are a distance, so turning one into a date needs your mileage — no guessed number is used anywhere. Change this any time in Settings.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 04 · Keeping records

private struct KeepingStation: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StationHeader(
                title: "It all stays on this phone",
                body_: "No account, no sign-in, no sync, no network calls at all. Your measurements, photos and signoffs live in the app, and you export them yourself when a garage, an MOT or a buyer wants proof."
            )

            ToolPanel {
                TTLabel(text: "What the app keeps for you")
                TickRule(tint: TT.hairlineSoft)
                keepRow("ruler.fill", "Tread depth per corner, dated", TT.accent)
                keepRow("speedometer", "Cold pressure per corner", TT.steelBlue)
                keepRow("arrow.triangle.2.circlepath", "Rotations and seasonal swaps", TT.steelBlue)
                keepRow("doc.text.fill", "PDF and CSV export on demand", TT.accent)
            }

            ToolPanel {
                SetsPreference(text: "Sets whether reminders are on")
                TTToggleRow(title: "Local reminders",
                            subtitle: "Nudges to check pressure, rotate, swap sets or measure tread",
                            isOn: $model.wantsReminders)
                TickRule(tint: TT.hairlineSoft)
                TTLabel(text: "Available nudges")
                WrapChips(data: ReminderType.allCases) { t in
                    NudgeTag(type: t, enabled: model.wantsReminders)
                }
                Text("Turning this on does not ask iOS for anything yet. The permission prompt appears only when you actually create your first reminder — and never if you skip this.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func keepRow(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(.caption, design: .default, weight: .bold))
                    .foregroundColor(tint)
            }
            Text(text)
                .font(.ttBody())
                .foregroundColor(TT.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// Read-only tag. The nudge list is a statement of what exists, not a
/// set of controls — nothing here is tappable, so nothing is a dead tap.
private struct NudgeTag: View {
    let type: ReminderType
    let enabled: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: type.icon)
                .font(.system(.caption2, design: .default, weight: .bold))
            Text(type.label.uppercased())
                .font(.ttLabel(.caption2))
                .kerning(1.1)
        }
        .foregroundColor(enabled ? TT.steelLight : TT.textDisabled)
        .padding(.vertical, 8).padding(.horizontal, 11)
        .background(
            RoundedRectangle(cornerRadius: TTShape.chip, style: .continuous)
                .fill(enabled ? TT.steelMuted : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TTShape.chip, style: .continuous)
                .stroke(enabled ? TT.steelBlue.opacity(0.5) : TT.hairline, lineWidth: 1)
        )
        .animation(TTMotion.snap, value: enabled)
    }
}

// MARK: - 05 · Your vehicle

private struct VehicleStation: View {
    @ObservedObject var model: OnboardingModel
    @Binding var showPicker: Bool

    private var status: TreadStatus {
        TreadEngine.status(depth: model.tread, legalMin: model.minLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StationHeader(
                title: "Now take your car in",
                body_: "One vehicle is enough to start. Everything you enter here is your own reading — the app never invents data for you."
            )

            // The spec card fills in as the fields below are typed.
            ToolPanel {
                HStack(alignment: .top, spacing: 12) {
                    Button(action: { showPicker = true }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                                .fill(TT.surfaceSunken)
                                .frame(width: 56, height: 56)
                            RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                                .stroke(TT.hairline, lineWidth: 1)
                                .frame(width: 56, height: 56)
                            if let image = model.photoImage {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: TTShape.well,
                                                                style: .continuous))
                            } else {
                                VStack(spacing: 2) {
                                    Image(systemName: model.type.icon)
                                        .font(.system(.body, design: .default, weight: .regular))
                                        .foregroundColor(TT.steelBlue)
                                    Text("PHOTO")
                                        .font(.ttLabel(.caption2))
                                        .kerning(0.8)
                                        .foregroundColor(TT.textDisabled)
                                }
                            }
                        }
                    }
                    .buttonStyle(TTPressStyle())
                    .accessibilityLabel(model.photoImage == nil ? "Add photo" : "Change photo")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.resolvedTitle)
                            .font(.ttTitle(.headline))
                            .foregroundColor(TT.textPrimary)
                            .lineLimit(2)
                        Text("\(model.tyreSize) · \(model.loadIndex)")
                            .font(.ttReadout(.caption, weight: .medium))
                            .foregroundColor(TT.textTertiary)
                            .lineLimit(1)
                        StatusPill(text: model.season.label, tint: model.season.tint)
                    }
                    Spacer(minLength: 0)
                }
                TickRule(tint: TT.hairlineSoft)
                HStack(spacing: 10) {
                    ReadoutWell(caption: "Tread now",
                                value: String(format: "%.1f", model.tread),
                                unit: "mm",
                                tint: status.tint,
                                live: true,
                                showScale: false)
                    ReadoutWell(caption: "Pressure",
                                value: Fmt.number(model.units.pressureValue(fromPSI: model.pressure),
                                                  decimals: model.units == .metric ? 2 : 0),
                                unit: model.units.pressureUnit,
                                tint: TT.steelBlue,
                                showScale: false)
                }
            }

            ToolPanel {
                TTTextField(title: "Vehicle name", text: $model.vehicleTitle,
                            placeholder: "e.g. Family Focus")
                TTLabel(text: "Type")
                SelectorRail(items: VehicleType.allCases,
                             selection: $model.type,
                             tint: TT.steelBlue,
                             label: { $0.label },
                             icon: { $0.icon })
                TTTextField(title: "Tyre size", text: $model.tyreSize,
                            placeholder: "205/55 R16")
                TTTextField(title: "Load index", text: $model.loadIndex, placeholder: "91V")
                TTLabel(text: "Set fitted")
                SelectorRail(items: TyreSeason.allCases,
                             selection: $model.season,
                             tint: model.season.tint,
                             label: { $0.label },
                             icon: { $0.icon })
            }

            ToolPanel {
                TTLabel(text: "First readings")
                TickRule(tint: TT.hairlineSoft)
                TyreSection(depth: model.tread, legalMin: model.minLimit, newDepth: 8)
                    .frame(height: 96)
                TTSliderRow(title: "Tread depth now", value: $model.tread,
                            range: 0...9, unit: "mm", decimals: 1)
                TTSliderRow(title: "Recommended pressure", value: $model.pressure,
                            range: 20...45, unit: "psi", decimals: 0, tint: TT.steelBlue)
                Text("Not sure yet? Leave them and log a proper reading from the Tread bench later.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ToolPanel {
                TTLabel(text: "Priority")
                SelectorRail(items: Priority.allCases,
                             selection: $model.priority,
                             label: { $0.label })
            }
        }
    }
}
