//
//  TreadTab.swift
//  TyreTrack
//
//  Tread bench: Tread Depth, Legal Limit Check, Tyre Age, Wear Pattern.
//

import SwiftUI

// MARK: - Hub

struct TreadHub: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            HubScreen(title: "Tread", subtitle: "Depth, legal limit, age and wear pattern.") {
                VehicleSelectorBar()
                if let v = selectedVehicle {
                    treadSummary(v)
                    Group {
                        NavigationLink(destination: TreadDepthView(vehicleID: v.id)) {
                            NavRow(title: "Tread depth", icon: "ruler.fill", tint: TT.accent)
                        }
                        NavigationLink(destination: LegalLimitView(vehicleID: v.id)) {
                            NavRow(title: "Legal limit check", icon: "checkmark.shield.fill")
                        }
                        NavigationLink(destination: TyreAgeView(vehicleID: v.id)) {
                            NavRow(title: "Tyre age", icon: "calendar")
                        }
                        NavigationLink(destination: WearPatternView(vehicleID: v.id)) {
                            NavRow(title: "Wear pattern", icon: "waveform.path.ecg")
                        }
                    }
                    .buttonStyle(TTPressStyle())
                } else {
                    TTEmptyState(title: "No vehicle selected",
                                 message: "Tread depth is measured per vehicle, against the legal limit you set for it.",
                                 icon: "ruler",
                                 actionTitle: "Go to Vehicles") {
                        withAnimation(TTMotion.spring) { appState.mainTab = .vehicles }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { appeared = true }
    }

    private var selectedVehicle: Vehicle? {
        store.vehicle(id: appState.selectedVehicleID) ?? store.vehicles.first
    }

    private func treadSummary(_ v: Vehicle) -> some View {
        let remaining = TreadEngine.remainingFraction(depth: v.minTreadNow,
                                                      legalMin: v.legalMinTread,
                                                      newDepth: v.newTread)
        let gauge = SweepGauge(fraction: remaining,
                               tint: v.overallTreadStatus.tint,
                               label: "\(Int((remaining * 100).rounded()))%",
                               caption: "left")
        let details = VStack(alignment: .leading, spacing: 6) {
            Text(v.displayTitle)
                .font(.ttTitle(.headline))
                .foregroundColor(TT.textPrimary)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Fmt.mmValue(v.minTreadNow))
                    .font(.ttReadout(.title2, weight: .bold))
                    .foregroundColor(v.overallTreadStatus.tint)
                Text("mm min")
                    .font(.ttReadout(.caption2, weight: .medium))
                    .foregroundColor(TT.textTertiary)
            }
            Text("\(Int((remaining * 100).rounded()))% of usable tread left")
                .font(.ttCaption())
                .foregroundColor(TT.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            StatusPill(text: v.overallTreadStatus.label,
                       tint: v.overallTreadStatus.tint,
                       live: true)
        }

        // At accessibility sizes the dial and the text stop fitting side by
        // side, so the panel stacks instead of squeezing either one.
        return ToolPanel {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    gauge.frame(width: 130, height: 130)
                    details
                }
            } else {
                HStack(spacing: 14) {
                    gauge.frame(width: 96, height: 96)
                    details
                    Spacer(minLength: 0)
                }
            }
            if v.latestTread == nil {
                TickRule(tint: TT.hairlineSoft)
                Text("No reading logged yet — the figure above uses the new-tyre reference.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .ttStagger(0, appeared: appeared, reduceMotion: reduceMotion)
    }
}

// MARK: - Tread depth

struct TreadDepthView: View {
    @EnvironmentObject var store: GarageStore
    let vehicleID: UUID

    @State private var depths: [Double] = [0, 0, 0, 0]
    @State private var date = Date()
    @State private var toast: String?
    @State private var loaded = false
    /// Celebration: the set has just climbed back above the legal limit.
    @State private var celebrate = false

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Tread Depth") {
                    SectionHead(title: "Tread depth",
                                subtitle: "Measure the shallowest groove on each tyre.")

                    let worst = depths.min() ?? 0
                    let status = TreadEngine.status(depth: worst, legalMin: v.legalMinTread)

                    ToolPanel {
                        TreadGauge(depth: worst,
                                   legalMin: v.legalMinTread,
                                   newDepth: v.newTread,
                                   status: status,
                                   sweep: celebrate)
                        TickRule(tint: TT.hairlineSoft)
                        HStack {
                            Text("Legal minimum \(Fmt.mm(v.legalMinTread))")
                                .font(.ttReadout(.caption2, weight: .medium))
                                .foregroundColor(TT.textTertiary)
                            Spacer(minLength: 6)
                            StatusPill(text: status.label, tint: status.tint, live: true)
                        }
                    }

