//
//  NotificationService.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import UserNotifications
import SwiftData

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            await MainActor.run {
                isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestAuthorization() async throws {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        isAuthorized = granted
        
        if granted {
            // Register delegate for handling notifications
            await notificationCenter.setNotificationCategories(createNotificationCategories())
        }
    }
    
    private func createNotificationCategories() -> Set<UNNotificationCategory> {
        // Action for missed workout notification
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark as Complete",
            options: .foreground
        )
        
        let rescheduleAction = UNNotificationAction(
            identifier: "RESCHEDULE_ACTION",
            title: "Reschedule",
            options: .foreground
        )
        
        let missedWorkoutCategory = UNNotificationCategory(
            identifier: "MISSED_WORKOUT",
            actions: [completeAction, rescheduleAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Action for conflict alert
        let viewConflictAction = UNNotificationAction(
            identifier: "VIEW_CONFLICT_ACTION",
            title: "View Details",
            options: .foreground
        )
        
        let conflictCategory = UNNotificationCategory(
            identifier: "TRAINING_CONFLICT",
            actions: [viewConflictAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Action for check-in
        let respondAction = UNNotificationAction(
            identifier: "RESPOND_ACTION",
            title: "Respond",
            options: .foreground
        )
        
        let checkInCategory = UNNotificationCategory(
            identifier: "CHECK_IN",
            actions: [respondAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        return [missedWorkoutCategory, conflictCategory, checkInCategory]
    }
    
    // MARK: - Schedule Notifications
    
    func scheduleMissedWorkoutNotification(training: Training) async throws {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Missed Workout"
        content.body = "Hey! I noticed you didn't complete \(training.title). Everything okay?"
        content.sound = .default
        content.categoryIdentifier = "MISSED_WORKOUT"
        content.userInfo = [
            "type": "missed_workout",
            "trainingId": training.id.uuidString
        ]
        
        // Schedule for 2 hours after planned workout time
        let triggerDate = training.date.addingTimeInterval(2 * 3600)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "missed_workout_\(training.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    func scheduleConflictNotification(conflict: ConflictAlert) async throws {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Training Schedule Conflict"
        content.body = "Your calendar event '\(conflict.calendarEventTitle)' conflicts with your training. Would you like to reschedule?"
        content.sound = .default
        content.categoryIdentifier = "TRAINING_CONFLICT"
        content.userInfo = [
            "type": "conflict",
            "conflictId": conflict.id.uuidString,
            "trainingId": conflict.trainingId.uuidString
        ]
        
        // Notify 24 hours before the conflict
        let triggerDate = conflict.conflictDate.addingTimeInterval(-24 * 3600)
        
        // Only schedule if trigger is in the future
        guard triggerDate > Date() else { return }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "conflict_\(conflict.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    func scheduleCheckInNotification(userId: UUID, message: String, date: Date) async throws {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Your Cycling Coach"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "CHECK_IN"
        content.userInfo = [
            "type": "check_in",
            "userId": userId.uuidString
        ]
        
        guard date > Date() else { return }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "check_in_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    func scheduleWeeklyReview(userId: UUID, weekDay: Int = 1, hour: Int = 18) async throws {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Training Review"
        content.body = "Let's review your training week! How did it go?"
        content.sound = .default
        content.categoryIdentifier = "CHECK_IN"
        content.userInfo = [
            "type": "weekly_review",
            "userId": userId.uuidString
        ]
        
        var components = DateComponents()
        components.weekday = weekDay // 1 = Sunday, 2 = Monday, etc.
        components.hour = hour
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "weekly_review_\(userId.uuidString)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    func schedulePreWorkoutMotivation(training: Training) async throws {
        guard isAuthorized else { return }
        
        let messages = [
            "Time to ride! 🚴 Your workout today: \(training.title)",
            "Let's do this! Your training session is coming up: \(training.title)",
            "Ready to crush it? \(training.title) is scheduled soon!",
            "Get pumped! Your workout \(training.title) starts soon."
        ]
        
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Workout"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.userInfo = [
            "type": "pre_workout",
            "trainingId": training.id.uuidString
        ]
        
        // Notify 30 minutes before workout
        let triggerDate = training.date.addingTimeInterval(-30 * 60)
        
        guard triggerDate > Date() else { return }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "pre_workout_\(training.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    // MARK: - Cancel Notifications
    
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    func cancelNotificationsForTraining(trainingId: UUID) {
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.filter { request in
                if let trainingIdStr = request.content.userInfo["trainingId"] as? String,
                   trainingIdStr == trainingId.uuidString {
                    return true
                }
                return false
            }.map { $0.identifier }
            
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
}

