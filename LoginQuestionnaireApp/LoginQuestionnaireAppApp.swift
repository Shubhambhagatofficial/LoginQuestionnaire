//
//  LoginQuestionnaireAppApp.swift
//  LoginQuestionnaireApp
//

import SwiftUI

@main
struct LoginQuestionnaireAppApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
