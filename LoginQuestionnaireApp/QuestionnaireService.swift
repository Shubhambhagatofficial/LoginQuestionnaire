//
//  QuestionnaireService.swift
//  LoginQuestionnaireApp
//

import Foundation
import FirebaseFirestore

/// Fetches questionnaire configuration from Firestore using your structure:
/// - questionnaires/{id} → title, subtitle
/// - sections (query by questionnaire path) → type, question, label, order, required, hasNoneOfTheAbove
/// - sectionOptions (query by section path) → value, order
final class QuestionnaireService {
    private let db = Firestore.firestore()

    /// Loads a questionnaire by document ID (e.g. "skillsQuestionnaire") and fetches its sections and options from the sections and sectionOptions collections.
    func fetchQuestionnaire(questionnaireId: String) async throws -> QuestionnaireScreen {
        // 1. Fetch questionnaire document (try by ID first, then fallback to first doc in collection)
        let questionnaireRef = db.collection("questionnaires").document(questionnaireId)
        let questionnaireSnap = try await questionnaireRef.getDocument()

        let questionnaireData: [String: Any]
        let resolvedQuestionnaireId: String

        if questionnaireSnap.exists, let data = questionnaireSnap.data() {
            questionnaireData = data
            resolvedQuestionnaireId = questionnaireId
        } else {
            // Fallback: get first document in questionnaires collection (in case document ID differs)
            let allQuestionnaires = try await db.collection("questionnaires").limit(to: 10).getDocuments()
            guard let firstDoc = allQuestionnaires.documents.first else {
                throw QuestionnaireError.noQuestionnaireFound(triedId: questionnaireId)
            }
            questionnaireData = firstDoc.data()
            resolvedQuestionnaireId = firstDoc.documentID
        }

        let title = questionnaireData["title"] as? String ?? ""
        let subtitle = questionnaireData["subtitle"] as? String ?? ""

        // 2. Fetch sections that belong to this questionnaire.
        // Query by BOTH Reference and path string, then merge – Firestore treats Reference vs string as different,
        // so some docs may match only one query (e.g. one radio section missing).
        let resolvedQuestionnaireRef = db.collection("questionnaires").document(resolvedQuestionnaireId)
        let pathWithSlash = "/questionnaires/\(resolvedQuestionnaireId)"
        let pathNoSlash = "questionnaires/\(resolvedQuestionnaireId)"

        let snapByRef = try await db.collection("sections")
            .whereField("questionnaire", isEqualTo: resolvedQuestionnaireRef)
            .getDocuments()
        let snapByPathSlash = try await db.collection("sections")
            .whereField("questionnaire", isEqualTo: pathWithSlash)
            .getDocuments()
        let snapByPathNoSlash = try await db.collection("sections")
            .whereField("questionnaire", isEqualTo: pathNoSlash)
            .getDocuments()

        var seenIds: Set<String> = []
        var sectionDocs: [QueryDocumentSnapshot] = []
        for doc in snapByRef.documents + snapByPathSlash.documents + snapByPathNoSlash.documents {
            if seenIds.insert(doc.documentID).inserted {
                sectionDocs.append(doc)
            }
        }
        sectionDocs.sort { (a, b) in
            let orderA = a.data()["order"] as? Int ?? 0
            let orderB = b.data()["order"] as? Int ?? 0
            return orderA < orderB
        }

        // 3. For each section, fetch options from sectionOptions and build QuestionnaireSection
        var sections: [QuestionnaireSection] = []
        for sectionDoc in sectionDocs {
            let sectionId = sectionDoc.documentID
            let sectionData = sectionDoc.data()
            let type = sectionData["type"] as? String ?? "radio"
            let question = sectionData["question"] as? String
            let label = sectionData["label"] as? String
            let required = sectionData["required"] as? Bool ?? true
            let hasNoneOfTheAbove = sectionData["hasNoneOfTheAbove"] as? Bool ?? false

            // Options: section may be stored as DocumentReference or path string
            let sectionRef = db.collection("sections").document(sectionId)
            let sectionPathWithSlash = "/sections/\(sectionId)"
            let sectionPathNoSlash = "sections/\(sectionId)"

            var options: [String] = []
            if type.lowercased() == "checkbox" || type.lowercased() == "radio" {
                var optionsSnap: QuerySnapshot
                let byRef = try await db.collection("sectionOptions")
                    .whereField("section", isEqualTo: sectionRef)
                    .getDocuments()
                if !byRef.documents.isEmpty {
                    optionsSnap = byRef
                } else {
                    let withSlash = try await db.collection("sectionOptions")
                        .whereField("section", isEqualTo: sectionPathWithSlash)
                        .getDocuments()
                    if !withSlash.documents.isEmpty {
                        optionsSnap = withSlash
                    } else {
                        optionsSnap = try await db.collection("sectionOptions")
                            .whereField("section", isEqualTo: sectionPathNoSlash)
                            .getDocuments()
                    }
                }
                var optionDocs = optionsSnap.documents
                optionDocs.sort { (a, b) in
                    let orderA = a.data()["order"] as? Int ?? 0
                    let orderB = b.data()["order"] as? Int ?? 0
                    return orderA < orderB
                }
                options = optionDocs.compactMap { $0.data()["value"] as? String }
            }

            let section = QuestionnaireSection(
                type: type,
                question: question,
                label: label,
                options: options.isEmpty ? nil : options,
                hasNoneOfTheAbove: hasNoneOfTheAbove,
                required: required
            )
            sections.append(section)
        }

        return QuestionnaireScreen(title: title, subtitle: subtitle, sections: sections)
    }
}

enum QuestionnaireError: LocalizedError {
    case notFound(String)
    case noQuestionnaireFound(triedId: String)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Questionnaire '\(id)' not found at path questionnaires/\(id)."
        case .noQuestionnaireFound(let triedId):
            return "No questionnaire found. Tried document '\(triedId)' and checked questionnaires collection (empty or unreadable). Check Firestore: document IDs and read rules."
        }
    }
}
