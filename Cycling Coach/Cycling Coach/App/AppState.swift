//
//  AppState.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isOnboarded: Bool = false
    @Published var hasOpenAIKey: Bool = false
    @Published var hasIntervalsICU: Bool = false
    @Published var hasHealthKitAccess: Bool = false
    @Published var hasCalendarAccess: Bool = false
    @Published var currentUser: User?
    
    init() {
        loadOnboardingState()
    }
    
    func loadOnboardingState() {
        isOnboarded = UserDefaults.standard.bool(forKey: "isOnboarded")
        hasOpenAIKey = KeychainService.shared.getOpenAIKey() != nil
    }
    
    func completeOnboarding() {
        isOnboarded = true
        UserDefaults.standard.set(true, forKey: "isOnboarded")
    }
}

