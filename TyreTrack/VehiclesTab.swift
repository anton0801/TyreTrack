//
//  VehiclesTab.swift
//  TyreTrack
//
//  Vehicles bench: the garage list plus Vehicle Setup, Vehicle Detail,
//  Tyre Board and Set & Spare.
//

import SwiftUI

// MARK: - Hub

struct VehiclesHub: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            HubScreen(title: "Vehicles", subtitle: "Your garage. Tap a car for its tyre passport.") {

                HStack(spacing: 10) {
                    StatTile(label: "In garage", value: "\(store.vehicles.count)", tint: TT.accent)
                    StatTile(label: "Need replace",
                             value: "\(replaceCount)",
                             tint: replaceCount > 0 ? TT.critical : TT.positive)
                }

                NavigationLink(destination: VehicleSetupView(existing: nil)) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(.footnote, design: .default, weight: .bold))
                        Text("ADD VEHICLE").font(.ttLabel(.footnote)).kerning(1.3)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(.caption2, design: .default, weight: .bold))
                    }
                    .foregroundColor(TT.onAccent)
                    .padding(.vertical, 14).padding(.horizontal, 16)
                    .background(TTShape.panelShape().fill(TT.accent))
                }
                .buttonStyle(TTPressStyle())

                if store.vehicles.isEmpty {
                    TTEmptyState(title: "The garage is empty",
                                 message: "Add your first vehicle to start tracking tread depth, pressure, rotation and seasonal sets. Nothing is stored anywhere but this device.",
                                 icon: "car.2")
                } else {
                    SectionHead(title: "Garage", accent: TT.steelBlue)
                    ForEach(Array(store.vehicles.enumerated()), id: \.element.id) { index, v in
                        NavigationLink(destination: VehicleDetailView(vehicleID: v.id)) {
                            VehicleCard(vehicle: v)
                        }
                        .buttonStyle(TTPressStyle())
                        .ttStagger(index, appeared: appeared, reduceMotion: reduceMotion)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { appeared = true }
    }

    private var replaceCount: Int {
        store.vehicles.filter { $0.overallTreadStatus == .replace }.count
    }
}

struct VehicleCard: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 12) {
            VehicleThumb(fileName: vehicle.photoFile, icon: vehicle.type.icon, size: 54)
            VStack(alignment: .leading, spacing: 5) {
                Text(vehicle.displayTitle)
                    .font(.ttTitle(.headline))
                    .foregroundColor(TT.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(vehicle.tyreSize) · \(vehicle.season.label)")
                    .font(.ttReadout(.caption2, weight: .medium))
                    .foregroundColor(TT.textTertiary)
                    .lineLimit(1)
                StatusPill(text: vehicle.overallTreadStatus.label,
                           tint: vehicle.overallTreadStatus.tint)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.mmValue(vehicle.minTreadNow))
                    .font(.ttReadout(.title3, weight: .bold))
                    .foregroundColor(vehicle.overallTreadStatus.tint)
                Text("MM MIN")
                    .font(.ttLabel(.caption2)).kerning(1.1)
                    .foregroundColor(TT.textTertiary)
            }
        }
        .ttPanel()
    }
}

