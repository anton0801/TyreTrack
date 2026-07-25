//
//  ReportsTab.swift
//  TyreTrack
//
//  Reports bench: Reports & Export, Export & Data, Cost & Life,
//  Reminders Centre, Records Signoff, Settings.
//

import SwiftUI

// MARK: - Hub

struct ReportsHub: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore

    var body: some View {
        NavigationStack {
            HubScreen(title: "Reports", subtitle: "Build a record, export it, set the nudges.") {
                VehicleSelectorBar()
                if let v = selectedVehicle {
                    Group {
                        NavigationLink(destination: VehicleReportView(vehicleID: v.id)) {
                            NavRow(title: "Report & export", icon: "doc.text.fill", tint: TT.accent)
                        }
                        NavigationLink(destination: ExportDataView(vehicleID: v.id)) {
                            NavRow(title: "Export data", icon: "square.and.arrow.up")
                        }
                        NavigationLink(destination: CostLifeView(vehicleID: v.id)) {
                            NavRow(title: "Cost & life", icon: "sterlingsign.circle")
                        }
                        NavigationLink(destination: SignoffView(vehicleID: v.id)) {
                            NavRow(title: "Records signoff", icon: "square.and.pencil")
                        }
                    }
                    .buttonStyle(TTPressStyle())
                } else {
                    TTEmptyState(title: "No vehicle selected",
                                 message: "Reports and exports are built per vehicle from its own readings.",
                                 icon: "doc.text",
                                 actionTitle: "Go to Vehicles") {
                        withAnimation(TTMotion.spring) { appState.mainTab = .vehicles }
                    }
                }

                SectionHead(title: "Everything else", accent: TT.steelBlue)
                Group {
                    NavigationLink(destination: RemindersView()) {
                        NavRow(title: "Reminders centre", icon: "bell.badge.fill")
                    }
                    NavigationLink(destination: SettingsView()) {
                        NavRow(title: "Settings", icon: "gearshape.fill")
                    }
                }
                .buttonStyle(TTPressStyle())
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var selectedVehicle: Vehicle? {
        store.vehicle(id: appState.selectedVehicleID) ?? store.vehicles.first
    }
}

// MARK: - Report & export

struct VehicleReportView: View {
    @EnvironmentObject var store: GarageStore
    @EnvironmentObject var appState: AppState
    let vehicleID: UUID

    @State private var sections = ReportSections()
    @State private var generated = false
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var toast: String?

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Report & Export") {
                    SectionHead(title: "Report & export",
                                subtitle: "A clean record of this vehicle, built on device.")

                    ToolPanel {
                        TTLabel(text: "Include")
                        TickRule(tint: TT.hairlineSoft)
                        TTToggleRow(title: "Tread depth", isOn: $sections.tread)
                        TTToggleRow(title: "Pressure", isOn: $sections.pressure)
                        TTToggleRow(title: "Rotation", isOn: $sections.rotation)
                        TTToggleRow(title: "Season", isOn: $sections.season)
                        TTToggleRow(title: "Wear diagnoses", isOn: $sections.wear)
                        TTToggleRow(title: "Cost & life", isOn: $sections.costLife)
                    }

                    if generated {
                        ToolPanel {
                            TTLabel(text: "Preview")
                            TickRule(tint: TT.hairlineSoft)
                            Text(ReportBuilder.summaryText(for: v, sections: sections,
                                                           units: appState.units,
                                                           currency: appState.currency,
                                                           milesPerMonth: appState.milesPerMonth))
                                .font(.ttReadout(.caption2, weight: .regular))
                                .foregroundColor(TT.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.opacity)
                    } else {
                        TTEmptyState(title: "Nothing generated yet",
                                     message: "Pick the sections you want, then generate to see exactly what will be shared before anything leaves the app.",
                                     icon: "doc.text.magnifyingglass")
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Generate report", icon: "doc.text.magnifyingglass") {
                            withAnimation(TTMotion.spring) { generated = true }
                            toast = "Report generated"
                        }
                        HStack(spacing: 10) {
                            GhostButton(title: "PDF", icon: "arrow.down.doc") { exportPDF(v) }
                            GhostButton(title: "Share text", icon: "square.and.arrow.up") { shareText(v) }
                        }
                    }
                }
                .toast($toast)
                .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
            } else {
                DetailScreen(title: "Report & Export") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "doc.text")
                }
            }
        }
    }

    private func exportPDF(_ v: Vehicle) {
        if let url = ReportBuilder.pdf(for: v, sections: sections, units: appState.units,
                                       currency: appState.currency,
                                       milesPerMonth: appState.milesPerMonth) {
            shareItems = [url]; showShare = true
        } else {
            toast = "Could not build the PDF"
        }
    }

    private func shareText(_ v: Vehicle) {
        let text = ReportBuilder.summaryText(for: v, sections: sections, units: appState.units,
                                             currency: appState.currency,
                                             milesPerMonth: appState.milesPerMonth)
        shareItems = [text]; showShare = true
    }
}

