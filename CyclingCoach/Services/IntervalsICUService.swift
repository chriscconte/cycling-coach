//
//  IntervalsICUService.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import AuthenticationServices
import SwiftData

// MARK: - Models

struct IntervalsICUAthlete: Codable {
    let id: String
    let name: String
    let email: String?
}

struct IntervalsICUEvent: Codable {
    let id: String
    let startDateLocal: String
    let name: String
    let description: String?
    let type: String?
    let category: String?
    let movingTime: Int?
    let distance: Double?
    let icuTrainingLoad: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case startDateLocal = "start_date_local"
        case name
        case description
        case type
        case category
        case movingTime = "moving_time"
        case distance
        case icuTrainingLoad = "icu_training_load"
    }
}

struct IntervalsICUActivity: Codable {
    let id: String
    let startDateLocal: String
    let name: String
    let type: String
    let movingTime: Int?
    let distance: Double?
    let averageHeartrate: Int?
    let maxHeartrate: Int?
    let averageWatts: Int?
    let weightedAveragePower: Int?
    let icuTrainingLoad: Int?
    let perceivedExertion: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case startDateLocal = "start_date_local"
        case name
        case type
        case movingTime = "moving_time"
        case distance
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case averageWatts = "average_watts"
        case weightedAveragePower = "weighted_average_watts"
        case icuTrainingLoad = "icu_training_load"
        case perceivedExertion = "perceived_exertion"
    }
}

// MARK: - Service

@MainActor
class IntervalsICUService: NSObject, ObservableObject {
    static let shared = IntervalsICUService()
    
    private let baseURL = "https://intervals.icu/api/v1"
    @Published var isAuthenticated = false
    @Published var currentAthlete: IntervalsICUAthlete?
    
    private var authenticationSession: ASWebAuthenticationSession?
    
    private override init() {
        super.init()
        checkAuthentication()
    }
    
    func checkAuthentication() {
        isAuthenticated = KeychainService.shared.getIntervalsICUToken() != nil
    }
    
    // MARK: - Authentication
    
    func authenticate(completion: @escaping (Result<Void, Error>) -> Void) {
        // intervals.icu uses API key authentication
        // For OAuth-like flow, we'd redirect to intervals.icu/settings to generate API key
        // For now, we'll implement direct API key entry
        
        // This would be called after user enters their API key
        completion(.success(()))
    }
    
    func saveAPIKey(_ apiKey: String) async throws {
        // Validate the API key by fetching athlete info
        let athlete = try await fetchAthlete(apiKey: apiKey)
        
        // Save to keychain if valid
        _ = KeychainService.shared.saveIntervalsICUToken(apiKey)
        self.currentAthlete = athlete
        self.isAuthenticated = true
    }
    
    func signOut() {
        _ = KeychainService.shared.deleteIntervalsICUToken()
        self.isAuthenticated = false
        self.currentAthlete = nil
    }
    
    // MARK: - API Calls
    
