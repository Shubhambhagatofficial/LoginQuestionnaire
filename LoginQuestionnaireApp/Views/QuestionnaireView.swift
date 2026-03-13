//
//  QuestionnaireView.swift
//  LoginQuestionnaireApp
//

import SwiftUI

private let defaultScreenId = "skillsQuestionnaire"

private let kQuestionnaireAnswersPrefix = "LoginQuestionnaire.questionnaireAnswers."

struct QuestionnaireView: View {
    @EnvironmentObject var appState: AppState

    @State private var screen: QuestionnaireScreen?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var checkboxSelections: [Int: Set<String>] = [:]
    @State private var radioSelections: [Int: String] = [:]
    @State private var dateValues: [Int: DateInput] = [:]
    @FocusState private var focusedDateField: DateField?
    @State private var showDatePickerForSection: Int? = nil
    @State private var datePickerSelectedDate: Date = Date()

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
    private let breakService = BreakService()
    @State private var isStartingBreak = false
    @State private var breakStartError: String?
    @State private var showBreakErrorAlert = false
    private let defaultBreakDurationSeconds = 300
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
            .onDisappear { saveAnswers() }
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
                    restoreSavedAnswers()
                }
            } catch {
                await MainActor.run {
                    self.loadError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func restoreSavedAnswers() {
        let cb = UserDefaults.standard.dictionary(forKey: kQuestionnaireAnswersPrefix + defaultScreenId + ".checkbox") as? [String: [String]]
        let rad = UserDefaults.standard.dictionary(forKey: kQuestionnaireAnswersPrefix + defaultScreenId + ".radio") as? [String: String]
        let dat = UserDefaults.standard.dictionary(forKey: kQuestionnaireAnswersPrefix + defaultScreenId + ".date") as? [String: [String: String]]
        if let cb = cb {
            for (k, arr) in cb {
                if let i = Int(k) { checkboxSelections[i] = Set(arr) }
            }
        }
        if let rad = rad {
            for (k, v) in rad {
                if let i = Int(k) { radioSelections[i] = v }
            }
        }
        if let dat = dat {
            for (k, parts) in dat {
                guard let i = Int(k) else { continue }
                var d = dateValues[i] ?? DateInput()
                d.day = parts["day"] ?? ""
                d.month = parts["month"] ?? ""
                d.year = parts["year"] ?? ""
                dateValues[i] = d
            }
        }
    }

    private func saveAnswers() {
        var cb: [String: [String]] = [:]
        for (k, set) in checkboxSelections { cb[String(k)] = Array(set) }
        var rad: [String: String] = [:]
        for (k, v) in radioSelections { rad[String(k)] = v }
        var dat: [String: [String: String]] = [:]
        for (k, d) in dateValues {
            dat[String(k)] = ["day": d.day, "month": d.month, "year": d.year]
        }
        UserDefaults.standard.set(cb, forKey: kQuestionnaireAnswersPrefix + defaultScreenId + ".checkbox")
        UserDefaults.standard.set(rad, forKey: kQuestionnaireAnswersPrefix + defaultScreenId + ".radio")
        UserDefaults.standard.set(dat, forKey: kQuestionnaireAnswersPrefix + defaultScreenId + ".date")
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
        let hasValue = !(binding.day.wrappedValue.isEmpty && binding.month.wrappedValue.isEmpty && binding.year.wrappedValue.isEmpty)
        let borderColor = (showDatePickerForSection == index || hasValue) ? borderFocused : borderGray
        return VStack(alignment: .leading, spacing: 12) {
            Text(section.displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                dateField(value: binding.day.wrappedValue, placeholder: "DD", borderColor: borderColor)
                dateField(value: binding.month.wrappedValue, placeholder: "MM", borderColor: borderColor)
                dateField(value: binding.year.wrappedValue, placeholder: "YYYY", borderColor: borderColor)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedDateField = nil
                if let existing = parsedDate(from: dateValues[index] ?? DateInput()),
                   existing <= Self.datePickerMaxDate {
                    datePickerSelectedDate = existing
                } else {
                    datePickerSelectedDate = Self.datePickerMaxDate
                }
                showDatePickerForSection = index
            }
        }
        .sheet(isPresented: Binding(
            get: { showDatePickerForSection == index },
            set: { if !$0 { showDatePickerForSection = nil } }
        )) {
            datePickerSheet(sectionIndex: index)
        }
    }

    private func dateField(value: String, placeholder: String, borderColor: Color) -> some View {
        Text(value.isEmpty ? placeholder : value)
            .font(.body)
            .foregroundStyle(value.isEmpty ? Color.secondary : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func parsedDate(from d: DateInput) -> Date? {
        guard let day = Int(d.day), let month = Int(d.month), let year = Int(d.year),
              (1...31).contains(day), (1...12).contains(month), year >= 1900, year <= 2100 else { return nil }
        var comp = DateComponents()
        comp.day = day
        comp.month = month
        comp.year = year
        return Calendar.current.date(from: comp)
    }

    private static var datePickerMinDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }

    private static var datePickerMaxDate: Date {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        return cal.date(byAdding: .second, value: -1, to: startOfToday) ?? startOfToday
    }

    private func datePickerSheet(sectionIndex: Int) -> some View {
        let validRange = Self.datePickerMinDate ... Self.datePickerMaxDate
        return NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Select date",
                    selection: $datePickerSelectedDate,
                    in: validRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Select date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let cal = Calendar.current
                        let comp = cal.dateComponents([.day, .month, .year], from: datePickerSelectedDate)
                        var d = dateValues[sectionIndex] ?? DateInput()
                        d.day = String(format: "%02d", comp.day ?? 0)
                        d.month = String(format: "%02d", comp.month ?? 0)
                        d.year = String(comp.year ?? 0)
                        var updated = dateValues
                        updated[sectionIndex] = d
                        dateValues = updated
                        showDatePickerForSection = nil
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDatePickerForSection = nil
                    }
                }
            }
        }
    }

    private var continueButton: some View {
        Button {
            startBreakAndNavigate()
        } label: {
            Group {
                if isStartingBreak {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canContinue && !isStartingBreak ? accentColor : disabledButtonGray)
            .foregroundStyle(canContinue && !isStartingBreak ? .white : disabledTextGray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canContinue || isStartingBreak)
        .padding(.top, 8)
        .alert("Break could not start", isPresented: $showBreakErrorAlert) {
            Button("OK") { showBreakErrorAlert = false; breakStartError = nil }
        } message: {
            if let err = breakStartError { Text(err) }
        }
    }

    private func startBreakAndNavigate() {
        saveAnswers()
        isStartingBreak = true
        breakStartError = nil
        Task {
            do {
                let duration = try await breakService.fetchBreakDuration() ?? defaultBreakDurationSeconds
                try await breakService.startBreak(durationSeconds: duration)
                await MainActor.run {
                    isStartingBreak = false
                    appState.showBreak()
                }
            } catch {
                await MainActor.run {
                    isStartingBreak = false
                    breakStartError = error.localizedDescription
                    showBreakErrorAlert = true
                }
            }
        }
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
