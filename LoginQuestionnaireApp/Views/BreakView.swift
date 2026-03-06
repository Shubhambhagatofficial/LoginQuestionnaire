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

    // Design colors – match reference
    private let darkBlueTop = Color(red: 0.12, green: 0.15, blue: 0.32)
    private let darkBlueBottom = Color(red: 0.18, green: 0.22, blue: 0.42)
    private let cardGradientTop = Color(red: 0.45, green: 0.32, blue: 0.78)
    private let cardGradientBottom = Color(red: 0.28, green: 0.38, blue: 0.82)
    private let endBreakRed = Color(red: 0.91, green: 0.26, blue: 0.21)
    private let progressGreen = Color(red: 0.2, green: 0.72, blue: 0.38)
    private let progressOrange = Color(red: 0.98, green: 0.58, blue: 0.22)
    private let progressGray = Color(red: 0.78, green: 0.78, blue: 0.8)
    // End-break sheet colors (pixel-perfect modal)
    private let sheetGreen = Color(red: 0.44, green: 0.62, blue: 0.44)   // muted sage #6F9E70
    private let sheetRed = Color(red: 0.72, green: 0.33, blue: 0.31)    // muted red #B8554F
    private let titleGray = Color(red: 0.2, green: 0.2, blue: 0.22)
    private let messageGray = Color(red: 0.45, green: 0.45, blue: 0.48)
    private let grabberGray = Color(red: 0.82, green: 0.82, blue: 0.84)

    private var screenGradient: LinearGradient {
        LinearGradient(
            colors: [darkBlueTop, darkBlueBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [cardGradientTop, cardGradientBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

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
                screenGradient
                    .ignoresSafeArea()
                // Subtle faded circular pattern
                GeometryReader { geo in
                    Circle()
                        .fill(Color.white.opacity(0.03))
                        .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                        .blur(radius: 60)
                        .offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.1)
                    Circle()
                        .fill(Color.white.opacity(0.02))
                        .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                        .blur(radius: 40)
                        .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.4)
                }
                .ignoresSafeArea()

                // Timer is shown only after fetching break config from server.
                if isLoading {
                    ProgressView("Loading break…")
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    VStack(spacing: 12) {
                        Text(err)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") { loadBreak() }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Cool Down")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button { } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 12))
                                Text("Help")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                        }
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(screenGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task { loadBreak() }
            .overlay { endBreakEarlySheet }
        }
    }

    // MARK: - End break early bottom sheet (pixel-perfect modal)
    @ViewBuilder
    private var endBreakEarlySheet: some View {
        if showEndEarlyAlert {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { showEndEarlyAlert = false }

                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(grabberGray)
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    Text("Ending break early?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(titleGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    Text("Are you sure you want to end your break now? Take this time to recharge before your next task.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(messageGray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)

                    HStack(spacing: 12) {
                        Button {
                            showEndEarlyAlert = false
                        } label: {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(sheetGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button {
                            endBreakEarly()
                        } label: {
                            Text("End now")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(sheetRed)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(sheetRed, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: 20,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 24
                    )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
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
                        if c.hasEnded {
                            appState.breakCompleted()
                        } else {
                            startTimer()
                        }
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
                        appState.breakCompleted()
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
                    appState.breakCompleted()
                }
            } catch {
                await MainActor.run {
                    breakEnded = true
                    timerSubscription?.cancel()
                    appState.breakCompleted()
                }
            }
        }
    }

    private var activeBreakContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header: Hi + You are on break (on dark blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi, \(displayName)!")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white)
                    Text("You are on break!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)

                // Main card: gradient, stars, message, timer ring, end time, red button
                ZStack {
                    cardGradient
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Faint star decorations
                    Image(systemName: "star.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.2))
                        .offset(x: -100, y: -20)
                    Image(systemName: "star.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.18))
                        .offset(x: 95, y: 10)

                    VStack(spacing: 20) {
                        Text("We value your hard work!\nTake this time to relax")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 8)

                        ZStack {
                            // Background ring
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 8)
                                .frame(width: 160, height: 160)
                            // Progress ring (filled = elapsed; gap bottom-right = remaining)
                            if let config = breakConfig {
                                Circle()
                                    .trim(from: 0, to: progressFraction(config: config))
                                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 160, height: 160)
                                    .rotationEffect(.degrees(-90))
                            }
                            VStack(spacing: 4) {
                                Text(timeString(from: timerSeconds))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Break")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.95))
                            }
                        }

                        Text("Break ends at \(endTimeFormatted)")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.95))

                        Button {
                            showEndEarlyAlert = true
                        } label: {
                            Text("End my break")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(endBreakRed)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 28)
                    }
                    .padding(.vertical, 28)
                }
                .padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)

                progressSteps
                    .padding(.top, 28)
            }
            .padding(.bottom, 32)
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
        VStack(alignment: .leading, spacing: 0) {
            // Login – green circle + checkmark, orange line down
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(progressGreen)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Rectangle()
                        .fill(progressOrange)
                        .frame(width: 2)
                        .frame(height: 28)
                }
                .frame(width: 24, alignment: .center)
                Text("Login")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
            }

            // Lunch in Progress – orange circle, grey line down
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(progressOrange)
                        .frame(width: 24, height: 24)
                    Rectangle()
                        .fill(progressGray)
                        .frame(width: 2)
                        .frame(height: 28)
                }
                .frame(width: 24, alignment: .center)
                Text("Lunch in Progress")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
            }

            // Logout – hollow grey circle
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .stroke(progressGray, lineWidth: 2)
                    .frame(width: 24, height: 24)
                Text("Logout")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
    }

    private var completionContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header (same as active break): Hi + You are on break!
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi, \(displayName)!")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white)
                    Text("You are on break!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)

                // Single card: gradient top (icon + message) + white bottom (progress list)
                VStack(spacing: 0) {
                    // Top half – gradient, completion icon, motivational text
                    ZStack {
                        cardGradient
                        VStack(spacing: 24) {
                            // Completion icon: white outer ring, light blue inner ring, white center, green checkmark
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 5)
                                    .frame(width: 120, height: 120)
                                Circle()
                                    .stroke(Color(red: 0.5, green: 0.65, blue: 0.95), lineWidth: 6)
                                    .frame(width: 96, height: 96)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 72, height: 72)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(progressGreen)
                            }
                            Text("Hope you are feeling refreshed and ready to start working again")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 36)
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 20
                        )
                    )

                    // Bottom half – white background, vertical progress (Login ✓, Lunch ✓, Logout empty)
                    breakEndedProgressSteps
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 20,
                                bottomTrailingRadius: 20,
                                topTrailingRadius: 0
                            )
                        )
                }
                .padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
            }
            .padding(.bottom, 32)
        }
    }

    /// Progress list for break-ended state: on white card, dark text; Login and Lunch completed (green ✓), Logout pending.
    private var breakEndedProgressSteps: some View {
        let stepText = Color(red: 0.25, green: 0.25, blue: 0.28)
        return VStack(alignment: .leading, spacing: 0) {
            // Login – green circle + checkmark, grey line down
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(progressGreen)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Rectangle()
                        .fill(progressGray)
                        .frame(width: 2)
                        .frame(height: 28)
                }
                .frame(width: 24, alignment: .center)
                Text("Login")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(stepText)
                    .padding(.top, 2)
            }

            // Lunch in Progress – green circle + checkmark (completed), grey line down
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(progressGreen)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Rectangle()
                        .fill(progressGray)
                        .frame(width: 2)
                        .frame(height: 28)
                }
                .frame(width: 24, alignment: .center)
                Text("Lunch in Progress")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(stepText)
                    .padding(.top, 2)
            }

            // Logout – hollow grey circle, pending
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .stroke(progressGray, lineWidth: 2)
                    .frame(width: 24, height: 24)
                Text("Logout")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(stepText)
                    .padding(.top, 2)
            }
        }
    }

    private var noBreakContent: some View {
        VStack(spacing: 16) {
            Text("No active break")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Add break config in Firestore (breakConfig/current with startTime and durationSeconds) or complete the questionnaire to start a break.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Back to Questionnaire") {
                appState.showQuestionnaire()
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    BreakView()
        .environmentObject(AppState())
}
