//
//  Goal.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import SwiftData

@Model
class Goal {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var title: String
    var goalDescription: String?
    var type: String // "event", "fitness", "distance", "power"
    
    // Goal specifics
    var targetDate: Date?
    var targetMetric: String? // "ftp", "distance", "duration", "race_time"
    var targetValue: Double?
    var currentValue: Double?
    var unit: String? // "watts", "km", "minutes", "hours"
    
    // Event details (if type is "event")
    var eventName: String?
    var eventLocation: String?
    var eventDistance: Double?
    var eventType: String? // "road_race", "time_trial", "gran_fondo", "criterium"
    
    // Progress tracking
    var status: String // "active", "completed", "abandoned", "on_track", "at_risk"
    var progress: Double // 0.0 to 1.0
    var lastProgressUpdate: Date?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: UUID, title: String, type: String, status: String = "active") {
        self.id = UUID()
        self.userId = userId
        self.title = title
        self.type = type
        self.status = status
        self.progress = 0.0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