/// Vehicle photo tile — reads from disk via PhotoStore, never from the
/// defaults blob.
struct VehicleThumb: View {
    let fileName: String?
    let icon: String
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                .fill(TT.surfaceSunken)
            RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                .stroke(TT.hairline, lineWidth: 1)
            if let image = PhotoStore.image(named: fileName) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: TTShape.well, style: .continuous))
            } else {
                Image(systemName: icon)
                    .font(.system(.title3, design: .default, weight: .regular))
                    .foregroundColor(TT.steelBlue)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Vehicle / tyre setup

struct VehicleSetupView: View {
    @EnvironmentObject var store: GarageStore
    @EnvironmentObject var appState: AppState

    let existing: Vehicle?
    @State private var draft: Vehicle
    @State private var toast: String?
    @State private var savedOnce = false

    init(existing: Vehicle?) {
        self.existing = existing
        var seed = existing ?? Vehicle()
        if existing == nil { seed.legalMinTread = 1.6 }
        _draft = State(initialValue: seed)
    }

    var body: some View {
        DetailScreen(title: existing == nil ? "New Vehicle" : "Edit Vehicle") {
            SectionHead(title: "Vehicle & tyre setup",
                        subtitle: "The passport every reading is filed against.")

            ToolPanel {
                TTTextField(title: "Vehicle", text: $draft.title, placeholder: "e.g. Family Focus")
                TTTextField(title: "Tyre size", text: $draft.tyreSize, placeholder: "205/55 R16")

                TTLabel(text: "Vehicle type")
                SelectorRail(items: VehicleType.allCases,
                             selection: $draft.type,
                             tint: TT.steelBlue,
                             label: { $0.label },
                             icon: { $0.icon })

                TTLabel(text: "Set fitted")
                SelectorRail(items: TyreSeason.allCases,
                             selection: $draft.season,
                             tint: draft.season.tint,
                             label: { $0.label },
                             icon: { $0.icon })

                TTTextField(title: "Load index", text: $draft.loadIndex, placeholder: "91V")
                TTNumberField(title: "Pressure tolerance", value: $draft.tolerance,
                              unit: "psi", decimals: 0)
            }

            ToolPanel {
                TTLabel(text: "Limits")
                TickRule(tint: TT.hairlineSoft)
                TyreSection(depth: draft.newTread,
                            legalMin: draft.legalMinTread,
                            newDepth: max(draft.newTread, 1))
                    .frame(height: 92)
                TTNumberField(title: "New tread reference", value: $draft.newTread, unit: "mm")
                TTNumberField(title: "Legal minimum", value: $draft.legalMinTread, unit: "mm")
                TTNumberField(title: "Recommended pressure", value: $draft.recommendedPressure,
                              unit: "psi", decimals: 0)
            }

            VStack(spacing: 10) {
                PrimaryButton(title: existing == nil ? "Save vehicle" : "Update vehicle",
                              icon: "checkmark") {
                    save(msg: existing == nil ? "Vehicle saved" : "Vehicle updated")
                }
                if existing == nil {
                    NavigationLink(destination: TreadDepthView(vehicleID: draft.id)) {
                        NavRow(title: "Log first tread reading", icon: "ruler.fill", tint: TT.accent)
                    }
                    .buttonStyle(TTPressStyle())
                    .disabled(!savedOnce)
                    .opacity(savedOnce ? 1 : 0.45)
                }
            }
        }
        .toast($toast)
    }

    private func save(msg: String) {
        if existing == nil && !savedOnce {
            store.add(draft)
            appState.selectedVehicleID = draft.id
            savedOnce = true
        } else {
            store.update(draft)
        }
        store.flush()
        toast = msg
    }
}

// MARK: - Vehicle detail (passport hub)

struct VehicleDetailView: View {
    @EnvironmentObject var store: GarageStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let vehicleID: UUID
    @State private var toast: String?
    @State private var showPicker = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                content(v)
            } else {
                DetailScreen(title: "Vehicle") {
                    TTEmptyState(title: "Vehicle removed",
                                 message: "This vehicle no longer exists in the garage.",
                                 icon: "car.2")
                }
            }
        }
    }

    private func content(_ v: Vehicle) -> some View {
        let binding = store.binding(for: v)
        let nextRot = v.rotation.map {
            RotationEngine.nextDate(lastRotated: $0.lastRotated,
                                    intervalMiles: $0.intervalMiles,
                                    milesPerMonth: appState.milesPerMonth)
        }
        return DetailScreen(title: v.displayTitle) {
            // Passport header
            HStack(spacing: 12) {
                VehicleThumb(fileName: v.photoFile, icon: v.type.icon, size: 68)
                VStack(alignment: .leading, spacing: 5) {
                    Text(v.displayTitle)
                        .font(.ttTitle(.title3))
                        .foregroundColor(TT.textPrimary)
                        .lineLimit(2)
                    Text("\(v.tyreSize) · \(v.loadIndex)")
                        .font(.ttReadout(.caption, weight: .medium))
                        .foregroundColor(TT.textTertiary)
                    StatusPill(text: v.overallTreadStatus.label,
                               tint: v.overallTreadStatus.tint,
                               live: true)
                }
                Spacer(minLength: 0)
            }
            .ttPanel()

            HStack(spacing: 10) {
                ReadoutWell(caption: "Min tread",
                            value: Fmt.mmValue(v.minTreadNow),
                            unit: "mm",
                            tint: v.overallTreadStatus.tint)
                ReadoutWell(caption: "Season",
                            value: v.season.label,
                            tint: v.season.tint,
                            style: .headline,
                            showScale: false)
            }
            HStack(spacing: 10) {
                ReadoutWell(caption: "Next rotation",
                            value: nextRot.map { Fmt.relative($0) } ?? "—",
                            tint: TT.steelBlue,
                            style: .headline,
                            showScale: false)
                ReadoutWell(caption: "Priority",
                            value: v.priority.label,
                            tint: v.priority.tint,
                            style: .headline,
                            showScale: false)
            }
            if nextRot != nil {
                Text(RotationEngine.estimateNote(milesPerMonth: appState.milesPerMonth,
                                                 units: appState.units) + " — change it in Settings.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
            }

            ToolPanel {
                TTLabel(text: "Status notes")
                TTTextField(title: "Notes", text: binding.notes,
                            placeholder: "Anything worth remembering…")
                TTNumberField(title: "Legal minimum", value: binding.legalMinTread, unit: "mm")
            }

            Button(action: { showPicker = true }) {
                NavRow(title: v.photoFile == nil ? "Add photo" : "Change photo",
                       icon: "photo", tint: TT.steelLight)
            }
            .buttonStyle(TTPressStyle())

            SectionHead(title: "Open", accent: TT.steelBlue)
            NavigationLink(destination: TreadDepthView(vehicleID: v.id)) {
                NavRow(title: "Tread depth", icon: "ruler.fill", tint: TT.accent)
            }
            .buttonStyle(TTPressStyle())
            NavigationLink(destination: TyreBoardView(vehicleID: v.id)) {
                NavRow(title: "Tyre board", icon: "square.grid.2x2.fill")
            }
            .buttonStyle(TTPressStyle())
            NavigationLink(destination: SetSpareView(vehicleID: v.id)) {
                NavRow(title: "Set & spare", icon: "circle.grid.2x2")
            }
            .buttonStyle(TTPressStyle())
            NavigationLink(destination: VehicleReportView(vehicleID: v.id)) {
                NavRow(title: "Reports", icon: "doc.text.fill")
            }
            .buttonStyle(TTPressStyle())

            VStack(spacing: 10) {
                PrimaryButton(title: "Save changes", icon: "checkmark") {
                    store.flush(); toast = "Vehicle updated"
                }
                HStack(spacing: 10) {
                    GhostButton(title: "Duplicate", icon: "plus.square.on.square") {
                        store.duplicate(v); toast = "Duplicated"
                    }
                    DangerButton(title: "Delete", icon: "trash") { confirmDelete = true }
                }
            }
        }
        .toast($toast)
        .sheet(isPresented: $showPicker) {
            PhotoPicker { image in
                store.setPhoto(image, for: v.id)
                toast = "Photo updated"
            }
        }
        .confirmationDialog("Delete \(v.displayTitle)?",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Delete vehicle", role: .destructive) {
                store.delete(v)
                if appState.selectedVehicleID == v.id {
                    appState.selectedVehicleID = store.vehicles.first?.id
                }
                TTHaptics.notify(.warning)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text(deleteMessage(v))
        }
    }

    /// Names exactly what goes with the vehicle.
    private func deleteMessage(_ v: Vehicle) -> String {
        let reminders = store.reminderCount(for: v)
        var parts: [String] = []
        let readings = v.treadReadings.count + v.pressureReadings.count
        parts.append(readings == 1 ? "1 measurement" : "\(readings) measurements")
        if reminders > 0 {
            parts.append(reminders == 1 ? "1 reminder" : "\(reminders) reminders")
        }
        if v.photoFile != nil { parts.append("its photo") }
        return "Its " + parts.joined(separator: ", ") + " are removed. This cannot be undone."
    }
}

