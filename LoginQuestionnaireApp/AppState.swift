//
//  AppState.swift
//  LoginQuestionnaireApp
//

import SwiftUI

/// Tracks auth and which screen to show: Login → Questionnaire → Break
final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentFlow: AppFlow = .questionnaire

    enum AppFlow {
        case questionnaire
        case breakScreen
    }

    func login() {
        isLoggedIn = true
        currentFlow = .questionnaire
    }

    func logout() {
        isLoggedIn = false
    }

    func showBreak() {
        currentFlow = .breakScreen
    }

    func showQuestionnaire() {
        currentFlow = .questionnaire
    }
}
