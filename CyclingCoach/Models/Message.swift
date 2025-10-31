//
//  Message.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import SwiftData

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var content: String
    var role: String // "user", "assistant", "system"
    var timestamp: Date
    
    // Context metadata
    var contextType: String? // "goal_setting", "training_review", "conflict_alert", "check_in"
    var relatedGoalId: UUID?
    var relatedTrainingId: UUID?
    
    var createdAt: Date
    
    init(userId: UUID, content: String, role: String, contextType: String? = nil) {
        self.id = UUID()
        self.userId = userId
        self.content = content
        self.role = role
        self.contextType = contextType
        self.timestamp = Date()
        self.createdAt = Date()
    }
}

