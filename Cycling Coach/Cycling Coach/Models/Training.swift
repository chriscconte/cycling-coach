//
//  Training.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import SwiftData

@Model
class Training {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var date: Date
    var scheduledDate: Date?
    var type: String // "endurance", "interval", "tempo", "recovery", "race"
    var title: String
    var trainingDescription: String?
    
    // Planned workout details
    var plannedDurationMinutes: Int?
    var plannedDistanceKm: Double?
    var plannedIntensity: String? // "easy", "moderate", "hard", "max"
    var plannedTSS: Int? // Training Stress Score
    
    // Actual workout data
    var completed: Bool
    var completedDate: Date?
    var actualDurationMinutes: Int?
    var actualDistanceKm: Double?
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var averagePowerWatts: Int?
    var normalizedPowerWatts: Int?
    var actualTSS: Int?
    var perceivedEffort: Int? // 1-10 scale
    
    // Source tracking
    var sourceIntervalsICU: Bool
    var intervalsICUEventId: String?
    var sourceHealthKit: Bool
    var healthKitWorkoutId: String?
    
    // User notes
    var userNotes: String?
    var coachingFeedback: String?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: UUID, date: Date, type: String, title: String) {
        self.id = UUID()
        self.userId = userId
        self.date = date
        self.type = type
        self.title = title
        self.completed = false
        self.sourceIntervalsICU = false
        self.sourceHealthKit = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

