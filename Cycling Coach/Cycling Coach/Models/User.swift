//
//  User.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String?
    var intervalsICUAthleteId: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Preferences
    var preferredTrainingDays: [String] // ["Monday", "Wednesday", "Friday"]
    var preferredTrainingTime: String? // "morning", "afternoon", "evening"
    var ftpWatts: Int?
    var thresholdHeartRate: Int?
    
    init(name: String, email: String? = nil) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.createdAt = Date()
        self.updatedAt = Date()
        self.preferredTrainingDays = []
    }
}

