//
//  ContentView.swift
//  TyreTrack
//
//  Root router: Splash → Intake docket (first launch) → the benches.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            TT.surface.ignoresSafeArea()
            switch appState.phase {
            case .splash:
                LaunchView {
                    appState.finishSplash(hasOnboarded: hasCompletedOnboarding)
                }
                .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
    }
}
