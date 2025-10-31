//
//  ChatView.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ChatViewModel
    @State private var scrollProxy: ScrollViewProxy?
    
    init() {
        // This will be properly initialized when the view appears
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            modelContext: ModelContext(
                try! ModelContainer(for: User.self, Training.self, Goal.self, Message.self, ConflictAlert.self)
            ),
            userId: UUID()
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // Streaming message
                            if viewModel.isLoading && !viewModel.currentStreamingMessage.isEmpty {
                                MessageBubble(
                                    content: viewModel.currentStreamingMessage,
                                    role: "assistant",
                                    isStreaming: true
                                )
                                .id("streaming")
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom()
                    }
                    .onChange(of: viewModel.currentStreamingMessage) { _, _ in
                        scrollToBottom()
                    }
                }
                
                // Error message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Dismiss") {
                            viewModel.errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                }
                
                Divider()
                
                // Input area
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Message your coach...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .disabled(viewModel.isLoading)
                    
                    Button(action: {
                        viewModel.sendMessage()
                        scrollToBottom()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("Coach")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.clearConversation()
                        } label: {
                            Label("Clear Conversation", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            initializeViewModel()
        }
    }
    
    private func initializeViewModel() {
        guard let userId = appState.currentUser?.id else {
            // Create or fetch user
            let descriptor = FetchDescriptor<User>()
            if let existingUser = try? modelContext.fetch(descriptor).first {
                appState.currentUser = existingUser
                _viewModel.wrappedValue.userId = existingUser.id
            } else {
                let newUser = User(name: "Cyclist")
                modelContext.insert(newUser)
                try? modelContext.save()
                appState.currentUser = newUser
            }
            return
        }
        
        // Update view model with correct context and user
        let newViewModel = ChatViewModel(modelContext: modelContext, userId: userId)
        _viewModel.wrappedValue = newViewModel
    }
    
    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if viewModel.isLoading {
                scrollProxy?.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = viewModel.messages.last {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

struct MessageBubble: View {
    let content: String
    let role: String
    let isStreaming: Bool
    
    init(message: Message) {
        self.content = message.content
        self.role = message.role
        self.isStreaming = false
    }
    
    init(content: String, role: String, isStreaming: Bool = false) {
        self.content = content
        self.role = role
        self.isStreaming = isStreaming
    }
    
    var body: some View {
        HStack {
            if role == "user" {
                Spacer()
            }
            
            VStack(alignment: role == "user" ? .trailing : .leading, spacing: 4) {
                Text(content)
                    .padding(12)
                    .background(role == "user" ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(role == "user" ? .white : .primary)
                    .cornerRadius(16)
                
                if isStreaming {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 6, height: 6)
                                .opacity(0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isStreaming
                                )
                        }
                    }
                    .padding(.leading, 12)
                }
            }
            
            if role == "assistant" {
                Spacer()
            }
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(AppState())
        .modelContainer(for: [User.self, Training.self, Goal.self, Message.self, ConflictAlert.self])
}

