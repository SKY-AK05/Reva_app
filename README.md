# Reva Mobile App

## Backend AI Proxy (OpenRouter Claude 3 Sonnet)
A minimal Node.js/Express backend is included in the `backend/` directory. It proxies chat requests from the Flutter app to the OpenRouter Claude 3 Sonnet model, keeping your API key secure.

- Start the backend: see `backend/README.md` for setup and deployment instructions.
- The Flutter app will continue to send chat messages to `/api/v1/chat` as before.

---

Reva is an AI-powered productivity assistant mobile application built with Flutter. This app serves as a companion to the web application, providing users with a native mobile experience while maintaining full feature parity and real-time synchronization.

## Features

- **Chat-first Interface**: Natural language interaction with AI assistant
- **Task Management**: Create, view, and manage tasks
- **Expense Tracking**: Log and track expenses with AI assistance
- **Reminder System**: Set reminders with push notifications
- **Real-time Sync**: Instant synchronization with web app via Supabase
- **Offline Support**: View cached data when offline
- **Cross-platform**: Supports both Android and iOS

## Tech Stack

- **Framework**: Flutter 3.32.6
- **State Management**: Riverpod
- **Backend**: Supabase (Database, Auth, Realtime)
- **Push Notifications**: Supabase Edge Functions
- **Local Storage**: SQLite + Flutter Secure Storage
- **HTTP Client**: Dio
- **Navigation**: GoRouter

## Project Structure

```
lib/
├── core/
│   ├── config/          # App configuration
│   ├── constants/       # App constants
│   └── theme/          # App theming
├── models/             # Data models
├── services/           # Business logic services
│   ├── auth/          # Authentication services
│   ├── chat/          # Chat/AI services
│   ├── cache/         # Caching services
│   ├── sync/          # Data synchronization
│   └── notification/  # Push notification services
├── providers/          # Riverpod providers
├── screens/           # UI screens
│   ├── auth/         # Authentication screens
│   ├── chat/         # Chat interface
│   ├── tasks/        # Task management
│   ├── expenses/     # Expense tracking
│   └── reminders/    # Reminder management
├── widgets/          # Reusable UI components
└── utils/           # Utility functions
```

## Setup Instructions

### Prerequisites

1. Flutter SDK 3.32.6 or higher
2. Dart SDK 3.8.1 or higher
3. Android Studio (for Android development)
4. Xcode (for iOS development, macOS only)

### Installation

1. Clone the repository
2. Navigate to the project directory:
   ```bash
   cd reva_mobile_app
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Set up environment variables:
   - Copy `env.sample` to `.env`:
     ```bash
     cp env.sample .env
     ```
   - Update the values in `.env` with your actual configuration:
     ```
     SUPABASE_URL=https://jjjrstmydcvimasfkdxw.supabase.co
     SUPABASE_ANON_KEY=your-anon-key-here
     API_BASE_URL=https://reva-backend-8bcr.onrender.com/api/v1/chat
     ENVIRONMENT=development
     ```
   - Get your Supabase credentials from your project dashboard:
     - Go to [supabase.com](https://supabase.com)
     - Select your project
     - Go to Settings → API
     - Copy Project URL and anon/public key

### Running the App

#### Development Mode
```bash
flutter run --dart-define-from-file=.env
```

#### Debug Build
```bash
flutter run --debug --dart-define=ENVIRONMENT=development
```

#### Release Build
```bash
flutter run --release --dart-define=ENVIRONMENT=production
```

### Building for Production

#### Android
```bash
# Debug APK
flutter build apk --debug --flavor dev

# Release APK
flutter build apk --release --flavor prod
```

#### iOS
```bash
# Debug build
flutter build ios --debug --flavor dev

# Release build
flutter build ios --release --flavor prod
```

### Testing

Run all tests:
```bash
flutter test
```

Run specific test file:
```bash
flutter test test/widget_test.dart
```

### Code Analysis

Check for issues:
```bash
flutter analyze
```

Format code:
```bash
flutter format .
```

## Configuration

### Supabase Setup

1. Create a new Supabase project
2. Set up the database schema (tables for tasks, expenses, reminders, chat_messages)
3. Configure Row Level Security (RLS) policies
4. Enable Realtime for required tables
5. Update environment variables with your Supabase URL and anon key

### Push Notifications Setup (using Supabase)

1. Set up Supabase Edge Functions for push notifications
2. Configure push notification triggers in your Supabase project
3. Enable real-time subscriptions for reminder notifications
4. No additional configuration files needed - everything is handled through Supabase

## Build Variants

The app supports multiple build variants:

- **dev**: Development environment with debug features
- **stage**: Staging environment for testing
- **prod**: Production environment

Each variant can have different:
- API endpoints
- Database configurations
- Feature flags
- App identifiers

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and ensure they pass
5. Submit a pull request

## License

This project is licensed under the MIT License."# Reva_app" 
