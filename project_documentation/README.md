# UVA Carpool App (CavPool)

A cross-platform ride-sharing application designed specifically for UVA students to connect drivers and riders within the university community.

## Project Overview

CavPool facilitates secure, affordable transportation for UVA students by connecting those who need rides with verified student drivers. The app prioritizes safety through UVA authentication, driver verification, and emergency features.

## Key Features

### Authentication & User Management (IMPLEMENTED)
- UVA @virginia.edu email authentication with Google Sign-In
- User profile creation with photo upload
- Secure Firebase authentication and user management
- Default rider accounts with profile customization

### Google Maps Integration (IMPLEMENTED)
- Interactive Google Maps with real-time location tracking
- Uber-style address search with Google Places API autocomplete
- Custom route calculation between any two addresses
- Visual route display with polylines, markers, and route information
- Support for both current location and custom address selection

### Navigation & Route Planning (IMPLEMENTED)
- Turn-by-turn route visualization
- Distance and estimated duration calculations
- From/To address selection with search suggestions
- Route information cards with detailed trip data

### Ride Management (PLANNED)
- **For Drivers**: Post rides with origin, destination, timing, available seats, and cost
- **For Riders**: Request rides and browse available options
- Route optimization with stop requests along driver's path
- Intelligent ride matching algorithm for route efficiency

### Payment Integration (PLANNED)
- Secure payments via Stripe Connect
- Automated fare estimation and cost breakdown
- Cost splitting among multiple passengers
- Refund handling for cancellations

### Safety Features (PLANNED)
- Emergency contact notification system
- Panic button for immediate emergency alerts
- Location sharing during rides
- Route monitoring and deviation alerts
- Mutual rating system for drivers and riders

### Advanced Search & Matching (PLANNED)
- Filter by destination, date, cargo space requirements
- Prioritize shortest and cheapest routes
- Smart ride matching based on route proximity and preferences

## Technology Stack

### Mobile App
- **Framework**: Flutter 3.x with Dart
- **State Management**: Provider pattern
- **UI**: Material Design 3 with UVA branding (Navy #232F3E, Orange #E57200)
- **Navigation**: Bottom navigation with multiple tabs

### Backend & Services
- **Authentication**: Firebase Auth with Google Sign-In
- **Database**: Cloud Firestore (NoSQL document database)
- **File Storage**: Firebase Storage (user photos, documents)
- **Maps & Location**: Google Maps API, Google Places API, Geolocator
- **HTTP Client**: Dart http package for API calls

### Key Dependencies
```yaml
# Core Flutter & Firebase
firebase_core: ^4.1.0
firebase_auth: ^6.0.2
cloud_firestore: ^6.0.1
firebase_storage: ^13.0.1

# Google Services
google_sign_in: ^7.2.0
google_maps_flutter: ^2.10.0
google_fonts: ^6.2.1

# Location & Navigation
geolocator: ^14.0.2
geocoding: ^3.0.0
location: ^8.0.1

# State Management & UI
provider: ^6.1.2
go_router: ^16.2.1
image_picker: ^1.1.2
```

### Development Tools
- **Version Control**: Git with GitHub
- **CI/CD**: GitHub Actions (automated testing and builds)
- **Testing**: Flutter test framework
- **Code Quality**: Flutter lints, analysis options

## Getting Started

### Prerequisites
- **Flutter SDK** (3.8.1 or higher)
- **Dart SDK** (included with Flutter)
- **Firebase project** with the following services enabled:
  - Authentication (Google Sign-In provider)
  - Cloud Firestore
  - Storage
- **Google Cloud Console** project with APIs enabled:
  - Maps SDK for Android/iOS
  - Places API
  - Geocoding API
- **Android Studio** / **Xcode** for mobile development
- **Git** for version control

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/capstone-orange-1.git
   cd capstone-orange-1/app
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Add google-services.json (Android) to android/app/
   - Add GoogleService-Info.plist (iOS) to ios/Runner/
   - Update lib/firebase_options.dart with Firebase config

4. **Configure Google Maps API**
   - Add Google Maps API key to:
     - android/app/src/main/AndroidManifest.xml
     - ios/Runner/AppDelegate.swift

5. **Run the app**
   ```bash
   flutter run
   ```

### Environment Configuration
- API keys are configured directly in the platform-specific files
- Firebase configuration is handled through Firebase CLI and auto-generated files
- No additional environment files needed for basic setup

## Project Status

### Sprint 1: Foundations & Authentication (COMPLETED)
- Flutter project setup with complete mobile app structure
- Firebase integration (Authentication, Firestore, Storage)
- UVA email authentication with @virginia.edu validation
- Basic app scaffolding with navigation and UVA branding
- GitHub CI/CD pipeline implementation
- Working authentication system with login/register flows

### Sprint 2: User Profiles & Google Maps Integration (COMPLETED)
- User profile creation and editing with photo upload
- Google Maps integration with interactive map display
- Real-time location tracking and permissions handling
- Uber-style address search with Google Places API
- Custom route calculation between any two points
- Visual route display with markers, polylines, and trip information

### Current Focus: Ride Management System (IN PROGRESS)
- Implementing ride posting functionality for drivers
- Building ride browsing interface for passengers
- Creating ride booking and reservation system
- Developing smart ride matching algorithms

### Upcoming Features
- Payment integration with Stripe
- Real-time messaging between drivers and riders
- Safety features (emergency contacts, panic button)
- Push notifications for ride updates
- Rating and review system

### Architecture Achievements
- **Scalable Provider-based state management** for complex app state
- **Modular service architecture** (LocationService, RoutesService, AddressSearchService)
- **Responsive UI components** with proper error handling and loading states
- **Integration with multiple Google APIs** (Maps, Places, Geocoding)
- **Secure authentication flow** with profile management

## Contributing

This is a capstone project for UVA Computer Science students. See sprint plan for current development priorities.

## Security & Privacy

- All user data encrypted and stored securely
- Driver verification required before offering rides
- Emergency contact integration for safety
- No personal contact information shared without consent