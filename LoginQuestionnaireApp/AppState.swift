//
//  AppState.swift
//  LoginQuestionnaireApp
//

import SwiftUI
import FirebaseAuth

/// Tracks auth and which screen to show: Login → Questionnaire → Break.
/// Auth state is driven by Firebase Auth.
final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentFlow: AppFlow = .questionnaire
    @Published var currentUsername: String = ""

    private var authListener: AuthStateDidChangeListenerHandle?

    enum AppFlow {
        case questionnaire
        case breakScreen
    }

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isLoggedIn = user != nil
                self?.currentUsername = user?.email?.components(separatedBy: "@").first ?? user?.displayName ?? ""
            }
        }
    }

    deinit {
        if let handle = authListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    /// Call after successful Firebase sign-in (or from LoginView). Updates flow; isLoggedIn is set by auth listener.
    func login(username: String = "") {
        if !username.isEmpty {
            currentUsername = username.trimmingCharacters(in: .whitespaces)
        }
        currentFlow = .questionnaire
    }

    func logout() {
        try? Auth.auth().signOut()
        currentUsername = ""
        currentFlow = .questionnaire
    }

    func showBreak() {
        currentFlow = .breakScreen
    }

    func showQuestionnaire() {
        currentFlow = .questionnaire
    }
}
