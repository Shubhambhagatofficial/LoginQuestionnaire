//
//  LoginView.swift
//  LoginQuestionnaireApp
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var hasReferralCode: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case username, password
    }

    private var canContinue: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
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
            TextField("Enter your username", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .username)
                .textFieldStyle(LoginFieldStyle(
                    borderColor: focusedField == .username ? accentColor : (!username.isEmpty ? borderFocused : borderGray)
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
        Button {
            appState.login()
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canContinue ? accentColor : disabledButtonGray)
                .foregroundStyle(canContinue ? .white : disabledTextGray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canContinue)
        .padding(.top, 8)
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