                    ToolPanel {
                        TTLabel(text: "Tread per tyre")
                        TickRule(tint: TT.hairlineSoft)
                        wheelGrid()
                    }

                    ToolPanel {
                        DatePicker("Measured on", selection: $date, displayedComponents: .date)
                            .font(.ttBody())
                            .tint(TT.accent)
                            .foregroundColor(TT.textSecondary)
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Log reading", icon: "square.and.arrow.down") {
                            logTread(v)
                        }
                        HStack(spacing: 10) {
                            GhostButton(title: "Reset to new", icon: "arrow.counterclockwise") {
                                depths = Array(repeating: v.newTread, count: 4)
                                toast = "Reset to new-tyre reference"
                            }
                            GhostButton(title: "Clear", icon: "xmark", tint: TT.critical) {
                                depths = [0, 0, 0, 0]; toast = "Cleared"
                            }
                        }
                        NavigationLink(destination: PressureLogView(vehicleID: v.id)) {
                            NavRow(title: "Pressure log", icon: "speedometer")
                        }
                        .buttonStyle(TTPressStyle())
                    }

                    if !v.treadReadings.isEmpty {
                        SectionHead(title: "History", accent: TT.steelBlue)
                        ForEach(v.treadReadings.sorted { $0.date > $1.date }.prefix(6)) { r in
                            historyRow(r, v)
                        }
                    }
                }
                .toast($toast)
                .onAppear { if !loaded { load(v); loaded = true } }
            } else {
                DetailScreen(title: "Tread Depth") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "ruler")
                }
            }
        }
    }

    private func wheelGrid() -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) { wheelField(0); wheelField(1) }
            HStack(spacing: 10) { wheelField(2); wheelField(3) }
        }
    }

    private func wheelField(_ i: Int) -> some View {
        TTNumberField(title: TyrePosition.roadWheels[i].label,
                      value: Binding(get: { depths[i] }, set: { depths[i] = $0 }),
                      unit: "mm")
    }

    private func historyRow(_ r: TreadReading, _ v: Vehicle) -> some View {
        let st = TreadEngine.status(depth: r.minDepth, legalMin: v.legalMinTread)
        return HStack(spacing: 12) {
            Text(Fmt.date(r.date))
                .font(.ttReadout(.caption, weight: .medium))
                .foregroundColor(TT.textTertiary)
            Spacer(minLength: 6)
            Text("\(Fmt.mmValue(r.minDepth)) mm")
                .font(.ttReadout(.subheadline, weight: .bold))
                .foregroundColor(st.tint)
            StatusPill(text: st.label, tint: st.tint)
        }
        .ttPanel(padding: 12)
    }

    private func load(_ v: Vehicle) {
        if let r = v.latestTread {
            depths = TyrePosition.roadWheels.map { pos in
                r.depths.first(where: { $0.position == pos })?.value ?? v.newTread
            }
        } else {
            depths = Array(repeating: v.newTread, count: 4)
        }
    }

    private func logTread(_ v: Vehicle) {
        let previousWorst = v.latestTread?.minDepth
        var updated = v
        let values = zip(TyrePosition.roadWheels, depths).map { WheelValue(position: $0, value: $1) }
        let reading = TreadReading(date: date, depths: values)
        updated.treadReadings.append(reading)
        store.update(updated)
        store.flush()

        let newWorst = reading.minDepth
        let wasBelow = (previousWorst ?? .greatestFiniteMagnitude) <= v.legalMinTread
        let nowLegal = newWorst > v.legalMinTread

        if wasBelow && nowLegal {
            // The set is road legal again — the one celebration in the app.
            TTHaptics.notify(.success)
            withAnimation(TTMotion.spring) { celebrate = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.3)) { celebrate = false }
            }
            toast = "Back above the legal limit"
        } else {
            switch TreadEngine.status(depth: newWorst, legalMin: v.legalMinTread) {
            case .replace: TTHaptics.notify(.error)
            case .warning: TTHaptics.notify(.warning)
            default:       TTHaptics.commit()
            }
            toast = "Tread logged"
        }
    }
}

// MARK: - Legal limit check

