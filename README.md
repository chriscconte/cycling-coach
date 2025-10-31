# Cycling Coach - AI-Powered iOS App

An intelligent cycling coach app that uses AI to provide personalized training guidance, track your progress, and help you achieve your cycling goals.

## Features

### 🤖 AI Coaching
- Natural language conversations with your personal cycling coach
- Personalized training advice based on your goals and data
- Smart recommendations considering your schedule and fitness level

### 📊 Data Integrations
- **intervals.icu**: Sync your training plans and completed activities
- **Apple Health**: Track cycling workouts, heart rate, and power data
- **Calendar**: Detect scheduling conflicts with your training plan

### 🎯 Goal Management
- Set and track cycling goals (events, fitness milestones, etc.)
- Visual progress tracking
- AI-powered goal recommendations

### 📱 Training Tracking
- View upcoming and completed workouts
- Detailed training statistics
- Add notes and perceived effort ratings
- Sync data from multiple sources

### 🔔 Smart Notifications
- Missed workout follow-ups
- Pre-workout motivation
- Schedule conflict alerts
- Weekly training reviews

### 🔄 Background Processing
- Automatic conflict detection
- Proactive check-ins
- Data syncing

## Requirements

- iOS 17.0 or later
- Xcode 15.0 or later
- OpenAI API key (required)
- intervals.icu account (optional)

## Setup

1. Open the project in Xcode
2. Configure your development team in project settings
3. Build and run on your device or simulator

### First Launch

On first launch, you'll be guided through:
1. Creating your profile
2. Adding your OpenAI API key
3. Connecting optional integrations (intervals.icu)
4. Granting permissions (Health, Calendar, Notifications)

### Getting API Keys

**OpenAI API Key:**
1. Go to [platform.openai.com](https://platform.openai.com)
2. Sign in or create an account
3. Navigate to API keys section
4. Create a new API key
5. Copy and paste into the app

**intervals.icu API Key:**
1. Go to [intervals.icu/settings](https://intervals.icu/settings)
2. Find the API key section
3. Copy your API key
4. Paste into the app during onboarding or in Settings

## Architecture

### Tech Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData (iOS 17+)
- **Networking**: async/await with URLSession
- **AI API**: OpenAI GPT-4o
- **Background Processing**: BackgroundTasks framework
- **Notifications**: UserNotifications framework

### Project Structure
```
CyclingCoach/
├── App/
│   ├── CyclingCoachApp.swift
│   └── AppState.swift
├── Models/
│   ├── User.swift
│   ├── Training.swift
│   ├── Goal.swift
│   ├── Message.swift
│   └── ConflictAlert.swift
├── Services/
│   ├── OpenAIService.swift
│   ├── IntervalsICUService.swift
│   ├── HealthKitService.swift
│   ├── CalendarService.swift
│   ├── NotificationService.swift
│   ├── BackgroundTaskService.swift
│   └── KeychainService.swift
├── Views/
│   ├── ChatView.swift
│   ├── GoalsView.swift
│   ├── TrainingView.swift
│   ├── SettingsView.swift
│   ├── OnboardingView.swift
│   └── ContentView.swift
└── ViewModels/
    ├── ChatViewModel.swift
    ├── GoalsViewModel.swift
    └── TrainingViewModel.swift
```

## Privacy

This app:
- Stores all data locally on your device
- Never sends health or calendar data to external servers
- Only sends necessary context to OpenAI for coaching conversations
- Stores API keys securely in the iOS Keychain
- Provides clear privacy prompts for all permissions

## Usage

### Chatting with Your Coach
1. Open the Coach tab
2. Type your questions or updates
3. Get personalized responses based on your data

### Tracking Training
1. Connect intervals.icu and/or Apple Health
2. Sync your data in the Training tab
3. View stats and progress
4. Add notes and effort ratings

### Setting Goals
1. Navigate to Goals tab
2. Tap + to add a new goal
3. Track progress over time
4. Get AI coaching aligned with your goals

### Managing Settings
1. Open Settings tab
2. Configure API keys
3. Manage integrations
4. Control permissions

## Troubleshooting

**No AI responses:**
- Verify your OpenAI API key is set correctly in Settings
- Check your internet connection
- Ensure you have API credits in your OpenAI account

**Training data not syncing:**
- Check permissions for Health and Calendar
- Verify intervals.icu API key if using that integration
- Manually trigger sync with the refresh button

**Notifications not working:**
- Go to iOS Settings > Cycling Coach > Notifications
- Ensure notifications are enabled
- Check Do Not Disturb settings

## Contributing

This is a personal project, but feedback and suggestions are welcome!

## License

Copyright © 2025. All rights reserved.

