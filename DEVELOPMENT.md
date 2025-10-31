# Development Guide

## Getting Started

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later
- iOS 17.0+ device or simulator
- OpenAI API account

### Initial Setup

1. **Clone or open the project**
   ```bash
   cd /Users/chris/code/cycling-coach
   ```

2. **Open in Xcode**
   - Open `CyclingCoach` folder in Xcode
   - Select your development team in project settings
   - Ensure the correct bundle identifier is set

3. **Configure Signing & Capabilities**
   - Go to Project Settings > Signing & Capabilities
   - Enable "HealthKit" capability
   - Ensure "Background Modes" includes:
     - Background fetch
     - Background processing
   - Verify Info.plist permissions are set

4. **Build and Run**
   - Select your target device/simulator
   - Build (⌘B) and Run (⌘R)

## Project Structure

```
CyclingCoach/
├── CyclingCoachApp.swift          # App entry point
├── App/
│   ├── AppState.swift             # Global app state
├── Models/                         # SwiftData models
│   ├── User.swift
│   ├── Training.swift
│   ├── Goal.swift
│   ├── Message.swift
│   └── ConflictAlert.swift
├── Services/                       # Business logic & integrations
│   ├── OpenAIService.swift        # AI chat completions
│   ├── IntervalsICUService.swift  # Training data sync
│   ├── HealthKitService.swift     # Workout tracking
│   ├── CalendarService.swift      # Conflict detection
│   ├── NotificationService.swift  # User notifications
│   ├── BackgroundTaskService.swift # Background processing
│   └── KeychainService.swift      # Secure key storage
├── ViewModels/                    # View state management
│   ├── ChatViewModel.swift
│   ├── GoalsViewModel.swift
│   └── TrainingViewModel.swift
└── Views/                         # SwiftUI views
    ├── ChatView.swift
    ├── GoalsView.swift
    ├── TrainingView.swift
    ├── SettingsView.swift
    ├── OnboardingView.swift
    └── ContentView.swift
```

## Key Technologies

### SwiftData
- Used for local data persistence
- Models: User, Training, Goal, Message, ConflictAlert
- Automatic migration support
- Thread-safe with ModelContext

### OpenAI Integration
- GPT-4o model for conversational coaching
- Streaming responses for real-time chat
- Context-aware prompts with user data
- Error handling and retry logic

### HealthKit
- Read cycling workout data
- Track heart rate, power, distance
- Query historical workouts
- Sync with local training database

### Calendar (EventKit)
- Read calendar events
- Detect conflicts with training schedule
- Suggest alternative training times
- Background conflict monitoring

### Background Tasks
- `BGAppRefreshTask`: Check for missed workouts (every 4 hours)
- `BGProcessingTask`: Detect calendar conflicts (daily)
- Notification scheduling for follow-ups

## Testing the App

### First Time Setup
1. Launch app
2. Complete onboarding flow:
   - Enter your name
   - Add OpenAI API key
   - (Optional) Connect intervals.icu
   - Grant permissions

### Testing Features

**Chat with Coach:**
- Ask about training advice
- Discuss goals
- Get workout recommendations

**Training Tracking:**
1. Connect Apple Health
2. Do a cycling workout
3. Sync in Training tab
4. View stats and details

**Goal Management:**
1. Go to Goals tab
2. Add a cycling goal
3. Track progress
4. Update status

**Conflict Detection:**
1. Grant Calendar access
2. Add calendar event overlapping with training
3. Wait for background task or force sync
4. Receive notification

### Debugging

**View Logs:**
```swift
print() statements are used throughout
Check Xcode console for detailed logs
```

**Common Issues:**

1. **OpenAI API errors:**
   - Verify API key is correct
   - Check API quota/billing
   - Ensure internet connection

2. **HealthKit not working:**
   - Run on physical device (simulator limited)
   - Check permissions in Settings app
   - Verify entitlements file

3. **Background tasks not running:**
   - Debug scheme: Enable background fetch testing
   - Use `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.cyclingcoach.checktraining"]` in debugger

4. **Calendar access denied:**
   - Reset permissions: Settings > Privacy > Calendars
   - Restart app

## API Keys

### OpenAI API Key
- Get from: https://platform.openai.com/api-keys
- Cost: Pay-as-you-go (typically $0.01-0.03 per conversation)
- Stored in: iOS Keychain

### intervals.icu API Key
- Get from: https://intervals.icu/settings
- Free for personal use
- Stored in: iOS Keychain

## Architecture Decisions

### Why Client-Side Only?
- Simpler deployment (no backend)
- Better privacy (data stays on device)
- Faster development
- Lower costs

### Why SwiftData?
- Modern, native persistence
- Type-safe queries with macros
- Automatic CloudKit sync (future)
- Better than Core Data for new projects

### Why OpenAI GPT-4o?
- Best conversational AI available
- Good at domain expertise (coaching)
- Streaming support
- Future: Could integrate Apple Intelligence when available

## Future Enhancements

- [ ] Apple Intelligence integration when API available
- [ ] CloudKit sync for multi-device
- [ ] Workout route mapping
- [ ] Training plan generation
- [ ] Social features (coach sharing)
- [ ] Advanced analytics dashboard
- [ ] Strava integration
- [ ] Zwift integration
- [ ] Apple Watch companion app

## Contributing

When making changes:
1. Follow existing code style
2. Add comments for complex logic
3. Update this documentation
4. Test on device, not just simulator
5. Verify background tasks work
6. Check permissions are requested properly

## Resources

- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [BackgroundTasks Documentation](https://developer.apple.com/documentation/backgroundtasks)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [intervals.icu API Docs](https://forum.intervals.icu/t/api-access/609)

