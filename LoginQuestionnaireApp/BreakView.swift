//
//  BreakView.swift
//  LoginQuestionnaireApp
//

import SwiftUI

struct BreakView: View {
    @EnvironmentObject var appState: AppState

    @State private var breakConfig: BreakConfig?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showEndEarlyAlert = false
    @State private var breakEnded = false
    @State private var timerSeconds: Int = 0
    @State private var timerSubscription: Task<Void, Never>?

    private let service = BreakService()
    private let accentColor = Color(red: 0.45, green: 0.35, blue: 0.85)
    private let breakGradient = LinearGradient(
        colors: [Color(red: 0.4, green: 0.3, blue: 0.8), Color(red: 0.25, green: 0.35, blue: 0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private var endTimeFormatted: String {
        guard let config = breakConfig else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: config.endTime)
    }

    private var displayName: String {
        appState.currentUsername.isEmpty ? "there" : appState.currentUsername
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading break…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    VStack(spacing: 12) {
                        Text(err)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") { loadBreak() }
                            .buttonStyle(.borderedProminent)
                            .tint(accentColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if breakEnded || (breakConfig?.hasEnded == true) {
                    completionContent
                } else if breakConfig != nil {
                    activeBreakContent
                } else {
                    noBreakContent
                }
            }
            .navigationTitle("Cool Down")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button("Help") { }
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task { loadBreak() }
            .alert("Ending break early?", isPresented: $showEndEarlyAlert) {
                Button("Continue", role: .cancel) { showEndEarlyAlert = false }
                Button("End now", role: .destructive) {
                    endBreakEarly()
                }
            } message: {
                Text("Are you sure you want to end your break now? Take this time to recharge before your next task.")
            }
        }
    }

    private func loadBreak() {
        isLoading = true
        loadError = nil
        Task {
            do {
                let config = try await service.fetchBreakConfig()
                await MainActor.run {
                    if let c = config {
                        breakConfig = c
                        timerSeconds = c.remainingSeconds
                        breakEnded = c.hasEnded
                        startTimer()
                    } else {
                        breakConfig = nil
                        breakEnded = false
                        timerSubscription?.cancel()
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func startTimer() {
        timerSubscription?.cancel()
        timerSubscription = Task { @MainActor in
            while timerSeconds > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    timerSeconds = max(0, timerSeconds - 1)
                    if timerSeconds == 0 {
                        breakEnded = true
                        timerSubscription?.cancel()
                    }
                }
            }
        }
    }

    private func endBreakEarly() {
        showEndEarlyAlert = false
        Task {
            do {
                try await service.recordEndedEarly()
                await MainActor.run {
                    breakEnded = true
                    timerSubscription?.cancel()
                }
            } catch {
                await MainActor.run {
                    breakEnded = true
                    timerSubscription?.cancel()
                }
            }
        }
    }

    private var activeBreakContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi, \(displayName)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("You are on break!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                VStack(spacing: 20) {
                    Text("We value your hard work! Take this time to relax")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            .frame(width: 160, height: 160)
                        if let config = breakConfig {
                            Circle()
                                .trim(from: 0, to: progressFraction(config: config))
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 160, height: 160)
                                .rotationEffect(.degrees(-90))
                        }
                        VStack(spacing: 2) {
                            Text(timeString(from: timerSeconds))
                                .font(.system(size: 36, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Break")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }

                    Text("Break ends at \(endTimeFormatted)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))

                    Button {
                        showEndEarlyAlert = true
                    } label: {
                        Text("End my break")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(breakGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                progressSteps
            }
            .padding(.vertical, 20)
        }
    }

    private func progressFraction(config: BreakConfig) -> CGFloat {
        let total = Double(config.durationSeconds)
        let remaining = Double(timerSeconds)
        guard total > 0 else { return 0 }
        return CGFloat(1 - remaining / total)
    }

    private func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var progressSteps: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepRow(title: "Login", done: true)
            stepRow(title: "Lunch in Progress", done: breakEnded)
            stepRow(title: "Logout", done: false)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func stepRow(title: String, done: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(done ? Color.green : Color.orange, lineWidth: 2)
                    .frame(width: 24, height: 24)
                if done {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                } else if title == "Lunch in Progress" {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                }
            }
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private var completionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi, \(displayName)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("You are on break!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 4)
                            .frame(width: 120, height: 120)
                        Image(systemName: "checkmark")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("Hope you are feeling refreshed and ready to start working again")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
                .background(breakGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                progressSteps
            }
            .padding(.vertical, 20)
        }
    }

    private var noBreakContent: some View {
        VStack(spacing: 16) {
            Text("No active break")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add break config in Firestore (breakConfig/current with startTime and durationSeconds) or complete the questionnaire to start a break.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Back to Questionnaire") {
                appState.showQuestionnaire()
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    BreakView()
        .environmentObject(AppState())
}
