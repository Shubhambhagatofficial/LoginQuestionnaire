//
//  BreakView.swift
//  LoginQuestionnaireApp
//

import SwiftUI

struct BreakView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Break")
                    .font(.title)
                Text("Break screen placeholder. You can add design and behavior later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                Button("Back to Questionnaire") {
                    appState.showQuestionnaire()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.45, green: 0.35, blue: 0.85))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Break")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    BreakView()
        .environmentObject(AppState())
}
