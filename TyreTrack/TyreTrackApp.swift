//
//  TyreTrackApp.swift
//  TyreTrack
//
//  App entry point. Injects app-wide state and dresses the system
//  navigation chrome in the app's own type and surfaces.
//

import SwiftUI
import Firebase

@main
struct TyreTrackApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var store = GarageStore()

    init() {
        Self.styleNavigationBar()
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(store)
                .preferredColorScheme(appState.colorScheme)
        }
    }

    /// UIKit still draws the pushed-screen title bar, so it gets the
    /// condensed heavy face and the graphite surface too — scaled with
    /// Dynamic Type like everything else.
    private static func styleNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: 0x1D2026) : UIColor(hex: 0xF9F7F1)
        }
        appearance.shadowColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: 0x353B45) : UIColor(hex: 0xD4D0C6)
        }

        let ink = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: 0xF3EFE6) : UIColor(hex: 0x191C21)
        }
        let base = UIFont.systemFont(ofSize: 17, weight: .heavy, width: .condensed)
        let scaled = UIFontMetrics(forTextStyle: .headline).scaledFont(for: base)
        appearance.titleTextAttributes = [.font: scaled, .foregroundColor: ink, .kern: 0.6]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(hex: 0xE9A231)
    }
}