    private func fetchAthlete(apiKey: String) async throws -> IntervalsICUAthlete {
        guard let url = URL(string: "\(baseURL)/athlete") else {
            throw IntervalsICUError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("Basic \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntervalsICUError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw IntervalsICUError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let athlete = try JSONDecoder().decode(IntervalsICUAthlete.self, from: data)
        return athlete
    }
    
    func fetchCurrentAthlete() async throws -> IntervalsICUAthlete {
        guard let apiKey = KeychainService.shared.getIntervalsICUToken() else {
            throw IntervalsICUError.notAuthenticated
        }
        
        let athlete = try await fetchAthlete(apiKey: apiKey)
        self.currentAthlete = athlete
        return athlete
    }
    
    func fetchEvents(athleteId: String, startDate: Date, endDate: Date) async throws -> [IntervalsICUEvent] {
        guard let apiKey = KeychainService.shared.getIntervalsICUToken() else {
            throw IntervalsICUError.notAuthenticated
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)
        
        guard let url = URL(string: "\(baseURL)/athlete/\(athleteId)/events?oldest=\(startStr)&newest=\(endStr)") else {
            throw IntervalsICUError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("Basic \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntervalsICUError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw IntervalsICUError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let events = try JSONDecoder().decode([IntervalsICUEvent].self, from: data)
        return events
    }
    
    func fetchActivities(athleteId: String, startDate: Date, endDate: Date) async throws -> [IntervalsICUActivity] {
        guard let apiKey = KeychainService.shared.getIntervalsICUToken() else {
            throw IntervalsICUError.notAuthenticated
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)
        
        guard let url = URL(string: "\(baseURL)/athlete/\(athleteId)/activities?oldest=\(startStr)&newest=\(endStr)") else {
            throw IntervalsICUError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("Basic \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntervalsICUError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw IntervalsICUError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let activities = try JSONDecoder().decode([IntervalsICUActivity].self, from: data)
        return activities
    }
    
    // MARK: - Helper Methods
    
    func syncTrainingData(userId: UUID, context: ModelContext) async throws {
        guard let athlete = currentAthlete else {
            throw IntervalsICUError.notAuthenticated
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        // Fetch planned events
        let events = try await fetchEvents(athleteId: athlete.id, startDate: startDate, endDate: endDate)
        
        // Fetch completed activities
        let activities = try await fetchActivities(athleteId: athlete.id, startDate: startDate, endDate: endDate)
        
        // Convert to Training objects and save
        for event in events {
            let training = convertEventToTraining(event: event, userId: userId)
            context.insert(training)
        }
        
        // Update completed trainings with activity data
        for activity in activities where activity.type.lowercased().contains("ride") {
            // Find matching training or create new one
            if let training = findOrCreateTraining(from: activity, userId: userId, context: context) {
                updateTrainingWithActivity(training: training, activity: activity)
            }
        }
        
        try context.save()
    }
    
    private func convertEventToTraining(event: IntervalsICUEvent, userId: UUID) -> Training {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: event.startDateLocal) ?? Date()
        
        let training = Training(
            userId: userId,
            date: date,
            type: event.type ?? "unknown",
            title: event.name
        )
        
        training.description = event.description
        training.plannedDurationMinutes = event.movingTime.map { $0 / 60 }
        training.plannedDistanceKm = event.distance.map { $0 / 1000 }
        training.plannedTSS = event.icuTrainingLoad
        training.sourceIntervalsICU = true
        training.intervalsICUEventId = event.id
        
        return training
    }
    
    private func findOrCreateTraining(from activity: IntervalsICUActivity, userId: UUID, context: ModelContext) -> Training? {
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: activity.startDateLocal) else {
            return nil
        }
        
        // Try to find existing training within 4 hours
        let descriptor = FetchDescriptor<Training>(
            predicate: #Predicate<Training> { training in
                training.userId == userId
            }
        )
        
        if let trainings = try? context.fetch(descriptor) {
            let calendar = Calendar.current
            for training in trainings {
                let timeDiff = abs(training.date.timeIntervalSince(date))
                if timeDiff < 4 * 3600 { // Within 4 hours
                    return training
                }
            }
        }
        
        // Create new training if not found
        let training = Training(
            userId: userId,
            date: date,
            type: "ride",
            title: activity.name
        )
        context.insert(training)
        return training
    }
    
    private func updateTrainingWithActivity(training: Training, activity: IntervalsICUActivity) {
        training.completed = true
        training.completedDate = ISO8601DateFormatter().date(from: activity.startDateLocal)
        training.actualDurationMinutes = activity.movingTime.map { $0 / 60 }
        training.actualDistanceKm = activity.distance.map { $0 / 1000 }
        training.averageHeartRate = activity.averageHeartrate
        training.maxHeartRate = activity.maxHeartrate
        training.averagePowerWatts = activity.averageWatts
        training.normalizedPowerWatts = activity.weightedAveragePower
        training.actualTSS = activity.icuTrainingLoad
        training.perceivedEffort = activity.perceivedExertion
        training.sourceHealthKit = false
        training.updatedAt = Date()
    }
}

// MARK: - Errors

enum IntervalsICUError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with intervals.icu. Please sign in."
        case .invalidURL:
            return "Invalid URL for intervals.icu API."
        case .invalidResponse:
            return "Invalid response from intervals.icu API."
        case .httpError(let statusCode):
            return "intervals.icu API error: HTTP \(statusCode)"
        }
    }
}

