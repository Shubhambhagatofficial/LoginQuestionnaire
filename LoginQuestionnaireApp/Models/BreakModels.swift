//
//  BreakModels.swift
//  LoginQuestionnaireApp
//

import Foundation

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