// MARK: - Export & data

struct ExportDataView: View {
    @EnvironmentObject var store: GarageStore
    @EnvironmentObject var appState: AppState
    let vehicleID: UUID

    @State private var sections = ReportSections()
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var toast: String?

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Export Data") {
                    SectionHead(title: "Export data",
                                subtitle: "Your records, in formats other tools can read.")

                    HStack(spacing: 10) {
                        StatTile(label: "Tread logs", value: "\(v.treadReadings.count)", tint: TT.accent)
                        StatTile(label: "Pressure logs", value: "\(v.pressureReadings.count)",
                                 tint: TT.steelBlue)
                    }

                    if v.treadReadings.isEmpty && v.pressureReadings.isEmpty {
                        TTEmptyState(title: "Nothing to export yet",
                                     message: "Log a tread or pressure reading and it appears in the CSV and the PDF.",
                                     icon: "square.and.arrow.up")
                    } else {
                        ToolPanel {
                            TTLabel(text: "Sections")
                            TickRule(tint: TT.hairlineSoft)
                            TTToggleRow(title: "Tread", isOn: $sections.tread)
                            TTToggleRow(title: "Pressure", isOn: $sections.pressure)
                            TTToggleRow(title: "Rotation", isOn: $sections.rotation)
                            TTToggleRow(title: "Season", isOn: $sections.season)
                        }

                        HStack(spacing: 10) {
                            GhostButton(title: "CSV", icon: "tablecells") { exportCSV(v) }
                            GhostButton(title: "PDF", icon: "arrow.down.doc") { exportPDF(v) }
                        }
                    }

                    NavigationLink(destination: VehicleDetailView(vehicleID: v.id)) {
                        NavRow(title: "Vehicle detail", icon: "car.fill")
                    }
                    .buttonStyle(TTPressStyle())
                }
                .toast($toast)
                .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
            } else {
                DetailScreen(title: "Export Data") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "square.and.arrow.up")
                }
            }
        }
    }

    private func exportCSV(_ v: Vehicle) {
        let csv = ReportBuilder.csv(for: v, units: appState.units)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TyreTrack-\(v.displayTitle).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            shareItems = [url]; showShare = true
        } catch {
            toast = "Could not write the CSV"
        }
    }

    private func exportPDF(_ v: Vehicle) {
        if let url = ReportBuilder.pdf(for: v, sections: sections, units: appState.units,
                                       currency: appState.currency,
                                       milesPerMonth: appState.milesPerMonth) {
            shareItems = [url]; showShare = true
        } else {
            toast = "Could not build the PDF"
        }
    }
}

// MARK: - Cost & life

struct CostLifeView: View {
    @EnvironmentObject var store: GarageStore
    @EnvironmentObject var appState: AppState
    let vehicleID: UUID

    @State private var costPerTyre: Double = 0
    @State private var mileageLife: Double = 40000
    @State private var toast: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Cost & Life") {
                    SectionHead(title: "Cost & life",
                                subtitle: "What the set costs you for every mile it turns.")

                    let setCost = CostEngine.totalSetCost(costPerTyre: costPerTyre)
                    let perMile = CostEngine.costPerMile(costPerTyre: costPerTyre,
                                                         mileageLife: mileageLife)
                    let perUnit = appState.units == .metric ? perMile / 1.60934 : perMile

                    if costPerTyre <= 0 {
                        TTEmptyState(title: "No costs entered",
                                     message: "Put in what one tyre costs and how long a set lasts you, and the running cost per \(appState.units.distanceUnit) works itself out.",
                                     icon: "sterlingsign.circle")
                    } else {
                        HStack(spacing: 10) {
                            ReadoutWell(caption: "Set of four",
                                        value: Fmt.money(setCost, currency: appState.currency,
                                                         decimals: 0),
                                        tint: TT.accent,
                                        live: true,
                                        showScale: false)
                            ReadoutWell(caption: "Per \(appState.units.distanceUnit)",
                                        value: Fmt.money(perUnit, currency: appState.currency,
                                                         decimals: 3),
                                        tint: TT.steelBlue,
                                        showScale: false)
                        }
                    }

