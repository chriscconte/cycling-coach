//
//  CyclingCoachApp.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import SwiftUI
import SwiftData

@main
struct CyclingCoachApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Register background tasks
        BackgroundTaskService.shared.registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Schedule initial background tasks
                    BackgroundTaskService.shared.scheduleCheckTrainingTask()
                    BackgroundTaskService.shared.scheduleDetectConflictsTask()
                }
        }
        .modelContainer(for: [
            User.self,
            Training.self,
            Goal.self,
            Message.self,
            ConflictAlert.self
        ])
    }
}

