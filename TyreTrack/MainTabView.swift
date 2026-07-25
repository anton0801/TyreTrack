//
//  MainTabView.swift
//  TyreTrack
//
//  The shell: five benches — Vehicles · Tread · Pressure · Rotation ·
//  Reports — behind a machined tab rail. The active tab is a milled block
//  that slides between stations rather than a tinted glyph.
//

import SwiftUI

enum MainTab: Int, CaseIterable {
    case vehicles, tread, pressure, rotation, reports
    var title: String {
        switch self {
        case .vehicles: return "Vehicles"
        case .tread:    return "Tread"
        case .pressure: return "Pressure"
        case .rotation: return "Rotation"
        case .reports:  return "Reports"
        }
    }
    var icon: String {
        switch self {
        case .vehicles: return "car.2.fill"
        case .tread:    return "ruler.fill"
        case .pressure: return "speedometer"
        case .rotation: return "arrow.triangle.2.circlepath"
        case .reports:  return "doc.text.fill"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore

    var body: some View {
        ZStack(alignment: .bottom) {
            TT.surface.ignoresSafeArea()

            Group {
                switch appState.mainTab {
                case .vehicles: VehiclesHub()
                case .tread:    TreadHub()
                case .pressure: PressureHub()
                case .rotation: RotationHub()
                case .reports:  ReportsHub()
                }
            }
            .padding(.bottom, 60)

            TabRail(tab: $appState.mainTab)
        }
        .onAppear(perform: ensureSelection)
    }

    private func ensureSelection() {
        if appState.selectedVehicleID == nil || store.vehicle(id: appState.selectedVehicleID) == nil {
            appState.selectedVehicleID = store.vehicles.first?.id
        }
        if let raw = appState.launchTabRaw {
            switch raw {
            case "tread":    appState.mainTab = .tread
            case "pressure": appState.mainTab = .pressure
            case "rotation": appState.mainTab = .rotation
            case "reports":  appState.mainTab = .reports
            default:         appState.mainTab = .vehicles
            }
            appState.launchTabRaw = nil
        }
    }
}

// MARK: - Tab rail

private struct TabRail: View {
    @Binding var tab: MainTab
    @Namespace private var rail
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            TickRule(tint: TT.hairline, spacing: 7, height: 5)
                .padding(.horizontal, 10)
            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { t in
                    Button {
                        TTHaptics.select()
                        withAnimation(TTMotion.spring) { tab = t }
                    } label: {
                        VStack(spacing: 4) {
                            // At accessibility sizes five labels cannot fit
                            // without truncating into nonsense, so the rail
                            // drops to icons only — the VoiceOver label and
                            // the amber indicator still say where you are.
                            Image(systemName: t.icon)
                                .font(.system(typeSize.isAccessibilitySize ? .title2 : .subheadline,
                                              design: .default, weight: .semibold))
                            if !typeSize.isAccessibilitySize {
                                Text(t.title.uppercased())
                                    .font(.ttLabel(.caption2))
                                    .kerning(0.8)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                        .foregroundColor(tab == t ? TT.accent : TT.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 9)
                        .padding(.bottom, 4)
                        .background(alignment: .top) {
                            if tab == t {
                                Rectangle()
                                    .fill(TT.accent)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "tabBlock", in: rail)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TTPressStyle(scale: 0.94))
                    .accessibilityLabel(t.title)
                }
            }
            .padding(.bottom, 22)
        }
        .background(
            TT.surfaceRaised
                .overlay(Rectangle().fill(TT.hairline).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Vehicle selector bar

struct VehicleSelectorBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore

    var body: some View {
        if store.vehicles.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.vehicles) { v in
                        let selected = appState.selectedVehicleID == v.id
                        Button {
                            TTHaptics.select()
                            withAnimation(TTMotion.snap) { appState.selectedVehicleID = v.id }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: v.type.icon)
                                    .font(.system(.caption2, design: .default, weight: .bold))
                                Text(v.displayTitle.uppercased())
                                    .font(.ttLabel(.caption2))
                                    .kerning(1.1)
                                    .lineLimit(1)
                            }
                            .foregroundColor(selected ? TT.onAccent : TT.textSecondary)
                            .padding(.vertical, 8).padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: TTShape.chip, style: .continuous)
                                    .fill(selected ? TT.accent : TT.surfaceRaised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: TTShape.chip, style: .continuous)
                                    .stroke(selected ? TT.accent : TT.hairline, lineWidth: 1)
                            )
                        }
                        .buttonStyle(TTPressStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Screen scaffolds

/// Top-level bench screen: compressed display title over a rule.
struct HubScreen<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            TT.surface.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title.uppercased())
                            .font(.ttDisplay(.largeTitle))
                            .kerning(0.5)
                            .foregroundColor(TT.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        TickRule(tint: TT.accent.opacity(0.5), spacing: 7, height: 8)
                        if let s = subtitle {
                            Text(s)
                                .font(.ttCaption())
                                .foregroundColor(TT.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 10)
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
    }
}

/// Pushed detail screen.
struct DetailScreen<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            TT.surface.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) { content() }
                    .padding(16)
                    .padding(.bottom, 34)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Vehicle requirement

struct RequireVehicle<Content: View>: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: GarageStore
    let content: (Binding<Vehicle>) -> Content

    init(@ViewBuilder content: @escaping (Binding<Vehicle>) -> Content) {
        self.content = content
    }

    var body: some View {
        if let v = store.vehicle(id: appState.selectedVehicleID) ?? store.vehicles.first {
            content(store.binding(for: v))
        } else {
            TTEmptyState(title: "No vehicle yet",
                         message: "Every reading is filed against a vehicle, so the garage needs one first.",
                         icon: "car.2",
                         actionTitle: "Go to Vehicles") {
                withAnimation(TTMotion.spring) { appState.mainTab = .vehicles }
            }
        }
    }
}
