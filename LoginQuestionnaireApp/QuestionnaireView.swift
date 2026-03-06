//
//  QuestionnaireView.swift
//  LoginQuestionnaireApp
//

import SwiftUI

struct QuestionnaireView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Questionnaire")
                    .font(.title)
                Text("This screen will be built from your next screenshots.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                Button("Go to Break Screen") {
                    appState.showBreak()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.45, green: 0.35, blue: 0.85))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Questionnaire")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    QuestionnaireView()
        .environmentObject(AppState())
}