struct LegalLimitView: View {
    @EnvironmentObject var store: GarageStore
    let vehicleID: UUID
    @State private var toast: String?

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                let binding = store.binding(for: v)
                DetailScreen(title: "Legal Limit") {
                    SectionHead(title: "Legal limit check",
                                subtitle: "Every corner against the minimum you set.")

                    ToolPanel {
                        TTNumberField(title: "Legal minimum", value: binding.legalMinTread, unit: "mm")
                    }

                    if v.latestTread == nil {
                        TTEmptyState(title: "Nothing to check yet",
                                     message: "Log a tread reading first — the check compares each measured corner against your legal minimum.",
                                     icon: "checkmark.shield")
                    } else {
                        ForEach(TyrePosition.roadWheels) { pos in
                            legalRow(v, pos)
                        }

                        let worst = v.minTreadNow
                        let verdict = LegalEngine.verdict(tread: worst, legalMin: v.legalMinTread)
                        ToolPanel {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    TTLabel(text: "Overall")
                                    Text(verdict.label)
                                        .font(.ttTitle(.headline))
                                        .foregroundColor(verdict.tint)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 6)
                                Image(systemName: LegalEngine.mustReplace(tread: worst, legalMin: v.legalMinTread)
                                      ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                    .font(.system(.title2, design: .default, weight: .regular))
                                    .foregroundColor(verdict.tint)
                            }
                        }
                    }

                    Text("Observe the legal tread minimum in your region. Replace damaged or worn tyres — this app is a tracking aid, not an inspection.")
                        .font(.ttCaption())
                        .foregroundColor(TT.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    NavigationLink(destination: PressureByLoadView(vehicleID: v.id)) {
                        NavRow(title: "Pressure by load", icon: "shippingbox.fill")
                    }
                    .buttonStyle(TTPressStyle())
                }
                .toast($toast)
            } else {
                DetailScreen(title: "Legal Limit") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "checkmark.shield")
                }
            }
        }
    }

    private func legalRow(_ v: Vehicle, _ pos: TyrePosition) -> some View {
        let tread = v.latestTread?.depths.first { $0.position == pos }?.value ?? 0
        let margin = LegalEngine.margin(tread: tread, legalMin: v.legalMinTread)
        let replace = LegalEngine.mustReplace(tread: tread, legalMin: v.legalMinTread)
        return HStack(spacing: 12) {
            Text(pos.short)
                .font(.ttReadout(.subheadline, weight: .bold))
                .foregroundColor(TT.textPrimary)
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Fmt.mmValue(tread)) mm")
                    .font(.ttReadout(.subheadline, weight: .semibold))
                    .foregroundColor(TT.textSecondary)
                Text("margin \(Fmt.mmValue(margin)) mm")
                    .font(.ttReadout(.caption2, weight: .medium))
                    .foregroundColor(TT.textTertiary)
            }
            Spacer(minLength: 6)
            StatusPill(text: replace ? "Replace" : "Legal",
                       tint: replace ? TT.critical : TT.positive)
        }
        .ttPanel(padding: 12)
    }
}

// MARK: - Tyre age

struct TyreAgeView: View {
    @EnvironmentObject var store: GarageStore
    let vehicleID: UUID
    @State private var dotCode = ""
    @State private var ageLimit = 6
    @State private var cracking = false
    @State private var toast: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Tyre Age") {
                    SectionHead(title: "Tyre age",
                                subtitle: "Rubber ages whether you drive on it or not.")

                    let age = TyreAgeEngine.ageYears(dotCode: dotCode)
                    let status = TyreAgeEngine.status(ageYears: age, limit: ageLimit)

                    ToolPanel {
                        HStack(spacing: 12) {
                            ReadoutWell(caption: "Estimated age",
                                        value: age != nil ? Fmt.number(age!, decimals: 1) : "—",
                                        unit: age != nil ? "yrs" : nil,
                                        tint: status.tint,
                                        live: age != nil)
                            ReadoutWell(caption: "Age limit",
                                        value: "\(ageLimit)",
                                        unit: "yrs",
                                        tint: TT.steelBlue)
                        }
                        StatusPill(text: status.label, tint: status.tint)
                        if age == nil {
                            Text("Enter the four-digit DOT code from the sidewall — week and year, e.g. 3621 is week 36 of 2021.")
                                .font(.ttCaption())
                                .foregroundColor(TT.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ToolPanel {
                        TTTextField(title: "DOT date code", text: $dotCode, placeholder: "WWYY")
                        HStack {
                            TTLabel(text: "Age limit")
                            Spacer(minLength: 8)
                            Stepper(value: $ageLimit, in: 3...12) {
                                Text("\(ageLimit) yrs")
                                    .font(.ttReadout(.footnote, weight: .semibold))
                                    .foregroundColor(TT.accent)
                            }
                            .tint(TT.accent)
                            .fixedSize()
                        }
                        TTToggleRow(title: "Sidewall cracking visible",
                                    isOn: $cracking, tint: TT.critical)
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Save age", icon: "checkmark") { save(v) }
                        NavigationLink(destination: LegalLimitView(vehicleID: v.id)) {
                            NavRow(title: "Legal limit check", icon: "checkmark.shield.fill")
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .toast($toast)
                .onAppear {
                    if !loaded {
                        if let a = v.age {
                            dotCode = a.dotCode; ageLimit = a.ageLimitYears; cracking = a.cracking
                        }
                        loaded = true
                    }
                }
            } else {
                DetailScreen(title: "Tyre Age") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "calendar")
                }
            }
        }
    }

