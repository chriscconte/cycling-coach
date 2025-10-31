//
//  ChatViewModel.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import SwiftData

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var currentStreamingMessage: String = ""
    @Published var errorMessage: String?
    
    private var modelContext: ModelContext
    private var userId: UUID
    
    init(modelContext: ModelContext, userId: UUID) {
        self.modelContext = modelContext
        self.userId = userId
        loadMessages()
    }
    
    func loadMessages() {
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate<Message> { message in
                message.userId == self.userId
            },
            sortBy: [SortDescriptor(\Message.timestamp, order: .forward)]
        )
        
        do {
            messages = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading messages: \(error)")
            errorMessage = "Failed to load message history"
        }
    }
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let userMessage = Message(
            userId: userId,
            content: inputText,
            role: "user"
        )
        
        modelContext.insert(userMessage)
        messages.append(userMessage)
        
        let messageContent = inputText
        inputText = ""
        
        // Save immediately
        do {
            try modelContext.save()
        } catch {
            print("Error saving user message: \(error)")
        }
        
        // Get AI response
        Task {
            await getAIResponse(for: messageContent)
        }
    }
    
    private func getAIResponse(for userMessage: String) async {
        isLoading = true
        currentStreamingMessage = ""
        errorMessage = nil
        
        // Build context for AI
        let systemPrompt = await buildSystemPrompt()
        let conversationMessages = buildConversationHistory()
        
        var openAIMessages = [OpenAIChatMessage(role: "system", content: systemPrompt)]
        openAIMessages.append(contentsOf: conversationMessages)
        
        // Stream the response
        OpenAIService.shared.streamChatCompletion(
            messages: openAIMessages,
            onChunk: { [weak self] chunk in
                guard let self = self else { return }
                self.currentStreamingMessage += chunk
            },
            onComplete: { [weak self] in
                guard let self = self else { return }
                
                // Save the assistant's message
                let assistantMessage = Message(
                    userId: self.userId,
                    content: self.currentStreamingMessage,
                    role: "assistant"
                )
                
                self.modelContext.insert(assistantMessage)
                self.messages.append(assistantMessage)
                
                do {
                    try self.modelContext.save()
                } catch {
                    print("Error saving assistant message: \(error)")
                }
                
                self.currentStreamingMessage = ""
                self.isLoading = false
            },
            onError: { [weak self] error in
                guard let self = self else { return }
                self.errorMessage = error.localizedDescription
                self.currentStreamingMessage = ""
                self.isLoading = false
            }
        )
    }
    
    private func buildSystemPrompt() async -> String {
        // Fetch user data
        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.id == self.userId
            }
        )
        
        let user = try? modelContext.fetch(userDescriptor).first
        
        // Fetch active goals
        let goalsDescriptor = FetchDescriptor<Goal>(
            predicate: #Predicate<Goal> { goal in
                goal.userId == self.userId && goal.status == "active"
            },
            sortBy: [SortDescriptor(\Goal.createdAt, order: .reverse)]
        )
        
        let goals = (try? modelContext.fetch(goalsDescriptor)) ?? []
        
        // Fetch recent training (last 7 days)
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let trainingDescriptor = FetchDescriptor<Training>(
            predicate: #Predicate<Training> { training in
                training.userId == self.userId && training.date >= sevenDaysAgo
            },
            sortBy: [SortDescriptor(\Training.date, order: .reverse)]
        )
        
        let recentTraining = (try? modelContext.fetch(trainingDescriptor)) ?? []
        
        return OpenAIService.shared.buildSystemPrompt(
            user: user,
            goals: goals,
            recentTraining: recentTraining
        )
    }
    
    private func buildConversationHistory() -> [OpenAIChatMessage] {
        // Get last 10 messages for context (excluding system messages)
        let recentMessages = messages.suffix(10).filter { $0.role != "system" }
        
        return recentMessages.map { message in
            OpenAIChatMessage(role: message.role, content: message.content)
        }
    }
    
    func deleteMessage(_ message: Message) {
        modelContext.delete(message)
        messages.removeAll { $0.id == message.id }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting message: \(error)")
            errorMessage = "Failed to delete message"
        }
    }
    
    func clearConversation() {
        for message in messages {
            modelContext.delete(message)
        }
        messages.removeAll()
        
        do {
            try modelContext.save()
        } catch {
            print("Error clearing conversation: \(error)")
            errorMessage = "Failed to clear conversation"
        }
    }
}

