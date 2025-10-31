//
//  OpenAIService.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let stream: Bool
    let temperature: Double?
    let maxTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIChatResponse: Codable {
    let id: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: OpenAIChatMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
}

struct OpenAIStreamResponse: Codable {
    let id: String
    let choices: [StreamChoice]
    
    struct StreamChoice: Codable {
        let delta: Delta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }
    
    struct Delta: Codable {
        let role: String?
        let content: String?
    }
}

@MainActor
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    private let baseURL = "https://api.openai.com/v1"
    private let model = "gpt-4o" // Using latest model
    
    private init() {}
    
    func getChatCompletion(messages: [OpenAIChatMessage]) async throws -> String {
        guard let apiKey = KeychainService.shared.getOpenAIKey() else {
            throw OpenAIError.missingAPIKey
        }
        
        let request = OpenAIChatRequest(
            model: model,
            messages: messages,
            stream: false,
            temperature: 0.7,
            maxTokens: 1000
        )
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("OpenAI Error: \(errorMessage)")
            }
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        
        guard let message = chatResponse.choices.first?.message.content else {
            throw OpenAIError.noResponse
        }
        
        return message
    }
    
    func streamChatCompletion(
        messages: [OpenAIChatMessage],
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        Task {
            do {
                guard let apiKey = KeychainService.shared.getOpenAIKey() else {
                    throw OpenAIError.missingAPIKey
                }
                
                let request = OpenAIChatRequest(
                    model: model,
                    messages: messages,
                    stream: true,
                    temperature: 0.7,
                    maxTokens: 1500
                )
                
                var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
                urlRequest.httpMethod = "POST"
                urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = try JSONEncoder().encode(request)
                
                let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OpenAIError.invalidResponse
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
                }
                
                for try await line in bytes.lines {
                    if line.hasPrefix("data: ") {
                        let data = line.dropFirst(6)
                        
                        if data == "[DONE]" {
                            await MainActor.run {
                                onComplete()
                            }
                            break
                        }
                        
                        if let jsonData = data.data(using: .utf8),
                           let streamResponse = try? JSONDecoder().decode(OpenAIStreamResponse.self, from: jsonData),
                           let content = streamResponse.choices.first?.delta.content {
                            await MainActor.run {
                                onChunk(content)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    onError(error)
                }
            }
        }
    }
    
    func buildSystemPrompt(user: User?, goals: [Goal], recentTraining: [Training]) -> String {
        var prompt = """
        You are an expert cycling coach with years of experience training cyclists of all levels. You provide personalized, evidence-based coaching advice.
        
        Your coaching style is:
        - Encouraging and motivating
        - Data-driven but empathetic
        - Focused on long-term development
        - Attentive to recovery and injury prevention
        - Adaptive to the athlete's life circumstances
        
        """
        
        if let user = user {
            prompt += "\nAthlete Profile:\n"
            prompt += "- Name: \(user.name)\n"
            if let ftp = user.ftpWatts {
                prompt += "- FTP: \(ftp)W\n"
            }
            if let hr = user.thresholdHeartRate {
                prompt += "- Threshold HR: \(hr) bpm\n"
            }
            if !user.preferredTrainingDays.isEmpty {
                prompt += "- Preferred training days: \(user.preferredTrainingDays.joined(separator: ", "))\n"
            }
        }
        
        if !goals.isEmpty {
            prompt += "\nCurrent Goals:\n"
            for goal in goals.prefix(3) {
                prompt += "- \(goal.title)"
                if let targetDate = goal.targetDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    prompt += " (target: \(formatter.string(from: targetDate)))"
                }
                prompt += "\n"
            }
        }
        
        if !recentTraining.isEmpty {
            prompt += "\nRecent Training (last 7 days):\n"
            for training in recentTraining.prefix(5) {
                let status = training.completed ? "✓" : "✗"
                prompt += "- \(status) \(training.title)"
                if let effort = training.perceivedEffort {
                    prompt += " (RPE: \(effort)/10)"
                }
                prompt += "\n"
            }
        }
        
        prompt += """
        
        Respond naturally in conversation. Ask follow-up questions to understand the athlete better.
        When discussing workouts, consider their current fitness, goals, and life constraints.
        """
        
        return prompt
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int)
    case noResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not found. Please add it in Settings."
        case .invalidResponse:
            return "Invalid response from OpenAI API."
        case .httpError(let statusCode):
            return "OpenAI API error: HTTP \(statusCode)"
        case .noResponse:
            return "No response received from OpenAI."
        }
    }
}