// MARK: - Tyre board

struct TyreBoardView: View {
    @EnvironmentObject var store: GarageStore
    @EnvironmentObject var appState: AppState
    let vehicleID: UUID
    @State private var toast: String?

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Tyre Board") {
                    SectionHead(title: "Tyre board",
                                subtitle: "All four corners at a glance.")

                    if v.latestTread == nil && v.latestPressure == nil {
                        TTEmptyState(title: "Nothing measured yet",
                                     message: "Log a tread reading and a pressure check and every corner appears here with its own status.",
                                     icon: "square.grid.2x2")
                    } else {
                        ToolPanel {
                            WheelSetDiagram(valueFor: { pos in board(v, pos) }, showSpare: true)
                                .padding(.vertical, 6)
                        }
                        ForEach(TyrePosition.roadWheels) { pos in
                            wheelRow(v, pos)
                        }
                    }
                }
                .toast($toast)
            } else {
                DetailScreen(title: "Tyre Board") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "square.grid.2x2")
                }
            }
        }
    }

    private func board(_ v: Vehicle, _ pos: TyrePosition) -> (String, Color) {
        if pos == .spare { return ("SP", TT.steelBlue) }
        guard let d = v.latestTread?.depths.first(where: { $0.position == pos }) else {
            return ("—", TT.textTertiary)
        }
        let st = TreadEngine.status(depth: d.value, legalMin: v.legalMinTread)
        return (Fmt.mmValue(d.value), st.tint)
    }

    private func wheelRow(_ v: Vehicle, _ pos: TyrePosition) -> some View {
        let tread = v.latestTread?.depths.first { $0.position == pos }?.value ?? 0
        let pressPSI = v.latestPressure?.pressures.first { $0.position == pos }?.value ?? 0
        let press = appState.units.pressureValue(fromPSI: pressPSI)
        let st = TreadEngine.status(depth: tread, legalMin: v.legalMinTread)
        return HStack(spacing: 12) {
            Text(pos.short)
                .font(.ttReadout(.subheadline, weight: .bold))
                .foregroundColor(TT.textPrimary)
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Fmt.mmValue(tread)) mm tread")
                    .font(.ttReadout(.caption, weight: .medium))
                    .foregroundColor(TT.textSecondary)
                Text("\(Fmt.number(press, decimals: appState.units == .metric ? 1 : 0)) \(appState.units.pressureUnit)")
                    .font(.ttReadout(.caption2, weight: .medium))
                    .foregroundColor(TT.textTertiary)
            }
            Spacer(minLength: 6)
            StatusPill(text: st.label, tint: st.tint)
        }
        .ttPanel(padding: 12)
    }
}

