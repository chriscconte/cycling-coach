//
//  GoalsViewModel.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import SwiftData

@MainActor
class GoalsViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var errorMessage: String?
    
    private var modelContext: ModelContext
    private var userId: UUID
    
    init(modelContext: ModelContext, userId: UUID) {
        self.modelContext = modelContext
        self.userId = userId
        loadGoals()
    }
    
    func loadGoals() {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate<Goal> { goal in
                goal.userId == self.userId
            },
            sortBy: [SortDescriptor(\Goal.createdAt, order: .reverse)]
        )
        
        do {
            goals = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading goals: \(error)")
            errorMessage = "Failed to load goals"
        }
    }
    
    func addGoal(title: String, type: String, targetDate: Date?, description: String?) {
        let goal = Goal(userId: userId, title: title, type: type)
        goal.targetDate = targetDate
        goal.description = description
        
        modelContext.insert(goal)
        goals.append(goal)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving goal: \(error)")
            errorMessage = "Failed to save goal"
        }
    }
    
    func updateGoalProgress(goal: Goal, progress: Double) {
        goal.progress = progress
        goal.lastProgressUpdate = Date()
        goal.updatedAt = Date()
        
        // Update status based on progress
        if progress >= 1.0 {
            goal.status = "completed"
        } else if progress > 0.7 {
            goal.status = "on_track"
        } else if let targetDate = goal.targetDate, targetDate < Date() {
            goal.status = "at_risk"
        }
        
        do {
            try modelContext.save()
            loadGoals()
        } catch {
            print("Error updating goal: \(error)")
            errorMessage = "Failed to update goal progress"
        }
    }
    
    func deleteGoal(_ goal: Goal) {
        modelContext.delete(goal)
        goals.removeAll { $0.id == goal.id }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting goal: \(error)")
            errorMessage = "Failed to delete goal"
        }
    }
    
    func toggleGoalStatus(_ goal: Goal) {
        if goal.status == "completed" {
            goal.status = "active"
        } else {
            goal.status = "completed"
            goal.progress = 1.0
        }
        goal.updatedAt = Date()
        
        do {
            try modelContext.save()
            loadGoals()
        } catch {
            print("Error updating goal: \(error)")
            errorMessage = "Failed to update goal status"
        }
    }
}

