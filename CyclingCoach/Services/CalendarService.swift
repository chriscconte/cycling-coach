//
//  CalendarService.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import EventKit
import SwiftData

struct CalendarConflict {
    let training: Training
    let event: EKEvent
    let conflictType: String
    let severity: Int // 1-3, 3 being most severe
}

@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = (status == .authorized || status == .fullAccess)
    }
    
    func requestAuthorization() async throws {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
        } else {
            let granted = try await eventStore.requestAccess(to: .event)
            isAuthorized = granted
        }
    }
    
    // MARK: - Fetch Events
    
    func fetchEvents(startDate: Date, endDate: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        
        return eventStore.events(matching: predicate)
    }
    
    // MARK: - Conflict Detection
    
    func detectConflicts(trainings: [Training], startDate: Date, endDate: Date) -> [CalendarConflict] {
        let events = fetchEvents(startDate: startDate, endDate: endDate)
        var conflicts: [CalendarConflict] = []
        
        for training in trainings where !training.completed {
            for event in events {
                if let conflict = checkForConflict(training: training, event: event) {
                    conflicts.append(conflict)
                }
            }
        }
        
        return conflicts
    }
    
    private func checkForConflict(training: Training, event: EKEvent) -> CalendarConflict? {
        // Skip all-day events
        guard !event.isAllDay else { return nil }
        
        // Calculate training window (assume training takes 1-2 hours)
        let trainingDuration = TimeInterval((training.plannedDurationMinutes ?? 60) * 60)
        let trainingEnd = training.date.addingTimeInterval(trainingDuration)
        
        // Check for direct overlap
        if event.startDate < trainingEnd && event.endDate > training.date {
            return CalendarConflict(
                training: training,
                event: event,
                conflictType: "overlap",
                severity: 3
            )
        }
        
        // Check if event is too close before training (within 30 min)
        let timeBefore = training.date.timeIntervalSince(event.endDate)
        if timeBefore > 0 && timeBefore < 1800 {
            return CalendarConflict(
                training: training,
                event: event,
                conflictType: "too_close_before",
                severity: 2
            )
        }
        
        // Check if event is too close after training (within 30 min)
        let timeAfter = event.startDate.timeIntervalSince(trainingEnd)
        if timeAfter > 0 && timeAfter < 1800 {
            return CalendarConflict(
                training: training,
                event: event,
                conflictType: "too_close_after",
                severity: 2
            )
        }
        
        // Check for travel time conflicts (event location suggests travel needed)
        if let location = event.structuredLocation?.title, !location.isEmpty {
            // Simple heuristic: if event has a location and is within 2 hours before training
            let timeBeforeWithTravel = training.date.timeIntervalSince(event.endDate)
            if timeBeforeWithTravel > 0 && timeBeforeWithTravel < 7200 {
                return CalendarConflict(
                    training: training,
                    event: event,
                    conflictType: "travel_required",
                    severity: 1
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Sync Conflicts to Database
    
    func syncConflicts(userId: UUID, context: ModelContext) async throws {
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: 14, to: startDate) ?? startDate
        
        // Fetch upcoming trainings
        let descriptor = FetchDescriptor<Training>(
            predicate: #Predicate<Training> { training in
                training.userId == userId && training.date >= startDate && training.date <= endDate && !training.completed
            }
        )
        
        let trainings = try context.fetch(descriptor)
        let conflicts = detectConflicts(trainings: trainings, startDate: startDate, endDate: endDate)
        
        // Update conflict alerts in database
        for conflict in conflicts {
            let alertDescriptor = FetchDescriptor<ConflictAlert>(
                predicate: #Predicate<ConflictAlert> { alert in
                    alert.trainingId == conflict.training.id && alert.calendarEventId == conflict.event.eventIdentifier
                }
            )
            
            let existingAlerts = try context.fetch(alertDescriptor)
            
            if existingAlerts.isEmpty {
                // Create new alert
                let alert = ConflictAlert(
                    userId: userId,
                    trainingId: conflict.training.id,
                    calendarEventId: conflict.event.eventIdentifier,
                    calendarEventTitle: conflict.event.title,
                    conflictDate: conflict.training.date,
                    conflictType: conflict.conflictType
                )
                context.insert(alert)
            }
        }
        
        try context.save()
    }
    
    // MARK: - Helper Methods
    
    func suggestAlternativeTime(for training: Training, avoiding events: [EKEvent]) -> Date? {
        let calendar = Calendar.current
        let trainingDay = calendar.startOfDay(for: training.date)
        
        // Try different time slots throughout the day
        let timeSlots = [
            (6, 0),   // 6 AM
            (7, 0),   // 7 AM
            (12, 0),  // 12 PM
            (17, 0),  // 5 PM
            (18, 0),  // 6 PM
            (19, 0),  // 7 PM
        ]
        
        let trainingDuration = TimeInterval((training.plannedDurationMinutes ?? 60) * 60)
        
        for (hour, minute) in timeSlots {
            if let slotDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: trainingDay) {
                let slotEnd = slotDate.addingTimeInterval(trainingDuration)
                
                // Check if this slot conflicts with any events
                var hasConflict = false
                for event in events {
                    if event.startDate < slotEnd && event.endDate > slotDate {
                        hasConflict = true
                        break
                    }
                }
                
                if !hasConflict {
                    return slotDate
                }
            }
        }
        
        return nil
    }
}

