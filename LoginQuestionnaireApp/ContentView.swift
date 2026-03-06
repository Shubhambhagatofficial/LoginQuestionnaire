//
//  ContentView.swift
//  LoginQuestionnaireApp
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoggedIn {
                mainFlow
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isLoggedIn)
    }

    @ViewBuilder
    private var mainFlow: some View {
        switch appState.currentFlow {
        case .questionnaire:
            QuestionnaireView()
        case .breakScreen:
            BreakView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
