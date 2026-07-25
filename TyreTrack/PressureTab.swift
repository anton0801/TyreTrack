//
//  PressureTab.swift
//  TyreTrack
//
//  Pressure bench: Pressure Log, Pressure by Load.
//

import SwiftUI

// MARK: - Hub

struct PressureHub: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            HubScreen(title: "Pressure", subtitle: "Keep every corner inside its band.") {
                VehicleSelectorBar()
                if let v = selectedVehicle {
                    summary(v)
                    Group {
                        NavigationLink(destination: PressureLogView(vehicleID: v.id)) {
                            NavRow(title: "Pressure log", icon: "speedometer", tint: TT.steelLight)
                        }
                        NavigationLink(destination: PressureByLoadView(vehicleID: v.id)) {
                            NavRow(title: "Pressure by load", icon: "shippingbox.fill")
                        }
                    }
                    .buttonStyle(TTPressStyle())
                } else {
                    TTEmptyState(title: "No vehicle selected",
                                 message: "Log cold pressures per vehicle and every corner is read against its own recommended band.",
                                 icon: "speedometer",
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

    private func summary(_ v: Vehicle) -> some View {
        let rec = v.units.pressureValue(fromPSI: v.recommendedPressure)
        let decimals = v.units == .metric ? 1 : 0
        return ToolPanel {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(v.displayTitle)
                        .font(.ttTitle(.headline))
                        .foregroundColor(TT.textPrimary)
                        .lineLimit(2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Fmt.number(rec, decimals: decimals))
                            .font(.ttReadout(.title2, weight: .bold))
                            .foregroundColor(TT.steelLight)
                        Text(v.units.pressureUnit)
                            .font(.ttReadout(.footnote, weight: .medium))
                            .foregroundColor(TT.textTertiary)
                    }
                    TTLabel(text: "Recommended")
                }
                Spacer(minLength: 0)
            }

            if let p = v.latestPressure {
                TickRule(tint: TT.hairlineSoft)
                ForEach(Array(p.pressures.enumerated()), id: \.element.id) { index, wv in
                    let disp = v.units.pressureValue(fromPSI: wv.value)
                    let st = PressureEngine.status(actualPSI: wv.value,
                                                   recommendedPSI: v.recommendedPressure,
                                                   tolerance: v.tolerance)
                    HStack(spacing: 10) {
                        Text(wv.position.short)
                            .font(.ttReadout(.caption, weight: .bold))
                            .foregroundColor(TT.textTertiary)
                            .frame(width: 28, alignment: .leading)
                        PressureGauge(actual: disp,
                                      recommended: v.units.pressureValue(fromPSI: v.recommendedPressure),
                                      tolerance: v.units.pressureValue(fromPSI: v.tolerance),
                                      status: st,
                                      maxValue: v.units == .metric ? 4 : 60,
                                      live: index == 0)
                        Text(Fmt.number(disp, decimals: decimals))
                            .font(.ttReadout(.footnote, weight: .bold))
                            .foregroundColor(st.tint)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .ttStagger(index, appeared: appeared, reduceMotion: reduceMotion)
                }
                Text("Last checked \(Fmt.date(p.date))\(p.coldCheck ? " · cold" : "")")
                    .font(.ttReadout(.caption2, weight: .medium))
                    .foregroundColor(TT.textTertiary)
            } else {
                TickRule(tint: TT.hairlineSoft)
                Text("No pressure logged yet. Check them cold — before driving — for a reading that means anything.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Pressure log

struct PressureLogView: View {
    @EnvironmentObject var store: GarageStore
    let vehicleID: UUID

    @State private var values: [Double] = [0, 0, 0, 0]   // display units
    @State private var coldCheck = true
    @State private var date = Date()
    @State private var toast: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                let binding = store.binding(for: v)
                let decimals = v.units == .metric ? 1 : 0
                DetailScreen(title: "Pressure Log") {
                    SectionHead(title: "Pressure log",
                                subtitle: "Cold readings, one corner at a time.")

                    ToolPanel {
                        TTNumberField(title: "Recommended (\(v.units.pressureUnit))",
                                      value: Binding(
                                        get: { v.units.pressureValue(fromPSI: v.recommendedPressure) },
                                        set: { binding.wrappedValue.recommendedPressure = v.units.psi(fromDisplay: $0) }),
                                      unit: v.units.pressureUnit,
                                      decimals: decimals)
                    }

                    ToolPanel {
                        TTLabel(text: "Pressure per tyre (\(v.units.pressureUnit))")
                        TickRule(tint: TT.hairlineSoft)
                        VStack(spacing: 10) {
                            HStack(spacing: 10) { field(0, v); field(1, v) }
                            HStack(spacing: 10) { field(2, v); field(3, v) }
                        }
                        TTToggleRow(title: "Cold check",
                                    subtitle: "Measured before driving",
                                    isOn: $coldCheck,
                                    tint: TT.steelBlue)
                    }

                    ToolPanel {
                        DatePicker("Measured on", selection: $date, displayedComponents: .date)
                            .font(.ttBody())
                            .tint(TT.accent)
                            .foregroundColor(TT.textSecondary)
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Log pressure", icon: "square.and.arrow.down") { log(v) }
                        HStack(spacing: 10) {
                            GhostButton(title: "Fill recommended", icon: "arrow.counterclockwise") {
                                let rec = v.units.pressureValue(fromPSI: v.recommendedPressure)
                                values = Array(repeating: rec, count: 4)
                                toast = "Filled with recommended"
                            }
                            GhostButton(title: "Clear", icon: "xmark", tint: TT.critical) {
                                values = [0, 0, 0, 0]; toast = "Cleared"
                            }
                        }
                        NavigationLink(destination: RotationScheduleView(vehicleID: v.id)) {
                            NavRow(title: "Rotation schedule", icon: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .toast($toast)
                .onAppear { if !loaded { load(v); loaded = true } }
            } else {
                DetailScreen(title: "Pressure Log") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "speedometer")
                }
            }
        }
    }

    private func field(_ i: Int, _ v: Vehicle) -> some View {
        TTNumberField(title: TyrePosition.roadWheels[i].label,
                      value: Binding(get: { values[i] }, set: { values[i] = $0 }),
                      unit: v.units.pressureUnit,
                      decimals: v.units == .metric ? 1 : 0)
    }

    private func load(_ v: Vehicle) {
        if let p = v.latestPressure {
            values = TyrePosition.roadWheels.map { pos in
                let psi = p.pressures.first(where: { $0.position == pos })?.value ?? v.recommendedPressure
                return v.units.pressureValue(fromPSI: psi)
            }
            coldCheck = p.coldCheck
        } else {
            values = Array(repeating: v.units.pressureValue(fromPSI: v.recommendedPressure), count: 4)
        }
    }

    private func log(_ v: Vehicle) {
        var updated = v
        let psiValues = zip(TyrePosition.roadWheels, values).map {
            WheelValue(position: $0, value: v.units.psi(fromDisplay: $1))
        }
        updated.pressureReadings.append(PressureReading(date: date, pressures: psiValues,
                                                        coldCheck: coldCheck))
        store.update(updated); store.flush()

        let offBand = psiValues.contains {
            PressureEngine.status(actualPSI: $0.value,
                                  recommendedPSI: v.recommendedPressure,
                                  tolerance: v.tolerance) != .ok
        }
        TTHaptics.notify(offBand ? .warning : .success)
        toast = offBand ? "Logged — some corners out of band" : "Pressure logged"
    }
}

// MARK: - Pressure by load

struct PressureByLoadView: View {
    @EnvironmentObject var store: GarageStore
    let vehicleID: UUID
    @State private var towing = false
    @State private var fullCar = false
    @State private var notes = ""
    @State private var toast: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Pressure by Load") {
                    SectionHead(title: "Pressure by load",
                                subtitle: "A loaded car wants more air, mostly at the back.")

                    let corr = PressureEngine.loadCorrected(basePSI: v.recommendedPressure,
                                                            fullCar: fullCar, towing: towing)
                    let decimals = v.units == .metric ? 1 : 0
                    ToolPanel {
                        HStack(spacing: 10) {
                            ReadoutWell(caption: "Front axle",
                                        value: Fmt.number(v.units.pressureValue(fromPSI: corr.front),
                                                          decimals: decimals),
                                        unit: v.units.pressureUnit,
                                        tint: TT.accent)
                            ReadoutWell(caption: "Rear axle",
                                        value: Fmt.number(v.units.pressureValue(fromPSI: corr.rear),
                                                          decimals: decimals),
                                        unit: v.units.pressureUnit,
                                        tint: TT.accent,
                                        live: fullCar || towing)
                        }
                        TickRule(tint: TT.hairlineSoft)
                        Text("Base recommended \(Fmt.number(v.units.pressureValue(fromPSI: v.recommendedPressure), decimals: decimals)) \(v.units.pressureUnit). Always defer to the placard in the door shut.")
                            .font(.ttCaption())
                            .foregroundColor(TT.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ToolPanel {
                        TTToggleRow(title: "Fully loaded",
                                    subtitle: "Passengers and a full boot",
                                    isOn: $fullCar)
                        TTToggleRow(title: "Towing",
                                    subtitle: "Trailer or caravan on the back",
                                    isOn: $towing)
                        TTTextField(title: "Notes", text: $notes, placeholder: "Load details…")
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Save load setting", icon: "checkmark") { save(v, corr) }
                        NavigationLink(destination: SetSpareView(vehicleID: v.id)) {
                            NavRow(title: "Set & spare", icon: "circle.grid.2x2")
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .toast($toast)
                .onAppear {
                    if !loaded {
                        if let l = v.loadPressure {
                            towing = l.towing; fullCar = l.fullCar; notes = l.notes
                        }
                        loaded = true
                    }
                }
            } else {
                DetailScreen(title: "Pressure by Load") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "shippingbox")
                }
            }
        }
    }

    private func save(_ v: Vehicle, _ corr: (front: Double, rear: Double)) {
        var updated = v
        updated.loadPressure = LoadPressure(loadPressureFront: corr.front,
                                            loadPressureRear: corr.rear,
                                            towing: towing, fullCar: fullCar, notes: notes)
        store.update(updated); store.flush(); toast = "Load setting saved"
    }
}
