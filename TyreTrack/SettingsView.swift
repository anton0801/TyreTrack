//
//  SettingsView.swift
//  TyreTrack
//
//  Every control here does real, persisted work.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var showClearAlert = false
    @State private var toast: String?
    @State private var deniedNotice = false

    private let currencies = ["£", "$", "€", "¥", "₽"]

    var body: some View {
        DetailScreen(title: "Settings") {

            // Appearance
            ToolPanel {
                SectionHead(title: "Appearance", accent: TT.accent)
                TTLabel(text: "Theme")
                SelectorRail(items: ThemeMode.allCases,
                             selection: Binding(
                                get: { appState.themeMode },
                                set: { appState.themeMode = $0 }),
                             label: { $0.label },
                             icon: { $0.icon })
                Text("Applies instantly across the whole app.")
                    .font(.ttCaption()).foregroundColor(TT.textTertiary)
            }

            // Units & currency
            ToolPanel {
                SectionHead(title: "Units & currency", accent: TT.steelBlue)
                TTLabel(text: "Units")
                SelectorRail(items: Units.allCases,
                             selection: Binding(
                                get: { appState.units },
                                set: { appState.units = $0 }),
                             tint: TT.steelBlue,
                             label: { $0.short })
                Text(appState.units.label)
                    .font(.ttCaption()).foregroundColor(TT.textTertiary)
                TTLabel(text: "Currency")
                HStack(spacing: 8) {
                    ForEach(currencies, id: \.self) { c in
                        SelectChip(title: c, selected: appState.currency == c) {
                            appState.currency = c
                        }
                    }
                }
            }

            // Driving — feeds every distance-to-date projection
            ToolPanel {
                SectionHead(title: "Driving", accent: TT.accent)
                HStack(spacing: 10) {
                    ReadoutWell(caption: "Average distance",
                                value: Fmt.number(appState.units.distanceValue(fromMiles: appState.milesPerMonth),
                                                  decimals: 0),
                                unit: "\(appState.units.distanceUnit)/month",
                                tint: TT.accent,
                                live: true,
                                showScale: false)
                }
                TTSliderRow(title: "Distance per month",
                            value: $appState.milesPerMonth,
                            range: 100...3000, step: 50,
                            unit: "mi", decimals: 0)
                Text("Rotation intervals are measured in miles, so turning one into a date needs your own mileage. Every projected rotation date follows this figure.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Tread defaults
            ToolPanel {
                SectionHead(title: "Tread defaults", accent: TT.accent)
                TyreSection(depth: 8, legalMin: appState.defaultLegalMin, newDepth: 8)
                    .frame(height: 86)
                TTSliderRow(title: "Default legal minimum",
                            value: $appState.defaultLegalMin,
                            range: 1.0...3.0, step: 0.1,
                            unit: "mm", decimals: 1)
                Text("The starting limit for new vehicles. Each vehicle can override it.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Notifications
            ToolPanel {
                SectionHead(title: "Notifications", accent: TT.steelBlue)
                TTToggleRow(title: "Local reminders",
                            subtitle: "Pressure, rotation, seasonal swap and tread nudges",
                            isOn: Binding(
                                get: { appState.notificationsEnabled },
                                set: { newVal in
                                    appState.notificationsEnabled = newVal
                                    if newVal { enableReminders() } else { disableReminders() }
                                }))
                if deniedNotice {
                    Text("iOS is not allowing notifications for Tyre Track. Turn them on in the Settings app to get alerted.")
                        .font(.ttCaption())
                        .foregroundColor(TT.caution)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if store.reminders.isEmpty {
                    Text("No reminders are scheduled yet — add one in the Reminders centre.")
                        .font(.ttCaption())
                        .foregroundColor(TT.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\(store.reminders.count) scheduled.")
                        .font(.ttReadout(.caption2, weight: .medium))
                        .foregroundColor(TT.textTertiary)
                }
            }

            // Data
            ToolPanel {
                SectionHead(title: "Data", accent: TT.accent)
                Button(action: replayOnboarding) {
                    settingsRow("Replay the intake docket", "arrow.counterclockwise", TT.steelLight)
                }
                .buttonStyle(TTPressStyle())
                Button(action: { showClearAlert = true }) {
                    settingsRow("Clear all data", "trash.fill", TT.critical)
                }
                .buttonStyle(TTPressStyle())
            }

            // About
            ToolPanel {
                SectionHead(title: "About", accent: TT.steelBlue)
                HStack {
                    Text("Version").font(.ttBody()).foregroundColor(TT.textSecondary)
                    Spacer()
                    Text("1.0")
                        .font(.ttReadout(.footnote, weight: .medium))
                        .foregroundColor(TT.textTertiary)
                }
                TickRule(tint: TT.hairlineSoft)
                Text("Every measurement, photo and PDF stays on this device. No account, no sync, no network.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Observe the legal tread minimum in your region. Replace damaged or worn tyres. This app is a tracking aid, not a substitute for professional inspection.")
                    .font(.ttCaption())
                    .foregroundColor(TT.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toast($toast)
        .alert("Clear all data?", isPresented: $showClearAlert) {
            Button("Delete everything", role: .destructive) {
                store.clearAll()
                appState.selectedVehicleID = nil
                TTHaptics.notify(.warning)
                toast = "All data cleared"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every vehicle, reading, photo and reminder on this device.")
        }
    }

    private func settingsRow(_ title: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(.footnote, design: .default, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 22)
            Text(title).font(.ttBody()).foregroundColor(tint)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(.caption2, design: .default, weight: .bold))
                .foregroundColor(TT.textTertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    /// The master switch is one of only two places allowed to ask for
    /// notification permission — and it only asks because the user just
    /// turned reminders on.
    private func enableReminders() {
        NotificationManager.shared.requestAuthorization { granted in
            if granted {
                deniedNotice = false
                NotificationManager.shared.resync(reminders: store.reminders,
                                                  enabled: true) { id in
                    store.vehicle(id: id)?.displayTitle
                }
            } else {
                deniedNotice = true
            }
        }
        toast = "Reminders on"
    }

    private func disableReminders() {
        NotificationManager.shared.cancelAll()
        deniedNotice = false
        toast = "Reminders off"
    }

    private func replayOnboarding() {
        hasCompletedOnboarding = false
        withAnimation(TTMotion.panel) { appState.phase = .onboarding }
    }
}
