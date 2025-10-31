//
//  OnboardingView.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    
    @State private var currentPage = 0
    @State private var name = ""
    @State private var openAIKey = ""
    @State private var intervalsAPIKey = ""
    @State private var hasIntervalsICU = false
    
    var body: some View {
        TabView(selection: $currentPage) {
            // Welcome
            WelcomePage(currentPage: $currentPage)
                .tag(0)
            
            // Name
            NameInputPage(name: $name, currentPage: $currentPage)
                .tag(1)
            
            // OpenAI Setup
            OpenAISetupPage(openAIKey: $openAIKey, currentPage: $currentPage, appState: appState)
                .tag(2)
            
            // Integrations
            IntegrationsPage(
                hasIntervalsICU: $hasIntervalsICU,
                intervalsAPIKey: $intervalsAPIKey,
                currentPage: $currentPage
            )
            .tag(3)
            
            // Permissions
            PermissionsPage(currentPage: $currentPage)
                .tag(4)
            
            // Complete
            CompletePage(
                name: name,
                hasIntervalsICU: hasIntervalsICU,
                intervalsAPIKey: intervalsAPIKey,
                modelContext: modelContext,
                appState: appState
            )
            .tag(5)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct WelcomePage: View {
    @Binding var currentPage: Int
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "figure.outdoor.cycle")
                .font(.system(size: 100))
                .foregroundColor(.blue)
            
            Text("Welcome to\nCycling Coach")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Your AI-powered cycling coach that helps you achieve your goals")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: { currentPage = 1 }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct NameInputPage: View {
    @Binding var name: String
    @Binding var currentPage: Int
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("What's your name?")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This helps personalize your coaching experience")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("Your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .padding(.horizontal, 32)
            
            Spacer()
            
            HStack {
                Button(action: { currentPage = 0 }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: { currentPage = 2 }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(name.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(name.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct OpenAISetupPage: View {
    @Binding var openAIKey: String
    @Binding var currentPage: Int
    let appState: AppState
    
    @State private var showingInfo = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("AI Configuration")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Enter your OpenAI API key to enable AI coaching")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            SecureField("OpenAI API Key", text: $openAIKey)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .padding(.horizontal, 32)
                .autocapitalization(.none)
                .autocorrectionDisabled()
            
            Button(action: { showingInfo = true }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("How to get an API key")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            HStack {
                Button(action: { currentPage = 1 }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: {
                    if KeychainService.shared.saveOpenAIKey(openAIKey) {
                        appState.hasOpenAIKey = true
                        currentPage = 3
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(openAIKey.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(openAIKey.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .sheet(isPresented: $showingInfo) {
            NavigationStack {
                List {
                    Section {
                        Text("1. Go to platform.openai.com")
                        Text("2. Sign in or create an account")
                        Text("3. Navigate to API keys section")
                        Text("4. Create a new API key")
                        Text("5. Copy and paste it here")
                    }
                }
                .navigationTitle("Get API Key")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingInfo = false
                        }
                    }
                }
            }
        }
    }
}

struct IntegrationsPage: View {
    @Binding var hasIntervalsICU: Bool
    @Binding var intervalsAPIKey: String
    @Binding var currentPage: Int
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "link.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Connect Your Data")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Optional: Connect intervals.icu to sync your training plan")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Toggle("I use intervals.icu", isOn: $hasIntervalsICU)
                .padding(.horizontal, 32)
            
            if hasIntervalsICU {
                SecureField("intervals.icu API Key", text: $intervalsAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .padding(.horizontal, 32)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            Spacer()
            
            HStack {
                Button(action: { currentPage = 2 }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: { currentPage = 4 }) {
                    Text(hasIntervalsICU && intervalsAPIKey.isEmpty ? "Skip" : "Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct PermissionsPage: View {
    @Binding var currentPage: Int
    
    @StateObject private var healthKitService = HealthKitService.shared
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Permissions")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("We need access to provide personalized coaching")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "heart.fill",
                    title: "Apple Health",
                    description: "Track your cycling workouts",
                    isAuthorized: healthKitService.isAuthorized,
                    action: {
                        Task {
                            try? await healthKitService.requestAuthorization()
                        }
                    }
                )
                
                PermissionRow(
                    icon: "calendar",
                    title: "Calendar",
                    description: "Detect schedule conflicts",
                    isAuthorized: calendarService.isAuthorized,
                    action: {
                        Task {
                            try? await calendarService.requestAuthorization()
                        }
                    }
                )
                
                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Stay on track with reminders",
                    isAuthorized: notificationService.isAuthorized,
                    action: {
                        Task {
                            try? await notificationService.requestAuthorization()
                        }
                    }
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            HStack {
                Button(action: { currentPage = 3 }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: { currentPage = 5 }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isAuthorized: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isAuthorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Allow") {
                    action()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct CompletePage: View {
    let name: String
    let hasIntervalsICU: Bool
    let intervalsAPIKey: String
    let modelContext: ModelContext
    let appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Welcome, \(name)! Your AI cycling coach is ready to help you achieve your goals.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                completeOnboarding()
            }) {
                Text("Start Coaching")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func completeOnboarding() {
        // Create user
        let user = User(name: name)
        modelContext.insert(user)
        
        // Save intervals.icu if provided
        if hasIntervalsICU && !intervalsAPIKey.isEmpty {
            Task {
                try? await IntervalsICUService.shared.saveAPIKey(intervalsAPIKey)
            }
        }
        
        // Save and complete onboarding
        do {
            try modelContext.save()
            appState.currentUser = user
            appState.completeOnboarding()
            
            // Schedule background tasks
            BackgroundTaskService.shared.scheduleCheckTrainingTask()
            BackgroundTaskService.shared.scheduleDetectConflictsTask()
        } catch {
            print("Error completing onboarding: \(error)")
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .modelContainer(for: [User.self, Training.self, Goal.self, Message.self, ConflictAlert.self])
}