    private func save(_ v: Vehicle) {
        var updated = v
        updated.age = TyreAgeInfo(dotCode: dotCode, ageLimitYears: ageLimit, cracking: cracking)
        store.update(updated); store.flush(); toast = "Age saved"
    }
}

// MARK: - Wear pattern

struct WearPatternView: View {
    @EnvironmentObject var store: GarageStore
    let vehicleID: UUID
    @State private var position: TyrePosition = .frontLeft
    @State private var pattern: WearPattern = .even
    @State private var notes = ""
    @State private var toast: String?

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Wear Pattern") {
                    SectionHead(title: "Wear pattern",
                                subtitle: "What the tyre is telling you about the car.")

                    ToolPanel {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(WearPatternEngine.severity(pattern))
                                .frame(width: 3)
                                .frame(maxHeight: .infinity)
                            VStack(alignment: .leading, spacing: 5) {
                                TTLabel(text: "Likely cause")
                                Text(WearPatternEngine.cause(pattern))
                                    .font(.ttTitle(.headline))
                                    .foregroundColor(TT.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        TickRule(tint: TT.hairlineSoft)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(.caption, design: .default, weight: .semibold))
                                .foregroundColor(TT.steelBlue)
                            Text(WearPatternEngine.action(pattern))
                                .font(.ttBody())
                                .foregroundColor(TT.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ToolPanel {
                        TTLabel(text: "Position")
                        SelectorRail(items: TyrePosition.roadWheels,
                                     selection: $position,
                                     tint: TT.steelBlue,
                                     label: { $0.short })
                        TTLabel(text: "Pattern")
                        WrapChips(data: WearPattern.allCases) { p in
                            SelectChip(title: p.label,
                                       selected: pattern == p,
                                       tint: WearPatternEngine.severity(p)) {
                                withAnimation(TTMotion.snap) { pattern = p }
                            }
                        }
                        TTTextField(title: "Notes", text: $notes, placeholder: "What you observed…")
                    }

                    if v.diagnoses.isEmpty {
                        TTEmptyState(title: "No diagnoses yet",
                                     message: "Pick the corner and the pattern you can see, and the likely cause and fix are recorded against this vehicle.",
                                     icon: "waveform.path.ecg")
                    } else {
                        SectionHead(title: "History", accent: TT.steelBlue)
                        ForEach(v.diagnoses.reversed()) { d in
                            HStack(spacing: 12) {
                                Text(d.position.short)
                                    .font(.ttReadout(.caption, weight: .bold))
                                    .foregroundColor(TT.textPrimary)
                                    .frame(width: 30, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(d.pattern.label)
                                        .font(.ttBody())
                                        .foregroundColor(TT.textSecondary)
                                    Text(Fmt.date(d.date))
                                        .font(.ttReadout(.caption2, weight: .medium))
                                        .foregroundColor(TT.textTertiary)
                                }
                                Spacer(minLength: 6)
                                Rectangle()
                                    .fill(WearPatternEngine.severity(d.pattern))
                                    .frame(width: 8, height: 8)
                            }
                            .ttPanel(padding: 12)
                        }
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Record diagnosis", icon: "magnifyingglass") { save(v) }
                        NavigationLink(destination: TyreAgeView(vehicleID: v.id)) {
                            NavRow(title: "Tyre age", icon: "calendar")
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .toast($toast)
            } else {
                DetailScreen(title: "Wear Pattern") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "waveform.path.ecg")
                }
            }
        }
    }

    private func save(_ v: Vehicle) {
        var updated = v
        updated.diagnoses.append(WearDiagnosis(date: Date(), position: position,
                                               pattern: pattern, notes: notes))
        store.update(updated); store.flush()
        notes = ""
        toast = "Diagnosis recorded"
    }
}