                    ToolPanel {
                        TTNumberField(title: "Cost per tyre (\(appState.currency))",
                                      value: $costPerTyre, unit: appState.currency, decimals: 0)
                        TTNumberField(title: "Mileage life (miles)",
                                      value: $mileageLife, unit: "mi", decimals: 0)
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Save", icon: "checkmark") { save(v) }
                        NavigationLink(destination: AlignmentBalanceView(vehicleID: v.id)) {
                            NavRow(title: "Alignment & balance", icon: "slider.horizontal.3")
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .toast($toast)
                .onAppear {
                    if !loaded {
                        if let c = v.costLife {
                            costPerTyre = c.costPerTyre; mileageLife = c.mileageLife
                        }
                        loaded = true
                    }
                }
            } else {
                DetailScreen(title: "Cost & Life") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "sterlingsign.circle")
                }
            }
        }
    }

    private func save(_ v: Vehicle) {
        var updated = v
        updated.costLife = CostLife(costPerTyre: costPerTyre, mileageLife: mileageLife,
                                    currency: appState.currency)
        store.update(updated); store.flush(); toast = "Saved"
    }
}

// MARK: - Reminders centre

struct RemindersView: View {
    @EnvironmentObject var store: GarageStore
    @EnvironmentObject var appState: AppState

    @State private var type: ReminderType = .pressure
    @State private var date = Date().addingTimeInterval(86400)
    @State private var vehicleID: UUID? = nil
    @State private var repeats = false
    @State private var toast: String?
    @State private var deniedNotice = false

    var body: some View {
        DetailScreen(title: "Reminders") {
            SectionHead(title: "Reminders centre",
                        subtitle: "Local nudges. Nothing leaves the device.")

            if !appState.notificationsEnabled {
                ToolPanel {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(.footnote, design: .default, weight: .semibold))
                            .foregroundColor(TT.caution)
                        Text("Reminders are switched off in Settings. New ones are saved but will not alert.")
                            .font(.ttCaption())
                            .foregroundColor(TT.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if deniedNotice {
                ToolPanel {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(.footnote, design: .default, weight: .semibold))
                            .foregroundColor(TT.caution)
                        Text("iOS is not allowing notifications for Tyre Track. The reminder is saved — turn notifications on in the Settings app to get alerted.")
                            .font(.ttCaption())
                            .foregroundColor(TT.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            ToolPanel {
                TTLabel(text: "Reminder")
                WrapChips(data: ReminderType.allCases) { t in
                    SelectChip(title: t.label, icon: t.icon, selected: type == t) {
                        withAnimation(TTMotion.snap) { type = t }
                    }
                }
                DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .font(.ttBody())
                    .tint(TT.accent)
                    .foregroundColor(TT.textSecondary)

                TTLabel(text: "Vehicle")
                WrapChips(data: vehicleChips) { chip in
                    SelectChip(title: chip.label, selected: vehicleID == chip.id, tint: TT.steelBlue) {
                        withAnimation(TTMotion.snap) { vehicleID = chip.id }
                    }
                }
                TTToggleRow(title: "Repeat monthly", isOn: $repeats)
            }

            PrimaryButton(title: "Add reminder", icon: "plus") { add() }

            if store.reminders.isEmpty {
                TTEmptyState(title: "No reminders set",
                             message: "Tyres go quiet until they don't. Set a nudge to check pressures, rotate, swap sets or measure tread.",
                             icon: "bell")
            } else {
                SectionHead(title: "Scheduled", accent: TT.steelBlue)
                ForEach(store.reminders.sorted { $0.date < $1.date }) { r in
                    reminderRow(r)
                }
            }
        }
        .toast($toast)
    }

    private struct VChip: Hashable { var id: UUID?; var label: String }
    private var vehicleChips: [VChip] {
        [VChip(id: nil, label: "Any")] + store.vehicles.map { VChip(id: $0.id, label: $0.displayTitle) }
    }

    private func reminderRow(_ r: TyreReminder) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .fill(TT.accentMuted)
                    .frame(width: 30, height: 30)
                Image(systemName: r.type.icon)
                    .font(.system(.footnote, design: .default, weight: .bold))
                    .foregroundColor(TT.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.type.label)
                    .font(.ttBody())
                    .foregroundColor(TT.textPrimary)
                Text("\(Fmt.dateTime(r.date))\(r.repeats ? " · monthly" : "")")
                    .font(.ttReadout(.caption2, weight: .medium))
                    .foregroundColor(TT.textTertiary)
                if let title = store.vehicle(id: r.vehicleID)?.displayTitle {
                    Text(title)
                        .font(.ttReadout(.caption2, weight: .medium))
                        .foregroundColor(TT.steelLight)
                }
            }
            Spacer(minLength: 6)
            Button(action: { remove(r) }) {
                Image(systemName: "trash")
                    .font(.system(.footnote, design: .default, weight: .semibold))
                    .foregroundColor(TT.critical)
                    .padding(8)
            }
            .buttonStyle(TTPressStyle())
            .accessibilityLabel("Delete reminder")
        }
        .ttPanel(padding: 12)
    }

    /// The only place in the app besides the Settings master switch that
    /// may ask for notification permission — and only because the user has
    /// just created a reminder.
    private func add() {
        let r = TyreReminder(type: type, date: date, vehicleID: vehicleID,
                             repeats: repeats, enabled: true)
        store.addReminder(r)
        store.flush()
        toast = "Reminder added"

        guard appState.notificationsEnabled else { return }
        NotificationManager.shared.requestAuthorization { granted in
            if granted {
                NotificationManager.shared.schedule(r, vehicleTitle: store.vehicle(id: vehicleID)?.displayTitle)
                deniedNotice = false
            } else {
                deniedNotice = true
            }
        }
    }

    private func remove(_ r: TyreReminder) {
        TTHaptics.select()
        withAnimation(TTMotion.spring) { store.deleteReminder(r) }
    }
}

// MARK: - Records signoff

struct SignoffView: View {
    @EnvironmentObject var store: GarageStore
    @EnvironmentObject var appState: AppState
    let vehicleID: UUID

