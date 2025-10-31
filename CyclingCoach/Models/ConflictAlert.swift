//
//  ConflictAlert.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import SwiftData

@Model
class ConflictAlert {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var trainingId: UUID
    var calendarEventId: String
    var calendarEventTitle: String
    
    var conflictDate: Date
    var conflictType: String // "overlap", "too_close", "travel_required"
    
    var status: String // "pending", "resolved", "ignored"
    var resolution: String? // User's chosen resolution
    var resolutionDate: Date?
    
    var notificationSent: Bool
    var notificationDate: Date?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: UUID, trainingId: UUID, calendarEventId: String, calendarEventTitle: String, conflictDate: Date, conflictType: String) {
        self.id = UUID()
        self.userId = userId
        self.trainingId = trainingId
        self.calendarEventId = calendarEventId
        self.calendarEventTitle = calendarEventTitle
        self.conflictDate = conflictDate
        self.conflictType = conflictType
        self.status = "pending"
        self.notificationSent = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

