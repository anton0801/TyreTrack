//
//  AppState.swift
//  TyreTrack
//
//  App-wide state: launch phase, theme, and global display preferences.
//

import SwiftUI

enum AppPhase {
    case splash, onboarding, main
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case dark, light, system
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return nil
        }
    }
    var icon: String {
        switch self {
        case .dark:   return "moon.stars.fill"
        case .light:  return "sun.max.fill"
        case .system: return "circle.lefthalf.fill"
        }
    }
}

final class AppState: ObservableObject {
    @Published var phase: AppPhase = .splash

    /// Which bench is open. Held here so any screen — including an empty
    /// state on another bench — can send the user where the work is.
    @Published var mainTab: MainTab = .vehicles

    /// Currently focused vehicle, shared across the Tread/Pressure/Rotation/Reports tabs.
    @Published var selectedVehicleID: UUID? {
        didSet {
            UserDefaults.standard.set(selectedVehicleID?.uuidString, forKey: "tt.selectedVehicle")
        }
    }

    // Persisted global preferences (raw UserDefaults + didSet so @Published still fires)
    @Published var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: Keys.theme) }
    }
    @Published var units: Units {
        didSet { UserDefaults.standard.set(units.rawValue, forKey: Keys.units) }
    }
    @Published var currency: String {
        didSet { UserDefaults.standard.set(currency, forKey: Keys.currency) }
    }
    @Published var defaultLegalMin: Double {
        didSet { UserDefaults.standard.set(defaultLegalMin, forKey: Keys.legalMin) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notif) }
    }
    /// Drives every distance-to-date projection (rotation intervals are in
    /// miles, schedules are in days). Exposed in Settings — no magic number.
    @Published var milesPerMonth: Double {
        didSet { UserDefaults.standard.set(milesPerMonth, forKey: Keys.milesPerMonth) }
    }

    private enum Keys {
        static let theme = "tt.theme"
        static let units = "tt.units"
        static let currency = "tt.currency"
        static let legalMin = "tt.legalMin"
        static let notif = "tt.notif"
        static let milesPerMonth = "tt.milesPerMonth"
    }

    init() {
        let d = UserDefaults.standard
        themeMode = ThemeMode(rawValue: d.string(forKey: Keys.theme) ?? "") ?? .dark
        units = Units(rawValue: d.string(forKey: Keys.units) ?? "") ?? .imperial
        currency = d.string(forKey: Keys.currency) ?? "£"
        defaultLegalMin = d.object(forKey: Keys.legalMin) != nil ? d.double(forKey: Keys.legalMin) : 1.6
        notificationsEnabled = d.object(forKey: Keys.notif) != nil ? d.bool(forKey: Keys.notif) : true
        milesPerMonth = d.object(forKey: Keys.milesPerMonth) != nil
            ? d.double(forKey: Keys.milesPerMonth)
            : RotationEngine.defaultMilesPerMonth
        if let s = d.string(forKey: "tt.selectedVehicle") { selectedVehicleID = UUID(uuidString: s) }

        // Debug launch hooks (used only for automated verification).
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitest") { phase = .main }
        if let idx = args.firstIndex(of: "-tab"), idx + 1 < args.count {
            launchTabRaw = args[idx + 1]
        }
    }

    /// Raw name of the tab to open on launch (debug only).
    var launchTabRaw: String? = nil

    var colorScheme: ColorScheme? { themeMode.colorScheme }

    /// Advance from splash → onboarding or main. The splash has already
    /// wiped the screen with the blade, so this is a short crossfade
    /// behind it rather than a visible transition of its own.
    func finishSplash(hasOnboarded: Bool) {
        withAnimation(.easeInOut(duration: 0.22)) {
            phase = hasOnboarded ? .main : .onboarding
        }
    }
}
