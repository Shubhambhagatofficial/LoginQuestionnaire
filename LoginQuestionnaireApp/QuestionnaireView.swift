//
//  QuestionnaireView.swift
//  LoginQuestionnaireApp
//

import SwiftUI

private let defaultScreenId = "skillsQuestionnaire"

struct QuestionnaireView: View {
    @EnvironmentObject var appState: AppState

    @State private var screen: QuestionnaireScreen?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var checkboxSelections: [Int: Set<String>] = [:]
    @State private var radioSelections: [Int: String] = [:]
    @State private var dateValues: [Int: DateInput] = [:]
    @FocusState private var focusedDateField: DateField?

    private struct DateInput {
        var day: String = ""
        var month: String = ""
        var year: String = ""
    }

    private enum DateField: Hashable {
        case field(sectionIndex: Int, part: Part)
        enum Part: String, Hashable { case day, month, year }
    }

    private let service = QuestionnaireService()
    private let accentColor = Color(red: 0.45, green: 0.35, blue: 0.85)
    private let disabledButtonGray = Color(red: 0.9, green: 0.9, blue: 0.92)
    private let disabledTextGray = Color(red: 0.5, green: 0.5, blue: 0.55)
    private let borderGray = Color(red: 0.88, green: 0.88, blue: 0.9)
    private let borderFocused = Color(red: 0.75, green: 0.75, blue: 0.8)

    private var canContinue: Bool {
        guard let screen = screen else { return false }
        for (index, section) in screen.sections.enumerated() where section.isRequired {
            switch section.type.lowercased() {
            case "checkbox":
                if (checkboxSelections[index] ?? []).isEmpty { return false }
            case "radio":
                guard let selected = radioSelections[index] else { return false }
                if let requiredVal = section.requiredValue, selected != requiredVal {
                    return false
                }
            case "date":
                let d = dateValues[index] ?? DateInput()
                if d.day.isEmpty || d.month.isEmpty || d.year.count < 4 { return false }
            default:
                break
            }
        }
        return true
    }

    private var progress: Double {
        guard let screen = screen, !screen.sections.isEmpty else { return 0 }
        var completed = 0
        for (index, section) in screen.sections.enumerated() {
            switch section.type.lowercased() {
            case "checkbox":
                if !(checkboxSelections[index] ?? []).isEmpty { completed += 1 }
            case "radio":
                if radioSelections[index] != nil { completed += 1 }
            case "date":
                let d = dateValues[index] ?? DateInput()
                if !d.day.isEmpty && !d.month.isEmpty && d.year.count >= 4 { completed += 1 }
            default:
                break
            }
        }
        return Double(completed) / Double(screen.sections.count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    VStack(spacing: 12) {
                        Text(err)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") { loadQuestionnaire() }
                            .buttonStyle(.borderedProminent)
                            .tint(accentColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let screen = screen {
                    questionnaireContent(screen: screen)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(screen?.title ?? "Questionnaire")
            .navigationBarTitleDisplayMode(.inline)
            .task { loadQuestionnaire() }
        }
    }

    private func loadQuestionnaire() {
        isLoading = true
        loadError = nil
        Task {
            do {
				let loaded = try await service.fetchQuestionnaire(questionnaireId: defaultScreenId)
                await MainActor.run {
                    self.screen = loaded
                    self.isLoading = false
                    for (i, section) in loaded.sections.enumerated() {
                        if section.type.lowercased() == "checkbox" {
                            checkboxSelections[i] = checkboxSelections[i] ?? []
                        }
                        if section.type.lowercased() == "date" {
                            dateValues[i] = dateValues[i] ?? DateInput()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func questionnaireContent(screen: QuestionnaireScreen) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(screen.subtitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                progressBar

                ForEach(Array(screen.sections.enumerated()), id: \.offset) { index, section in
                    sectionView(index: index, section: section)
                }

                continueButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(borderGray)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: geo.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private func sectionView(index: Int, section: QuestionnaireSection) -> some View {
        switch section.type.lowercased() {
        case "checkbox":
            checkboxSection(index: index, section: section)
        case "radio":
            radioSection(index: index, section: section)
        case "date":
            dateSection(index: index, section: section)
        default:
            EmptyView()
        }
    }

    private func checkboxSection(index: Int, section: QuestionnaireSection) -> some View {
        let options = section.options ?? []
        let hasNone = section.hasNoneOfTheAbove ?? false
        let selected = checkboxSelections[index] ?? []

        return VStack(alignment: .leading, spacing: 12) {
            Text(section.displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        if option == "None of the above" {
                            checkboxSelections[index] = ["None of the above"]
                        } else {
                            checkboxSelections[index] = (checkboxSelections[index] ?? []).filter { $0 != "None of the above" }
                            var set = checkboxSelections[index] ?? []
                            if set.contains(option) { set.remove(option) }
                            else { set.insert(option) }
                            checkboxSelections[index] = set
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selected.contains(option) ? accentColor : borderGray, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                if selected.contains(option) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(accentColor)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text(option)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                if hasNone {
                    Button {
                        checkboxSelections[index] = ["None of the above"]
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selected.contains("None of the above") ? accentColor : borderGray, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                if selected.contains("None of the above") {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(accentColor)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text("None of the above")
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func radioSection(index: Int, section: QuestionnaireSection) -> some View {
        let options = section.options ?? ["Yes", "No"]
        let selected = radioSelections[index]

        return VStack(alignment: .leading, spacing: 12) {
            Text(section.displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            HStack(spacing: 20) {
                ForEach(options, id: \.self) { option in
                    Button {
                        radioSelections[index] = option
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .stroke(selected == option ? accentColor : borderGray, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                if selected == option {
                                    Circle()
                                        .fill(accentColor)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            Text(option)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dateSection(index: Int, section: QuestionnaireSection) -> some View {
        let binding = Binding(
            get: { dateValues[index] ?? DateInput() },
            set: { dateValues[index] = $0 }
        )
        return VStack(alignment: .leading, spacing: 12) {
            Text(section.displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                TextField("DD", text: binding.day)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedDateField, equals: .field(sectionIndex: index, part: .day))
                    .textFieldStyle(QuestionnaireFieldStyle(
                        borderColor: focusedDateField == .field(sectionIndex: index, part: .day) ? accentColor : (!binding.day.wrappedValue.isEmpty ? borderFocused : borderGray)
                    ))

                TextField("MM", text: binding.month)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedDateField, equals: .field(sectionIndex: index, part: .month))
                    .textFieldStyle(QuestionnaireFieldStyle(
                        borderColor: focusedDateField == .field(sectionIndex: index, part: .month) ? accentColor : (!binding.month.wrappedValue.isEmpty ? borderFocused : borderGray)
                    ))

                TextField("YYYY", text: binding.year)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedDateField, equals: .field(sectionIndex: index, part: .year))
                    .textFieldStyle(QuestionnaireFieldStyle(
                        borderColor: focusedDateField == .field(sectionIndex: index, part: .year) ? accentColor : (!binding.year.wrappedValue.isEmpty ? borderFocused : borderGray)
                    ))
            }
        }
    }

    private var continueButton: some View {
        Button {
            appState.showBreak()
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

private struct QuestionnaireFieldStyle: TextFieldStyle {
    var borderColor: Color

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    QuestionnaireView()
        .environmentObject(AppState())
}
