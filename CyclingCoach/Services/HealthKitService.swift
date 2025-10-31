//
//  HealthKitService.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import HealthKit
import SwiftData

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .cyclingPower)!,
            HKObjectType.quantityType(forIdentifier: .cyclingSpeed)!,
            HKObjectType.quantityType(forIdentifier: .cyclingCadence)!
        ]
        
        // Check if we have authorization for all types
        var allAuthorized = true
        for type in typesToRead {
            let status = healthStore.authorizationStatus(for: type)
            if status != .sharingAuthorized {
                allAuthorized = false
                break
            }
        }
        
        isAuthorized = allAuthorized
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .cyclingPower)!,
            HKObjectType.quantityType(forIdentifier: .cyclingSpeed)!,
            HKObjectType.quantityType(forIdentifier: .cyclingCadence)!
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        checkAuthorization()
    }
    
    // MARK: - Fetch Workouts
    
    func fetchCyclingWorkouts(startDate: Date, endDate: Date) async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .cycling)
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: compoundPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchHeartRateData(for workout: HKWorkout) async throws -> (average: Double?, max: Double?) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax]
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let avgQuantity = statistics?.averageQuantity()
                let maxQuantity = statistics?.maximumQuantity()
                
                let avgBPM = avgQuantity?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let maxBPM = maxQuantity?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                
                continuation.resume(returning: (avgBPM, maxBPM))
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchPowerData(for workout: HKWorkout) async throws -> (average: Double?, normalized: Double?) {
        guard let powerType = HKQuantityType.quantityType(forIdentifier: .cyclingPower) else {
            return (nil, nil)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: powerType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage]
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let avgQuantity = statistics?.averageQuantity()
                let avgWatts = avgQuantity?.doubleValue(for: .watt())
                
                // Note: Normalized power requires more complex calculation
                // For now, we'll use average as an approximation
                continuation.resume(returning: (avgWatts, avgWatts))
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Sync to Training Database
    
    func syncWorkouts(userId: UUID, context: ModelContext) async throws {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let workouts = try await fetchCyclingWorkouts(startDate: startDate, endDate: endDate)
        
        for workout in workouts {
            // Check if workout already exists
            let workoutId = workout.uuid.uuidString
            let descriptor = FetchDescriptor<Training>(
                predicate: #Predicate<Training> { training in
                    training.healthKitWorkoutId == workoutId
                }
            )
            
            let existingTrainings = try context.fetch(descriptor)
            
            if existingTrainings.isEmpty {
                // Create new training from workout
                let training = try await convertWorkoutToTraining(workout: workout, userId: userId)
                context.insert(training)
            } else if let training = existingTrainings.first {
                // Update existing training
                try await updateTrainingWithWorkout(training: training, workout: workout)
            }
        }
        
        try context.save()
    }
    
    private func convertWorkoutToTraining(workout: HKWorkout, userId: UUID) async throws -> Training {
        let training = Training(
            userId: userId,
            date: workout.startDate,
            type: workoutTypeToString(workout.workoutActivityType),
            title: workout.workoutActivityType == .cycling ? "Cycling Workout" : "Indoor Cycling"
        )
        
        training.completed = true
        training.completedDate = workout.endDate
        training.actualDurationMinutes = Int(workout.duration / 60)
        
        if let distance = workout.totalDistance {
            training.actualDistanceKm = distance.doubleValue(for: .meterUnit(with: .kilo))
        }
        
        // Fetch heart rate data
        let (avgHR, maxHR) = try await fetchHeartRateData(for: workout)
        training.averageHeartRate = avgHR.map { Int($0) }
        training.maxHeartRate = maxHR.map { Int($0) }
        
        // Fetch power data
        let (avgPower, normalizedPower) = try await fetchPowerData(for: workout)
        training.averagePowerWatts = avgPower.map { Int($0) }
        training.normalizedPowerWatts = normalizedPower.map { Int($0) }
        
        training.sourceHealthKit = true
        training.healthKitWorkoutId = workout.uuid.uuidString
        
        return training
    }
    
    private func updateTrainingWithWorkout(training: Training, workout: HKWorkout) async throws {
        training.completed = true
        training.completedDate = workout.endDate
        training.actualDurationMinutes = Int(workout.duration / 60)
        
        if let distance = workout.totalDistance {
            training.actualDistanceKm = distance.doubleValue(for: .meterUnit(with: .kilo))
        }
        
        let (avgHR, maxHR) = try await fetchHeartRateData(for: workout)
        training.averageHeartRate = avgHR.map { Int($0) }
        training.maxHeartRate = maxHR.map { Int($0) }
        
        let (avgPower, normalizedPower) = try await fetchPowerData(for: workout)
        training.averagePowerWatts = avgPower.map { Int($0) }
        training.normalizedPowerWatts = normalizedPower.map { Int($0) }
        
        training.updatedAt = Date()
    }
    
    private func workoutTypeToString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .cycling:
            return "outdoor_ride"
        case .cycling:
            return "indoor_ride"
        default:
            return "ride"
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device."
        case .notAuthorized:
            return "HealthKit access not authorized. Please enable in Settings."
        }
    }
}

