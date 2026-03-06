//
//  LoginView.swift
//  LoginQuestionnaireApp
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var hasReferralCode: Bool = false
    @State private var isLoggingIn: Bool = false
    @State private var loginError: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    private var canContinue: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    private let accentColor = Color(red: 0.45, green: 0.35, blue: 0.85)
    private let disabledButtonGray = Color(red: 0.9, green: 0.9, blue: 0.92)
    private let disabledTextGray = Color(red: 0.5, green: 0.5, blue: 0.55)
    private let borderGray = Color(red: 0.88, green: 0.88, blue: 0.9)
    private let borderFocused = Color(red: 0.75, green: 0.75, blue: 0.8)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    inputFields
                    referralCheckbox
                    termsText
                    continueButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Login failed", isPresented: .constant(loginError != nil)) {
                Button("OK") { loginError = nil }
            } message: {
                if let err = loginError { Text(err) }
            }
        }
    }

    private var header: some View {
        Text("Login or Sign up to continue")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
    }

    private var inputFields: some View {
        VStack(spacing: 16) {
            TextField("Enter your email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .textFieldStyle(LoginFieldStyle(
                    borderColor: focusedField == .email ? accentColor : (!email.isEmpty ? borderFocused : borderGray)
                ))

            SecureField("Enter password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .textFieldStyle(LoginFieldStyle(
                    borderColor: focusedField == .password ? accentColor : (!password.isEmpty ? borderFocused : borderGray)
                ))
        }
    }

    private var referralCheckbox: some View {
        Button {
            hasReferralCode.toggle()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(hasReferralCode ? accentColor : borderGray, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if hasReferralCode {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                }
                Text("I have a referral code (optional)")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var termsText: some View {
        HStack(spacing: 4) {
            Text("By clicking, I accept the")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                .font(.caption)
                .foregroundStyle(accentColor)
            Text("&")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                .font(.caption)
                .foregroundStyle(accentColor)
        }
    }

    private var continueButton: some View {
		VStack {
			Button {
				signInOrSignUp()
			} label: {
				Group {
					if isLoggingIn {
						ProgressView()
							.tint(.white)
					} else {
						Text("Continue")
					}
				}
				.font(.headline)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 16)
				.background(canContinue && !isLoggingIn ? accentColor : disabledButtonGray)
				.foregroundStyle(canContinue && !isLoggingIn ? .white : disabledTextGray)
				.clipShape(RoundedRectangle(cornerRadius: 12))
			}
			.disabled(!canContinue || isLoggingIn)
			.padding(.top, 8)
			Text("Demo: \(Self.demoEmail) / \(Self.demoPassword)")
				.font(.caption2)
				.foregroundStyle(.tertiary)
		}
    }

    /// Demo account – bypasses Firebase. Use this to try the app while Auth is being fixed.
    private static let demoEmail = "demo@demo.com"
    private static let demoPassword = "demo123"

    private func signInOrSignUp() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else { return }

        if trimmedEmail == Self.demoEmail && trimmedPassword == Self.demoPassword {
            appState.login(username: "Demo", useDemoAccount: true)
            return
        }

        guard trimmedEmail.contains("@"), trimmedEmail.contains("."), trimmedEmail.first != "@", trimmedEmail.last != "." else {
            loginError = "Please enter a valid email address."
            return
        }
        guard trimmedPassword.count >= 6 else {
            loginError = "Password must be at least 6 characters."
            return
        }
        isLoggingIn = true
        loginError = nil
        Task {
            do {
                try await Auth.auth().signIn(withEmail: trimmedEmail, password: trimmedPassword)
                await MainActor.run {
                    isLoggingIn = false
                    appState.login(username: trimmedEmail.components(separatedBy: "@").first ?? trimmedEmail)
                }
            } catch let error as NSError {
                if error.domain == AuthErrorDomain, error.code == AuthErrorCode.userNotFound.rawValue {
                    do {
                        try await Auth.auth().createUser(withEmail: trimmedEmail, password: trimmedPassword)
                        await MainActor.run {
                            isLoggingIn = false
                            appState.login(username: trimmedEmail.components(separatedBy: "@").first ?? trimmedEmail)
                        }
                    } catch {
                        await MainActor.run {
                            isLoggingIn = false
                            loginError = error.localizedDescription
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoggingIn = false
                        loginError = error.localizedDescription
                    }
                }
            }
        }
    }
}

private struct LoginFieldStyle: TextFieldStyle {
    var borderColor: Color

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
