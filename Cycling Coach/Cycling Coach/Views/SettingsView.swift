//
//  SettingsView.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    
    @StateObject private var healthKitService = HealthKitService.shared
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var intervalsService = IntervalsICUService.shared
    @StateObject private var notificationService = NotificationService.shared
    
    @State private var openAIKey = ""
    @State private var intervalsAPIKey = ""
    @State private var showingOpenAIKeyInput = false
    @State private var showingIntervalsKeyInput = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("AI Configuration") {
                    HStack {
                        Text("OpenAI API Key")
                        Spacer()
                        if appState.hasOpenAIKey {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingOpenAIKeyInput = true
                    }
                }
                
                Section("Integrations") {
                    // intervals.icu
                    HStack {
                        VStack(alignment: .leading) {
                            Text("intervals.icu")
                                .font(.headline)
                            if intervalsService.isAuthenticated {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Not Connected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if intervalsService.isAuthenticated {
                            Button("Disconnect") {
                                intervalsService.signOut()
                            }
                            .foregroundColor(.red)
                        } else {
                            Button("Connect") {
                                showingIntervalsKeyInput = true
                            }
                        }
                    }
                }
                
                Section("Permissions") {
                    // HealthKit
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Apple Health")
                                .font(.headline)
                            Text(healthKitService.isAuthorized ? "Authorized" : "Not Authorized")
                                .font(.caption)
                                .foregroundColor(healthKitService.isAuthorized ? .green : .secondary)
                        }
                        
                        Spacer()
                        
                        if !healthKitService.isAuthorized {
                            Button("Authorize") {
                                Task {
                                    try? await healthKitService.requestAuthorization()
                                }
                            }
                        }
                    }
                    
                    // Calendar
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Calendar")
                                .font(.headline)
                            Text(calendarService.isAuthorized ? "Authorized" : "Not Authorized")
                                .font(.caption)
                                .foregroundColor(calendarService.isAuthorized ? .green : .secondary)
                        }
                        
                        Spacer()
                        
                        if !calendarService.isAuthorized {
                            Button("Authorize") {
                                Task {
                                    try? await calendarService.requestAuthorization()
                                }
                            }
                        }
                    }
                    
                    // Notifications
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Notifications")
                                .font(.headline)
                            Text(notificationService.isAuthorized ? "Authorized" : "Not Authorized")
                                .font(.caption)
                                .foregroundColor(notificationService.isAuthorized ? .green : .secondary)
                        }
                        
                        Spacer()
                        
                        if !notificationService.isAuthorized {
                            Button("Authorize") {
                                Task {
                                    try? await notificationService.requestAuthorization()
                                }
                            }
                        }
                    }
                }
                
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingOpenAIKeyInput) {
            OpenAIKeyInputView(isPresented: $showingOpenAIKeyInput, appState: appState)
        }
        .sheet(isPresented: $showingIntervalsKeyInput) {
            IntervalsKeyInputView(isPresented: $showingIntervalsKeyInput)
        }
    }
}

struct OpenAIKeyInputView: View {
    @Binding var isPresented: Bool
    let appState: AppState
    @State private var apiKey = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Get your API key from platform.openai.com")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("OpenAI Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if KeychainService.shared.saveOpenAIKey(apiKey) {
                            appState.hasOpenAIKey = true
                            isPresented = false
                        } else {
                            errorMessage = "Failed to save API key"
                        }
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
        }
    }
}

struct IntervalsKeyInputView: View {
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("intervals.icu API Key")
                } footer: {
                    Text("Get your API key from intervals.icu/settings")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("intervals.icu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        validateAndSave()
                    }
                    .disabled(apiKey.isEmpty || isValidating)
                }
            }
        }
    }
    
    private func validateAndSave() {
        isValidating = true
        errorMessage = nil
        
        Task {
            do {
                try await IntervalsICUService.shared.saveAPIKey(apiKey)
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isValidating = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .modelContainer(for: [User.self, Training.self, Goal.self, Message.self, ConflictAlert.self])
}