// MARK: - Set & spare

struct SetSpareView: View {
    @EnvironmentObject var store: GarageStore
    let vehicleID: UUID
    @State private var toast: String?

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                let binding = store.binding(for: v)
                DetailScreen(title: "Set & Spare") {
                    SectionHead(title: "Set & spare",
                                subtitle: "Four road tyres and the one in the boot.")

                    ToolPanel {
                        WheelSetDiagram(valueFor: { pos in
                            pos == .spare ? ("SP", TT.accent) : (pos.short, TT.steelBlue)
                        }, showSpare: true)
                    }

                    ToolPanel {
                        TTLabel(text: "Set history")
                        TickRule(tint: TT.hairlineSoft)
                        if let sw = v.swap, !sw.history.isEmpty {
                            ForEach(sw.history) { h in
                                HStack(spacing: 8) {
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
                            }
                        } else {
                            Text("No set changes logged yet. Record one in Rotation → Seasonal swap.")
                                .font(.ttCaption())
                                .foregroundColor(TT.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ToolPanel {
                        TTTextField(title: "Spare / notes", text: binding.notes,
                                    placeholder: "Spare condition, location…")
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Save set", icon: "checkmark") {
                            store.flush(); toast = "Set saved"
                        }
                        NavigationLink(destination: CostLifeView(vehicleID: v.id)) {
                            NavRow(title: "Cost & life", icon: "sterlingsign.circle")
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .toast($toast)
            } else {
                DetailScreen(title: "Set & Spare") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "circle.grid.2x2")
                }
            }
        }
    }
}
