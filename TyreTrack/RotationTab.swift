//
//  RotationTab.swift
//  TyreTrack
//
//  Rotation bench: Rotation Schedule, Seasonal Swap, Alignment & Balance.
//

import SwiftUI

// MARK: - Hub

struct RotationHub: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore

    var body: some View {
        NavigationStack {
            HubScreen(title: "Rotation", subtitle: "Even wear, seasons and alignment.") {
                VehicleSelectorBar()
                if let v = selectedVehicle {
                    summary(v)
                    Group {
                        NavigationLink(destination: RotationScheduleView(vehicleID: v.id)) {
                            NavRow(title: "Rotation schedule",
                                   icon: "arrow.triangle.2.circlepath", tint: TT.accent)
                        }
                        NavigationLink(destination: SeasonalSwapView(vehicleID: v.id)) {
                            NavRow(title: "Seasonal swap", icon: "arrow.left.arrow.right")
                        }
                        NavigationLink(destination: AlignmentBalanceView(vehicleID: v.id)) {
                            NavRow(title: "Alignment & balance", icon: "slider.horizontal.3")
                        }
                    }
                    .buttonStyle(TTPressStyle())
                } else {
                    TTEmptyState(title: "No vehicle selected",
                                 message: "Rotation patterns and seasonal swaps are planned per vehicle.",
                                 icon: "arrow.triangle.2.circlepath",
                                 actionTitle: "Go to Vehicles") {
                        withAnimation(TTMotion.spring) { appState.mainTab = .vehicles }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var selectedVehicle: Vehicle? {
        store.vehicle(id: appState.selectedVehicleID) ?? store.vehicles.first
    }

    private func summary(_ v: Vehicle) -> some View {
        ToolPanel {
            if let rot = v.rotation {
                let next = RotationEngine.nextDate(lastRotated: rot.lastRotated,
                                                   intervalMiles: rot.intervalMiles,
                                                   milesPerMonth: appState.milesPerMonth)
                let due = RotationEngine.isDue(plan: rot, milesPerMonth: appState.milesPerMonth)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(rot.pattern.label)
                            .font(.ttTitle(.headline))
                            .foregroundColor(TT.textPrimary)
                            .lineLimit(2)
                        Text("Next \(Fmt.relative(next)) · \(Fmt.date(next))")
                            .font(.ttReadout(.caption2, weight: .medium))
                            .foregroundColor(TT.textTertiary)
                    }
                    Spacer(minLength: 6)
                    StatusPill(text: due ? "Due now" : "Scheduled",
                               tint: due ? TT.caution : TT.positive,
                               live: due)
                }
                TickRule(tint: TT.hairlineSoft)
                Text(RotationEngine.estimateNote(milesPerMonth: appState.milesPerMonth,
                                                 units: appState.units) + " — set your own figure in Settings.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No rotation plan yet.")
                    .font(.ttBody())
                    .foregroundColor(TT.textSecondary)
                Text("Set a pattern and an interval and the schedule projects the next date from your monthly mileage.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let sw = v.swap {
                TickRule(tint: TT.hairlineSoft)
                HStack(spacing: 8) {
                    Image(systemName: sw.currentSeason.icon)
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundColor(sw.currentSeason.tint)
                    Text("Fitted: \(sw.currentSeason.label)")
                        .font(.ttBody())
                        .foregroundColor(TT.textSecondary)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Rotation schedule

struct RotationScheduleView: View {
    @EnvironmentObject var store: GarageStore
    @EnvironmentObject var appState: AppState
    let vehicleID: UUID

    @State private var pattern: RotationPattern = .forwardCross
    @State private var interval: Double = 6000
    @State private var lastRotated = Date()
    @State private var toast: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Rotation Schedule") {
                    SectionHead(title: "Rotation schedule",
                                subtitle: "Move the tyres before they wear unevenly.")

                    let next = RotationEngine.nextDate(lastRotated: lastRotated,
                                                       intervalMiles: interval,
                                                       milesPerMonth: appState.milesPerMonth)
                    ToolPanel {
                        HStack(spacing: 10) {
                            ReadoutWell(caption: "Next rotation",
                                        value: Fmt.date(next),
                                        tint: TT.accent,
                                        style: .subheadline,
                                        live: true,
                                        showScale: false)
                            ReadoutWell(caption: "That is",
                                        value: Fmt.relative(next),
                                        tint: TT.steelLight,
                                        style: .subheadline,
                                        showScale: false)
                        }
                        Text(RotationEngine.estimateNote(milesPerMonth: appState.milesPerMonth,
                                                         units: appState.units)
                             + ". Change your monthly mileage in Settings and every projection follows.")
                            .font(.ttCaption())
                            .foregroundColor(TT.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ToolPanel {
                        TTLabel(text: "Rotation pattern")
                        WrapChips(data: RotationPattern.allCases) { p in
                            SelectChip(title: p.label, selected: pattern == p) {
                                withAnimation(TTMotion.snap) { pattern = p }
                            }
                        }
                        Text(pattern.hint)
                            .font(.ttCaption())
                            .foregroundColor(TT.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ToolPanel {
                        TTLabel(text: "Move map")
                        TickRule(tint: TT.hairlineSoft)
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
                        TTNumberField(title: "Interval (miles)", value: $interval,
                                      unit: "mi", decimals: 0)
                        DatePicker("Last rotated", selection: $lastRotated,
                                   displayedComponents: .date)
                            .font(.ttBody())
                            .tint(TT.accent)
                            .foregroundColor(TT.textSecondary)
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Save schedule", icon: "checkmark") { save(v) }
                        GhostButton(title: "Mark rotated today",
                                    icon: "arrow.counterclockwise", tint: TT.positive) {
                            lastRotated = Date(); save(v)
                        }
                        NavigationLink(destination: SeasonalSwapView(vehicleID: v.id)) {
                            NavRow(title: "Seasonal swap", icon: "arrow.left.arrow.right")
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .toast($toast)
                .onAppear {
                    if !loaded {
                        if let r = v.rotation {
                            pattern = r.pattern; interval = r.intervalMiles; lastRotated = r.lastRotated
                        }
                        loaded = true
                    }
                }
            } else {
                DetailScreen(title: "Rotation Schedule") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "arrow.triangle.2.circlepath")
                }
            }
        }
    }

    private func save(_ v: Vehicle) {
        var updated = v
        updated.rotation = RotationPlan(pattern: pattern, intervalMiles: interval,
                                        lastRotated: lastRotated)
        store.update(updated); store.flush(); toast = "Schedule saved"
    }
}

// MARK: - Seasonal swap

struct SeasonalSwapView: View {
    @EnvironmentObject var store: GarageStore
    let vehicleID: UUID
    @State private var season: TyreSeason = .summer
    @State private var swapDate = Date()
    @State private var storage = ""
    @State private var toast: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Seasonal Swap") {
                    SectionHead(title: "Seasonal swap",
                                subtitle: "Which set is on the car, and when the other goes back on.")

                    let next = SeasonEngine.nextSwapDate(current: season, after: swapDate)
                    ToolPanel {
                        HStack(spacing: 12) {
                            Image(systemName: season.icon)
                                .font(.system(.title2, design: .default, weight: .regular))
                                .foregroundColor(season.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                TTLabel(text: "Currently fitted")
                                Text(season.label)
                                    .font(.ttTitle(.headline))
                                    .foregroundColor(TT.textPrimary)
                                Text(next != nil ? "Next swap around \(Fmt.date(next!))" : "No swap needed")
                                    .font(.ttReadout(.caption2, weight: .medium))
                                    .foregroundColor(season.tint)
                            }
                            Spacer(minLength: 0)
                        }
                        TickRule(tint: TT.hairlineSoft)
                        Text(SeasonEngine.swapAdvice(current: season))
                            .font(.ttCaption())
                            .foregroundColor(TT.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ToolPanel {
                        TTLabel(text: "Set on the car")
                        SelectorRail(items: TyreSeason.allCases,
                                     selection: $season,
                                     tint: season.tint,
                                     label: { $0.label },
                                     icon: { $0.icon })
                        DatePicker("Swap date", selection: $swapDate, displayedComponents: .date)
                            .font(.ttBody())
                            .tint(TT.accent)
                            .foregroundColor(TT.textSecondary)
                        TTTextField(title: "Storage", text: $storage,
                                    placeholder: "Where the other set lives")
                    }

                    if let sw = v.swap, !sw.history.isEmpty {
                        SectionHead(title: "Set history", accent: TT.steelBlue)
                        ForEach(sw.history.reversed()) { h in
                            HStack(spacing: 10) {
                                Image(systemName: h.season.icon)
                                    .font(.system(.caption, design: .default, weight: .semibold))
                                    .foregroundColor(h.season.tint)
                                Text(h.season.label)
                                    .font(.ttBody())
                                    .foregroundColor(TT.textSecondary)
                                Spacer(minLength: 6)
                                Text(Fmt.date(h.date))
                                    .font(.ttReadout(.caption2, weight: .medium))
                                    .foregroundColor(TT.textTertiary)
                            }
                            .ttPanel(padding: 12)
                        }
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Record swap", icon: "arrow.left.arrow.right") {
                            save(v, addHistory: true)
                        }
                        GhostButton(title: "Save without logging a swap",
                                    icon: "tray.and.arrow.down") {
                            save(v, addHistory: false)
                        }
                        NavigationLink(destination: WearPatternView(vehicleID: v.id)) {
                            NavRow(title: "Wear pattern", icon: "waveform.path.ecg")
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .toast($toast)
                .onAppear {
                    if !loaded {
                        if let sw = v.swap {
                            season = sw.currentSeason
                            swapDate = sw.lastSwapDate
                            storage = sw.storageLocation
                        }
                        loaded = true
                    }
                }
            } else {
                DetailScreen(title: "Seasonal Swap") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "arrow.left.arrow.right")
                }
            }
        }
    }

    private func save(_ v: Vehicle, addHistory: Bool) {
        var updated = v
        var sw = updated.swap ?? SeasonalSwap()
        if addHistory && sw.currentSeason != season {
            sw.history.append(SetHistoryEntry(date: swapDate, season: season,
                                              note: "Swapped to \(season.label)"))
        }
        sw.currentSeason = season
        sw.lastSwapDate = swapDate
        sw.storageLocation = storage
        updated.swap = sw
        updated.season = season
        store.update(updated); store.flush(); toast = "Swap saved"
    }
}

// MARK: - Alignment & balance

struct AlignmentBalanceView: View {
    @EnvironmentObject var store: GarageStore
    let vehicleID: UUID
    @State private var alignmentDone = false
    @State private var balanceDone = false
    @State private var symptoms = ""
    @State private var action = ""
    @State private var toast: String?

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Alignment & Balance") {
                    SectionHead(title: "Alignment & balance",
                                subtitle: "The work that stops uneven wear coming back.")

                    ToolPanel {
                        TTToggleRow(title: "Wheel alignment done",
                                    isOn: $alignmentDone, tint: TT.positive)
                        TTToggleRow(title: "Wheels balanced",
                                    isOn: $balanceDone, tint: TT.positive)
                        TTTextField(title: "Symptoms", text: $symptoms,
                                    placeholder: "Vibration, pulling, uneven wear…")
                        TTTextField(title: "Action", text: $action,
                                    placeholder: "What was done, or what to do")
                    }

                    if v.alignmentNotes.isEmpty {
                        TTEmptyState(title: "No notes yet",
                                     message: "Record what the car was doing and what the garage did about it. Wear patterns start making sense once there is a history.",
                                     icon: "slider.horizontal.3")
                    } else {
                        SectionHead(title: "History", accent: TT.steelBlue)
                        ForEach(v.alignmentNotes.reversed()) { n in
                            ToolPanel(padding: 12, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text(Fmt.date(n.date))
                                        .font(.ttReadout(.caption, weight: .medium))
                                        .foregroundColor(TT.textTertiary)
                                    Spacer(minLength: 6)
                                    if n.alignmentDone { StatusPill(text: "Aligned", tint: TT.positive) }
                                    if n.balanceDone { StatusPill(text: "Balanced", tint: TT.steelBlue) }
                                }
                                if !n.symptoms.isEmpty {
                                    Text(n.symptoms)
                                        .font(.ttCaption())
                                        .foregroundColor(TT.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Save note", icon: "checkmark") { save(v) }
                        NavigationLink(destination: ExportDataView(vehicleID: v.id)) {
                            NavRow(title: "Export data", icon: "square.and.arrow.up")
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .toast($toast)
            } else {
                DetailScreen(title: "Alignment & Balance") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "slider.horizontal.3")
                }
            }
        }
    }

    private func save(_ v: Vehicle) {
        var updated = v
        updated.alignmentNotes.append(AlignmentNote(date: Date(), alignmentDone: alignmentDone,
                                                    balanceDone: balanceDone,
                                                    symptoms: symptoms, action: action))
        store.update(updated); store.flush()
        symptoms = ""; action = ""
        toast = "Note saved"
    }
}