    @State private var reviewer = ""
    @State private var result = "Pass"
    @State private var comment = ""
    @State private var signature: Data? = nil
    @State private var toast: String?
    @State private var showShare = false
    @State private var shareItems: [Any] = []

    private let results = ["Pass", "Advisory", "Fail"]

    var body: some View {
        Group {
            if let v = store.vehicle(id: vehicleID) {
                DetailScreen(title: "Records Signoff") {
                    SectionHead(title: "Records signoff",
                                subtitle: "Close the check off and sign it.")

                    ToolPanel {
                        TTTextField(title: "Reviewer", text: $reviewer, placeholder: "Your name")
                        TTLabel(text: "Result")
                        SelectorRail(items: results,
                                     selection: $result,
                                     tint: tint(for: result),
                                     label: { $0 })
                        TTTextField(title: "Comment", text: $comment,
                                    placeholder: "Notes on this check")
                    }

                    ToolPanel {
                        TTLabel(text: "Signature")
                        SignaturePad(pngData: $signature)
                    }

                    if v.signoffs.isEmpty {
                        TTEmptyState(title: "Nothing signed off yet",
                                     message: "A signoff freezes the state of this check with a name, a result and a signature.",
                                     icon: "square.and.pencil")
                    } else {
                        SectionHead(title: "History", accent: TT.steelBlue)
                        ForEach(v.signoffs.reversed()) { s in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(s.reviewer.isEmpty ? "—" : s.reviewer) · \(s.result)")
                                        .font(.ttBody())
                                        .foregroundColor(TT.textSecondary)
                                    Text(Fmt.dateTime(s.date))
                                        .font(.ttReadout(.caption2, weight: .medium))
                                        .foregroundColor(TT.textTertiary)
                                }
                                Spacer(minLength: 6)
                                if let data = s.signature, let ui = UIImage(data: data) {
                                    Image(uiImage: ui).resizable().scaledToFit()
                                        .frame(height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 2,
                                                                    style: .continuous))
                                }
                            }
                            .ttPanel(padding: 12)
                        }
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Approve check", icon: "checkmark.seal.fill") { save(v) }
                        GhostButton(title: "Export PDF", icon: "arrow.down.doc") { exportPDF(v) }
                    }
                }
                .toast($toast)
                .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
            } else {
                DetailScreen(title: "Records Signoff") {
                    TTEmptyState(title: "No vehicle",
                                 message: "This vehicle is no longer in the garage.",
                                 icon: "square.and.pencil")
                }
            }
        }
    }

    private func tint(for r: String) -> Color {
        switch r {
        case "Pass":     return TT.positive
        case "Advisory": return TT.caution
        default:         return TT.critical
        }
    }

    private func save(_ v: Vehicle) {
        var updated = v
        updated.signoffs.append(SignoffRecord(date: Date(), reviewer: reviewer, result: result,
                                              comment: comment, signature: signature))
        store.update(updated); store.flush()
        TTHaptics.notify(result == "Fail" ? .error : .success)
        toast = "Signed off"
    }

    private func exportPDF(_ v: Vehicle) {
        if let url = ReportBuilder.pdf(for: v, sections: ReportSections(), units: appState.units,
                                       currency: appState.currency,
                                       milesPerMonth: appState.milesPerMonth) {
            shareItems = [url]; showShare = true
        } else {
            toast = "Could not build the PDF"
        }
    }
}
