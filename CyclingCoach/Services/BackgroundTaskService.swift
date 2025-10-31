//
//  BackgroundTaskService.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import BackgroundTasks
import SwiftData

class BackgroundTaskService {
    static let shared = BackgroundTaskService()
    
    private let checkTrainingTaskIdentifier = "com.cyclingcoach.checktraining"
    private let detectConflictsTaskIdentifier = "com.cyclingcoach.detectconflicts"
    
    private init() {}
    
    // MARK: - Registration
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: checkTrainingTaskIdentifier,
            using: nil
        ) { task in
            self.handleCheckTrainingTask(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: detectConflictsTaskIdentifier,
            using: nil
        ) { task in
            self.handleDetectConflictsTask(task: task as! BGProcessingTask)
        }
    }
    
    // MARK: - Scheduling
    
    func scheduleCheckTrainingTask() {
        let request = BGAppRefreshTaskRequest(identifier: checkTrainingTaskIdentifier)
        
        // Run every 4 hours
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled check training background task")
        } catch {
            print("❌ Could not schedule check training task: \(error)")
        }
    }
    
    func scheduleDetectConflictsTask() {
        let request = BGProcessingTaskRequest(identifier: detectConflictsTaskIdentifier)
        
        // Run daily
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 3600)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled detect conflicts background task")
        } catch {
            print("❌ Could not schedule detect conflicts task: \(error)")
        }
    }
    
    // MARK: - Task Handlers
    
    private func handleCheckTrainingTask(task: BGAppRefreshTask) {
        print("🔄 Running check training background task")
        
        // Schedule next run
        scheduleCheckTrainingTask()
        
        Task {
            do {
                let container = try ModelContainer(for: User.self, Training.self, Goal.self, Message.self, ConflictAlert.self)
                let context = ModelContext(container)
                
                // Check for missed workouts
                await checkMissedWorkouts(context: context)
                
                // Check for upcoming workouts that need motivation
                await checkUpcomingWorkouts(context: context)
                
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ Background task error: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func handleDetectConflictsTask(task: BGProcessingTask) {
        print("🔄 Running detect conflicts background task")
        
        // Schedule next run
        scheduleDetectConflictsTask()
        
        Task {
            do {
                let container = try ModelContainer(for: User.self, Training.self, Goal.self, Message.self, ConflictAlert.self)
                let context = ModelContext(container)
                
                // Sync calendar conflicts
                let descriptor = FetchDescriptor<User>()
                let users = try context.fetch(descriptor)
                
                for user in users {
                    await CalendarService.shared.syncConflicts(userId: user.id, context: context)
                }
                
                // Send notifications for new conflicts
                await notifyPendingConflicts(context: context)
                
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ Background task error: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func checkMissedWorkouts(context: ModelContext) async {
        let now = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        
        // Find workouts scheduled in the last 24 hours that weren't completed
        let descriptor = FetchDescriptor<Training>(
            predicate: #Predicate<Training> { training in
                training.date >= yesterday && training.date < now && !training.completed
            }
        )
        
        do {
            let missedTrainings = try context.fetch(descriptor)
            
            for training in missedTrainings {
                // Check if we already sent a notification for this
                let timeSinceMissed = now.timeIntervalSince(training.date)
                
                // Send notification 2 hours after scheduled time
                if timeSinceMissed >= 7200 && timeSinceMissed < 10800 {
                    try await NotificationService.shared.scheduleMissedWorkoutNotification(training: training)
                }
            }
        } catch {
            print("❌ Error checking missed workouts: \(error)")
        }
    }
    
    @MainActor
    private func checkUpcomingWorkouts(context: ModelContext) async {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        
        // Find workouts scheduled in the next 24 hours
        let descriptor = FetchDescriptor<Training>(
            predicate: #Predicate<Training> { training in
                training.date >= now && training.date < tomorrow && !training.completed
            }
        )
        
        do {
            let upcomingTrainings = try context.fetch(descriptor)
            
            for training in upcomingTrainings {
                // Schedule pre-workout motivation
                let timeUntilWorkout = training.date.timeIntervalSince(now)
                
                // If workout is 30-60 minutes away, send motivation
                if timeUntilWorkout > 1800 && timeUntilWorkout < 3600 {
                    try await NotificationService.shared.schedulePreWorkoutMotivation(training: training)
                }
            }
        } catch {
            print("❌ Error checking upcoming workouts: \(error)")
        }
    }
    
    @MainActor
    private func notifyPendingConflicts(context: ModelContext) async {
        let descriptor = FetchDescriptor<ConflictAlert>(
            predicate: #Predicate<ConflictAlert> { alert in
                alert.status == "pending" && !alert.notificationSent
            }
        )
        
        do {
            let pendingAlerts = try context.fetch(descriptor)
            
            for alert in pendingAlerts {
                try await NotificationService.shared.scheduleConflictNotification(conflict: alert)
                alert.notificationSent = true
                alert.notificationDate = Date()
            }
            
            try context.save()
        } catch {
            print("❌ Error notifying conflicts: \(error)")
        }
    }
}

