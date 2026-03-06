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

        // 2. Fetch ALL sections, then filter by questionnaire in code (avoids Reference vs string query mismatch).
        let expectedPath = "questionnaires/\(resolvedQuestionnaireId)"
        let expectedPathWithSlash = "/questionnaires/\(resolvedQuestionnaireId)"

        let allSectionsSnap = try await db.collection("sections").limit(to: 50).getDocuments()
        var sectionDocs: [QueryDocumentSnapshot] = allSectionsSnap.documents.filter { doc in
            let data = doc.data()
            guard let questionnaireValue = data["questionnaire"] else { return false }
            if let ref = questionnaireValue as? DocumentReference {
                return ref.path == expectedPath || ref.path.hasSuffix(expectedPath)
            }
            if let pathString = questionnaireValue as? String {
                return pathString == expectedPath || pathString == expectedPathWithSlash
                    || pathString.hasSuffix(expectedPath) || pathString.hasSuffix(expectedPathWithSlash)
            }
            return false
        }
        sectionDocs.sort { (a, b) in
            orderValue(a.data()["order"]) < orderValue(b.data()["order"])
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
            let requiredValue = sectionData["requiredValue"] as? String

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
                optionDocs.sort { orderValue($0.data()["order"]) < orderValue($1.data()["order"]) }
                options = optionDocs.compactMap { $0.data()["value"] as? String }
            }

            let section = QuestionnaireSection(
                type: type,
                question: question,
                label: label,
                options: options.isEmpty ? nil : options,
                hasNoneOfTheAbove: hasNoneOfTheAbove,
                required: required,
                requiredValue: requiredValue
            )
            sections.append(section)
        }

        return QuestionnaireScreen(title: title, subtitle: subtitle, sections: sections)
    }
}

private func orderValue(_ value: Any?) -> Int {
    if let i = value as? Int { return i }
    if let i64 = value as? Int64 { return Int(i64) }
    if let d = value as? Double { return Int(d) }
    return 0
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
