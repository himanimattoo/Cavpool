# UVA Carpool Flutter App

The mobile application for the UVA Carpool platform, built with Flutter for cross-platform iOS and Android support.

## Overview

This Flutter app provides a comprehensive ride-sharing platform specifically designed for UVA students. The app features secure authentication, interactive maps, route planning, and user profile management.

## Features

### Implemented Features

#### Authentication & User Management
- UVA @virginia.edu email validation with Google Sign-In
- User profile creation and editing
- Photo upload with Firebase Storage integration
- Secure session management

#### Google Maps Integration
- Interactive Google Maps with real-time location tracking
- Location permissions handling for iOS and Android
- Current location detection and display
- Map controls and user interaction

#### Address Search & Route Planning
- Uber-style address search interface
- Google Places API autocomplete with real-time suggestions
- Custom route calculation between any two addresses
- Visual route display with:
  - Polylines showing the route path
  - Start/end markers with custom colors
  - Route information cards (distance, duration)
  - Map camera fitting to show entire route

#### Navigation & UI
- Bottom navigation with multiple tabs (Rides, Requests, Routes, Profile)
- Material Design 3 with UVA branding
- Responsive layouts that work on different screen sizes
- Proper loading states and error handling

### Planned Features
- Ride posting and browsing system
- Real-time messaging
- Payment integration
- Push notifications
- Safety features

## Architecture

### State Management
- **Provider Pattern**: Used for app-wide state management
- **Key Providers**:
  - `AuthProvider`: Handles authentication state and user sessions
  - `UserProfileProvider`: Manages user profile data and updates
  - `RoutesProvider`: Controls map state, routes, and location services

### Service Layer
- **LocationService**: GPS location access and permissions
- **RoutesService**: Route calculation and map marker management
- **AddressSearchService**: Google Places API integration and geocoding
- **AuthService**: Firebase authentication wrapper

### UI Components
- **Screens**: Organized by feature (auth/, home/, profile/, routes/)
- **Widgets**: Reusable components (AddressSearchWidget)
- **Providers**: State management classes
- **Services**: Business logic and API integrations

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── models/                      # Data models
│   └── user_model.dart
├── providers/                   # State management
│   ├── auth_provider.dart
│   ├── user_profile_provider.dart
│   └── routes_provider.dart
├── services/                    # Business logic
│   ├── auth_service.dart
│   ├── location_service.dart
│   ├── routes_service.dart
│   └── address_search_service.dart
├── screens/                     # UI screens
│   ├── auth/
│   ├── home/
│   ├── profile/
│   └── routes/
└── widgets/                     # Reusable components
    └── address_search_widget.dart
```

## Configuration

### Environment Variables
The app uses environment variables for secure API key management:
- **Create `.env` file**: Copy from project root `.env.example`
- **Add Google Maps API Key**: 
  ```
  GOOGLE_MAPS_API_KEY=your_api_key_here
  ```
- **Firebase Config**: Add Firebase credentials to `.env`

### Firebase Setup
The app is configured with Firebase for:
- **Authentication**: Google Sign-In provider
- **Firestore**: User data and app content storage
- **Storage**: User profile photos and documents

Required files:
- `android/app/google-services.json` (Android)
- `ios/Runner/GoogleService-Info.plist` (iOS)

### Google Maps API
Google Maps integration requires API keys in multiple places:
- **Environment file**: `.env` for API calls (Directions, Places, Geocoding)
- **Android**: `android/app/src/main/AndroidManifest.xml` for native maps
- **iOS**: `ios/Runner/AppDelegate.swift` for native maps

Required APIs:
- Maps SDK for Android/iOS
- Places API
- Geocoding API
- Directions API

## Dependencies

### Core Flutter & Firebase
```yaml
firebase_core: ^4.1.0           # Firebase SDK core
firebase_auth: ^6.0.2           # Authentication
cloud_firestore: ^6.0.1         # Database
firebase_storage: ^13.0.1       # File storage
```

### Google Services
```yaml
google_sign_in: ^7.2.0          # Google authentication
google_maps_flutter: ^2.10.0    # Maps integration
google_fonts: ^6.2.1            # UVA typography
```

### Location & Navigation
```yaml
geolocator: ^14.0.2             # GPS location access
geocoding: ^3.0.0               # Address/coordinate conversion
location: ^8.0.1                # Location services
```

### State Management & UI
```yaml
provider: ^6.1.2                # State management
go_router: ^16.2.1              # Navigation routing
image_picker: ^1.1.2            # Photo selection
logger: ^2.4.0                  # Logging framework
```

### HTTP & Utilities
```yaml
http: ^1.1.0                    # API requests
```

## Development

### Running the App
```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run in debug mode with hot reload
flutter run --debug

# Build for release
flutter build apk                # Android
flutter build ios               # iOS
```

### Code Quality
- **Linting**: Configured with `flutter_lints` for code quality
- **Analysis**: Custom analysis options in `analysis_options.yaml`
- **Testing**: Unit tests in `test/` directory

### Platform-Specific Notes

#### Android
- Minimum SDK: 21 (Android 5.0)
- Permissions configured in `AndroidManifest.xml`
- Google Services configuration via `google-services.json`

#### iOS
- Minimum deployment target: iOS 12.0
- Location permissions in `Info.plist`
- Google Services configuration via `GoogleService-Info.plist`

## Debugging

### Common Issues
1. **Location permissions not working**: Check platform-specific permission configurations
2. **Google Maps not displaying**: Verify API keys are correctly configured
3. **Firebase authentication errors**: Ensure Firebase project is properly set up
4. **Build failures**: Run `flutter clean && flutter pub get`

### Logging
The app uses the `logger` package for comprehensive logging:
- Info logs for successful operations
- Warning logs for permission issues
- Error logs for API failures and exceptions

## Security

- **API Keys**: Configured in platform-specific files (not in version control)
- **Authentication**: Secure Firebase Auth with UVA email validation
- **Permissions**: Location access only when needed, with user consent
- **Data**: All user data encrypted and stored securely in Firestore