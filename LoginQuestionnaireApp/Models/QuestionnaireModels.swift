//
//  QuestionnaireModels.swift
//  LoginQuestionnaireApp
//

import Foundation

/// Top-level questionnaire screen (e.g. "Skills") loaded from Firestore.
struct QuestionnaireScreen: Codable {
    let title: String
    let subtitle: String
    let sections: [QuestionnaireSection]
}

/// One section in the questionnaire. Type is decoded from the "type" field.
struct QuestionnaireSection: Codable {
    let type: String
    let question: String?
    let label: String?
    let options: [String]?
    let hasNoneOfTheAbove: Bool?
    let required: Bool?
    /// When set (e.g. "Yes"), the user must select this exact option for Continue to be enabled. Use for radio sections.
    let requiredValue: String?

    var isRequired: Bool { required ?? true }

    /// For checkbox: question text. For radio: question. For date: use label.
    var displayText: String {
        if let q = question, !q.isEmpty { return q }
        return label ?? ""
    }
}

/// Decoded section types for type-safe rendering.
enum QuestionnaireSectionType: String {
    case checkbox
    case radio
    case date
}
