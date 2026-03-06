//
//  LoginQuestionnaireAppApp.swift
//  LoginQuestionnaireApp
//

import SwiftUI
import FirebaseCore

@main
struct LoginQuestionnaireAppApp: App {
    @StateObject private var appState = AppState()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
