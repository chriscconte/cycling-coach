//
//  TrainingViewModel.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import SwiftData

@MainActor
class TrainingViewModel: ObservableObject {
    @Published var trainings: [Training] = []
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    
    private var modelContext: ModelContext
    private var userId: UUID
    
    init(modelContext: ModelContext, userId: UUID) {
        self.modelContext = modelContext
        self.userId = userId
        loadTrainings()
        loadLastSyncDate()
    }
    
    func loadTrainings() {
        let descriptor = FetchDescriptor<Training>(
            predicate: #Predicate<Training> { training in
                training.userId == self.userId
            },
            sortBy: [SortDescriptor(\Training.date, order: .reverse)]
        )
        
        do {
            trainings = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading trainings: \(error)")
            errorMessage = "Failed to load trainings"
        }
    }
    
    func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastTrainingSync") as? Date
    }
    
    func syncAllSources() async {
        isSyncing = true
        errorMessage = nil
        
        do {
            // Sync intervals.icu if authenticated
            if IntervalsICUService.shared.isAuthenticated {
                try await IntervalsICUService.shared.syncTrainingData(userId: userId, context: modelContext)
            }
            
            // Sync HealthKit if authorized
            if HealthKitService.shared.isAuthorized {
                try await HealthKitService.shared.syncWorkouts(userId: userId, context: modelContext)
            }
            
            // Reload trainings
            loadTrainings()
            
            // Update last sync date
            let now = Date()
            UserDefaults.standard.set(now, forKey: "lastTrainingSync")
            lastSyncDate = now
            
            isSyncing = false
        } catch {
            print("Error syncing: \(error)")
            errorMessage = error.localizedDescription
            isSyncing = false
        }
    }
    
    func markAsCompleted(_ training: Training) {
        training.completed = true
        training.completedDate = Date()
        training.updatedAt = Date()
        
        do {
            try modelContext.save()
            loadTrainings()
        } catch {
            print("Error updating training: \(error)")
            errorMessage = "Failed to update training"
        }
    }
    
    func addNote(to training: Training, note: String) {
        training.userNotes = note
        training.updatedAt = Date()
        
        do {
            try modelContext.save()
            loadTrainings()
        } catch {
            print("Error saving note: \(error)")
            errorMessage = "Failed to save note"
        }
    }
    
    func updatePerceivedEffort(for training: Training, effort: Int) {
        training.perceivedEffort = effort
        training.updatedAt = Date()
        
        do {
            try modelContext.save()
            loadTrainings()
        } catch {
            print("Error updating effort: \(error)")
            errorMessage = "Failed to update perceived effort"
        }
    }
    
    func deleteTraining(_ training: Training) {
        modelContext.delete(training)
        trainings.removeAll { $0.id == training.id }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting training: \(error)")
            errorMessage = "Failed to delete training"
        }
    }
    
    func getUpcomingTrainings() -> [Training] {
        trainings.filter { $0.date > Date() && !$0.completed }
    }
    
    func getCompletedTrainings() -> [Training] {
        trainings.filter { $0.completed }
    }
    
    func getTrainingStats(days: Int = 30) -> TrainingStats {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let recentTrainings = trainings.filter { $0.date >= startDate && $0.completed }
        
        let totalWorkouts = recentTrainings.count
        let totalDistance = recentTrainings.compactMap { $0.actualDistanceKm }.reduce(0, +)
        let totalDuration = recentTrainings.compactMap { $0.actualDurationMinutes }.reduce(0, +)
        let totalTSS = recentTrainings.compactMap { $0.actualTSS }.reduce(0, +)
        
        return TrainingStats(
            totalWorkouts: totalWorkouts,
            totalDistanceKm: totalDistance,
            totalDurationMinutes: totalDuration,
            totalTSS: totalTSS
        )
    }
}

struct TrainingStats {
    let totalWorkouts: Int
    let totalDistanceKm: Double
    let totalDurationMinutes: Int
    let totalTSS: Int
    
    var averageDistanceKm: Double {
        totalWorkouts > 0 ? totalDistanceKm / Double(totalWorkouts) : 0
    }
    
    var averageDurationMinutes: Int {
        totalWorkouts > 0 ? totalDurationMinutes / totalWorkouts : 0
    }
    
    var totalDurationHours: Double {
        Double(totalDurationMinutes) / 60.0
    }
}

