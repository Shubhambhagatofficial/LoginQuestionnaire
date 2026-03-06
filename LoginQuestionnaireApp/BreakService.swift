//
//  BreakService.swift
//  LoginQuestionnaireApp
//

import Foundation
import FirebaseFirestore

/// Break config from server: start_time and duration.
struct BreakConfig {
    let startTime: Date
    let durationSeconds: Int
    let endedEarlyAt: Date?

    var endTime: Date {
        startTime.addingTimeInterval(TimeInterval(durationSeconds))
    }

    var remainingSeconds: Int {
        max(0, Int(endTime.timeIntervalSince(Date())))
    }

    var hasEnded: Bool {
        endedEarlyAt != nil || Date() >= endTime
    }
}

/// Fetches break config from Firestore and records when a break ends early.
final class BreakService {
    private let db = Firestore.firestore()
    private let configDocId = "current"
    private let settingsDocId = "settings"

    /// Fetch break duration (seconds) from server. Read from `breakConfig/settings` field `durationSeconds`.
    /// Used when user taps Continue to compute start/end time.
    func fetchBreakDuration() async throws -> Int? {
        let ref = db.collection("breakConfig").document(settingsDocId)
        let snap = try await ref.getDocument()
        guard snap.exists, let data = snap.data() else { return nil }
        let n = data["durationSeconds"]
        if let i = n as? Int { return i }
        if let i64 = n as? Int64 { return Int(i64) }
        if let d = n as? Double { return Int(d) }
        return nil
    }

    /// Start a break now: write `breakConfig/current` with startTime = now and duration from server.
    /// Call this when the user presses Continue on the questionnaire.
    func startBreak(durationSeconds: Int) async throws {
        let ref = db.collection("breakConfig").document(configDocId)
        try await ref.setData([
            "startTime": Timestamp(date: Date()),
            "durationSeconds": durationSeconds,
            "endedEarlyAt": FieldValue.delete()
        ], merge: true)
    }

    /// Fetch active break config from `breakConfig/current`.
    /// Document fields: startTime (Timestamp), durationSeconds (number), endedEarlyAt (Timestamp, optional).
    func fetchBreakConfig() async throws -> BreakConfig? {
        let ref = db.collection("breakConfig").document(configDocId)
        let snap = try await ref.getDocument()
        guard snap.exists, let data = snap.data() else { return nil }

        let startTime: Date
        if let ts = data["startTime"] as? Timestamp {
            startTime = ts.dateValue()
        } else if let sec = data["startTime"] as? Double {
            startTime = Date(timeIntervalSince1970: sec)
        } else {
            return nil
        }

        let durationSeconds = (data["durationSeconds"] as? Int) ?? (data["durationSeconds"] as? Int64).map(Int.init) ?? 0
        var endedEarlyAt: Date?
        if let ts = data["endedEarlyAt"] as? Timestamp {
            endedEarlyAt = ts.dateValue()
        }

        return BreakConfig(startTime: startTime, durationSeconds: durationSeconds, endedEarlyAt: endedEarlyAt)
    }

    /// Record that the break was ended early (before end time). Updates `breakConfig/current` with endedEarlyAt.
    func recordEndedEarly() async throws {
        let ref = db.collection("breakConfig").document(configDocId)
        try await ref.setData(["endedEarlyAt": Timestamp(date: Date())], merge: true)
    }
}
