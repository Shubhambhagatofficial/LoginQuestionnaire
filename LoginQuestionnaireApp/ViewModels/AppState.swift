//
//  AppState.swift
//  LoginQuestionnaireApp
//

import SwiftUI
import FirebaseAuth

private let kDemoLoginKey = "LoginQuestionnaire.demoLogin"
private let kDemoUsernameKey = "LoginQuestionnaire.demoUsername"
private let kBreakStartedKey = "LoginQuestionnaire.breakStarted"
private let kHasLaunchedBeforeKey = "LoginQuestionnaire.hasLaunchedBefore"

final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentFlow: AppFlow = .questionnaire
    @Published var currentUsername: String = ""
    @Published var isDemoUser: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle?

    enum AppFlow {
        case questionnaire
        case breakScreen
    }

    init() {
        // After app delete + reinstall, UserDefaults is empty but Firebase Auth may still restore a session from Keychain.
        // If we have never set hasLaunchedBefore, this is first launch (or first launch after reinstall) → sign out Firebase so user gets a fresh start.
        if UserDefaults.standard.object(forKey: kHasLaunchedBeforeKey) == nil {
            try? Auth.auth().signOut()
            UserDefaults.standard.set(true, forKey: kHasLaunchedBeforeKey)
        }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.isDemoUser { return }
                self.isLoggedIn = user != nil
                self.currentUsername = user?.email?.components(separatedBy: "@").first ?? user?.displayName ?? ""
                if self.isLoggedIn {
                    self.restoreFlowFromPersistedBreak()
                }
            }
        }
        restorePersistedLogin()
    }

    private func restorePersistedLogin() {
        if UserDefaults.standard.bool(forKey: kDemoLoginKey) {
            isDemoUser = true
            isLoggedIn = true
            currentUsername = UserDefaults.standard.string(forKey: kDemoUsernameKey) ?? "Demo"
            restoreFlowFromPersistedBreak()
        }
    }

    /// If user had already started a break (pressed Continue), show break screen on launch.
    private func restoreFlowFromPersistedBreak() {
        if UserDefaults.standard.bool(forKey: kBreakStartedKey) {
            currentFlow = .breakScreen
        }
    }

    deinit {
        if let handle = authListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    /// Call after successful Firebase sign-in, or for demo account (useDemoAccount: true).
    func login(username: String = "", useDemoAccount: Bool = false) {
        if useDemoAccount {
            isDemoUser = true
            isLoggedIn = true
            currentUsername = username.isEmpty ? "Demo" : username
            UserDefaults.standard.set(true, forKey: kDemoLoginKey)
            UserDefaults.standard.set(currentUsername, forKey: kDemoUsernameKey)
        } else {
            isDemoUser = false
            isLoggedIn = true
            currentUsername = username.isEmpty ? "" : username.trimmingCharacters(in: .whitespaces)
            UserDefaults.standard.removeObject(forKey: kDemoLoginKey)
            UserDefaults.standard.removeObject(forKey: kDemoUsernameKey)
        }
        currentFlow = .questionnaire
    }

    func logout() {
        isDemoUser = false
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: kDemoLoginKey)
        UserDefaults.standard.removeObject(forKey: kDemoUsernameKey)
        UserDefaults.standard.set(false, forKey: kBreakStartedKey)
        try? Auth.auth().signOut()
        currentUsername = ""
        currentFlow = .questionnaire
    }

    /// Call when user taps Continue on questionnaire; persists so next launch goes to break screen.
    func showBreak() {
        currentFlow = .breakScreen
        UserDefaults.standard.set(true, forKey: kBreakStartedKey)
    }

    func showQuestionnaire() {
        currentFlow = .questionnaire
    }

    /// Call when break has ended (timer finished or user ended early). Clears persisted break state so next app launch shows questionnaire; user stays on break completion screen until they leave the app.
    func breakCompleted() {
        UserDefaults.standard.set(false, forKey: kBreakStartedKey)
    }
}
