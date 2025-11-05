//
//  TrainingView.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import SwiftUI
import SwiftData

struct TrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @State private var viewModel: TrainingViewModel?
    @State private var selectedSegment = 0
    
    var body: some View {
        NavigationStack {
            if let viewModel = viewModel {
                VStack {
                    // Stats summary
                    StatsCard(stats: viewModel.getTrainingStats())
                        .padding()
                    
                    // Segment control
                    Picker("Filter", selection: $selectedSegment) {
                        Text("Upcoming").tag(0)
                        Text("Completed").tag(1)
                        Text("All").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Training list
                    List {
                        ForEach(filteredTrainings) { training in
                            NavigationLink(destination: TrainingDetailView(training: training, viewModel: viewModel)) {
                                TrainingRow(training: training)
                            }
                        }
                        .onDelete(perform: deleteTrainings)
                    }
                    .listStyle(.plain)
                }
                .navigationTitle("Training")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                await viewModel.syncAllSources()
                            }
                        }) {
                            if viewModel.isSyncing {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(viewModel.isSyncing)
                    }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            initializeViewModel()
        }
    }
    
    private var filteredTrainings: [Training] {
        guard let viewModel = viewModel else { return [] }
        switch selectedSegment {
        case 0:
            return viewModel.getUpcomingTrainings()
        case 1:
            return viewModel.getCompletedTrainings()
        default:
            return viewModel.trainings
        }
    }
    
    private func initializeViewModel() {
        guard let userId = appState.currentUser?.id else { return }
        viewModel = TrainingViewModel(modelContext: modelContext, userId: userId)
    }
    
    private func deleteTrainings(at offsets: IndexSet) {
        guard let viewModel = viewModel else { return }
        for index in offsets {
            let training = filteredTrainings[index]
            viewModel.deleteTraining(training)
        }
    }
}

struct StatsCard: View {
    let stats: TrainingStats
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Last 30 Days")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                StatItem(
                    value: "\(stats.totalWorkouts)",
                    label: "Workouts",
                    icon: "figure.outdoor.cycle"
                )
                
                StatItem(
                    value: String(format: "%.0f", stats.totalDistanceKm),
                    label: "km",
                    icon: "road.lanes"
                )
                
                StatItem(
                    value: String(format: "%.1f", stats.totalDurationHours),
                    label: "hours",
                    icon: "clock"
                )
                
                StatItem(
                    value: "\(stats.totalTSS)",
                    label: "TSS",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TrainingRow: View {
    let training: Training
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(training.title)
                    .font(.headline)
                
                Spacer()
                
                if training.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                Text(training.date, style: .date)
                    .font(.caption)
                
                if let duration = training.completed ? training.actualDurationMinutes : training.plannedDurationMinutes {
                    Divider()
                        .frame(height: 12)
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(duration) min")
                        .font(.caption)
                }
                
                if let distance = training.completed ? training.actualDistanceKm : training.plannedDistanceKm {
                    Divider()
                        .frame(height: 12)
                    Image(systemName: "road.lanes")
                        .font(.caption)
                    Text(String(format: "%.1f km", distance))
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
            
            if let description = training.trainingDescription {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TrainingDetailView: View {
    let training: Training
    let viewModel: TrainingViewModel
    
    @State private var showingNoteEditor = false
    @State private var note = ""
    @State private var perceivedEffort = 5
    
    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Date", value: training.date, format: .dateTime)
                LabeledContent("Type", value: training.type.capitalized)
                LabeledContent("Status", value: training.completed ? "Completed" : "Scheduled")
                
                if let description = training.trainingDescription {
                    LabeledContent("Description", value: description)
                }
            }
            
            if training.plannedDurationMinutes != nil || training.plannedDistanceKm != nil {
                Section("Planned") {
                    if let duration = training.plannedDurationMinutes {
                        LabeledContent("Duration", value: "\(duration) minutes")
                    }
                    if let distance = training.plannedDistanceKm {
                        LabeledContent("Distance", value: String(format: "%.1f km", distance))
                    }
                    if let tss = training.plannedTSS {
                        LabeledContent("TSS", value: "\(tss)")
                    }
                }
            }
            
            if training.completed {
                Section("Actual") {
                    if let duration = training.actualDurationMinutes {
                        LabeledContent("Duration", value: "\(duration) minutes")
                    }
                    if let distance = training.actualDistanceKm {
                        LabeledContent("Distance", value: String(format: "%.1f km", distance))
                    }
                    if let avgHR = training.averageHeartRate {
                        LabeledContent("Avg Heart Rate", value: "\(avgHR) bpm")
                    }
                    if let maxHR = training.maxHeartRate {
                        LabeledContent("Max Heart Rate", value: "\(maxHR) bpm")
                    }
                    if let avgPower = training.averagePowerWatts {
                        LabeledContent("Avg Power", value: "\(avgPower) W")
                    }
                    if let tss = training.actualTSS {
                        LabeledContent("TSS", value: "\(tss)")
                    }
                }
                
                Section("Perceived Effort") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("RPE: \(training.perceivedEffort ?? 5)")
                                .font(.headline)
                            Spacer()
                        }
                        
                        Slider(value: Binding(
                            get: { Double(training.perceivedEffort ?? 5) },
                            set: { viewModel.updatePerceivedEffort(for: training, effort: Int($0)) }
                        ), in: 1...10, step: 1)
                    }
                }
            }
            
            Section("Notes") {
                if let userNotes = training.userNotes {
                    Text(userNotes)
                        .font(.body)
                } else {
                    Text("No notes yet")
                        .foregroundColor(.secondary)
                        .font(.body)
                }
                
                Button("Add Note") {
                    note = training.userNotes ?? ""
                    showingNoteEditor = true
                }
            }
            
            if !training.completed {
                Section {
                    Button("Mark as Completed") {
                        viewModel.markAsCompleted(training)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(training.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNoteEditor) {
            NavigationStack {
                Form {
                    Section("Training Notes") {
                        TextEditor(text: $note)
                            .frame(minHeight: 200)
                    }
                }
                .navigationTitle("Edit Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingNoteEditor = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.addNote(to: training, note: note)
                            showingNoteEditor = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TrainingView()
        .environmentObject(AppState())
        .modelContainer(for: [User.self, Training.self, Goal.self, Message.self, ConflictAlert.self])
}

