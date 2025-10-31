//
//  GoalsView.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: GoalsViewModel
    @State private var showingAddGoal = false
    
    init() {
        _viewModel = StateObject(wrappedValue: GoalsViewModel(
            modelContext: ModelContext(
                try! ModelContainer(for: User.self, Training.self, Goal.self, Message.self, ConflictAlert.self)
            ),
            userId: UUID()
        ))
    }
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.goals.isEmpty {
                    ContentUnavailableView(
                        "No Goals Yet",
                        systemImage: "target",
                        description: Text("Add your first cycling goal to get started!")
                    )
                } else {
                    ForEach(viewModel.goals) { goal in
                        GoalRow(goal: goal, viewModel: viewModel)
                    }
                    .onDelete(perform: deleteGoals)
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGoal = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView(viewModel: viewModel)
            }
        }
        .onAppear {
            initializeViewModel()
        }
    }
    
    private func initializeViewModel() {
        guard let userId = appState.currentUser?.id else { return }
        let newViewModel = GoalsViewModel(modelContext: modelContext, userId: userId)
        _viewModel.wrappedValue = newViewModel
    }
    
    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let goal = viewModel.goals[index]
            viewModel.deleteGoal(goal)
        }
    }
}

struct GoalRow: View {
    let goal: Goal
    let viewModel: GoalsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                    
                    if let description = goal.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                StatusBadge(status: goal.status)
            }
            
            if let targetDate = goal.targetDate {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(targetDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let daysRemaining = daysUntilTarget(targetDate) {
                        Text("\(daysRemaining) days")
                            .font(.caption)
                            .foregroundColor(daysRemaining < 30 ? .orange : .secondary)
                    }
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(goal.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: goal.progress)
                    .tint(progressColor(for: goal))
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteGoal(goal)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                viewModel.toggleGoalStatus(goal)
            } label: {
                Label(
                    goal.status == "completed" ? "Reopen" : "Complete",
                    systemImage: goal.status == "completed" ? "arrow.counterclockwise" : "checkmark"
                )
            }
            .tint(.blue)
        }
    }
    
    private func daysUntilTarget(_ date: Date) -> Int? {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: date).day
        return days
    }
    
    private func progressColor(for goal: Goal) -> Color {
        switch goal.status {
        case "completed":
            return .green
        case "on_track":
            return .blue
        case "at_risk":
            return .orange
        default:
            return .gray
        }
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch status {
        case "completed":
            return .green
        case "on_track":
            return .blue
        case "at_risk":
            return .orange
        case "abandoned":
            return .red
        default:
            return .gray
        }
    }
}

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: GoalsViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var type = "event"
    @State private var targetDate = Date().addingTimeInterval(90 * 24 * 3600) // 90 days
    @State private var hasTargetDate = true
    
    let goalTypes = ["event", "fitness", "distance", "power"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Goal Title", text: $title)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Type", selection: $type) {
                        ForEach(goalTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                }
                
                Section("Target") {
                    Toggle("Set Target Date", isOn: $hasTargetDate)
                    
                    if hasTargetDate {
                        DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addGoal(
                            title: title,
                            type: type,
                            targetDate: hasTargetDate ? targetDate : nil,
                            description: description.isEmpty ? nil : description
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    GoalsView()
        .environmentObject(AppState())
        .modelContainer(for: [User.self, Training.self, Goal.self, Message.self, ConflictAlert.self])
}

