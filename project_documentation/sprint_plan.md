# UVA Carpool App - Sprint Plan

## Sprint 1: Foundations & Authentication (COMPLETED)
**Sept 22 – Sept 28 (Week 1)**
- Project setup (Flutter project, Firebase backend, GitHub CI/CD)
- Authentication: UVA @virginia.edu email validation with Google Sign-In
- Firebase schema: users, authentication, basic app structure
- **Deliverable:** Working authentication system with UVA email enforcement

**Achievements:**
- Complete Flutter app structure with Material Design 3
- Firebase Auth integration with Google Sign-In provider
- UVA branding implementation (Navy #232F3E, Orange #E57200)
- Bottom navigation with multiple tabs
- Secure user session management

## Sprint 2: User Profiles & Google Maps Integration (COMPLETED)
**Sept 29 – Oct 12 (Weeks 2–3)**
- User profiles (name, display name, account type, profile photos)
- Photo upload functionality with Firebase Storage
- Google Maps integration with interactive map display
- Real-time location tracking and permissions handling
- Uber-style address search with Google Places API autocomplete
- Custom route calculation between any two addresses
- **Deliverable:** Complete user profile system + comprehensive maps functionality

**Achievements:**
- Profile creation and editing with photo upload
- Google Maps SDK integration for Android and iOS
- Google Places API for address autocomplete
- Route visualization with polylines, markers, and trip information
- Location services with proper permission handling
- Provider-based state management architecture

## Sprint 3: Ride Management System (IN PROGRESS)
**Oct 13 – Oct 19 (Week 4)**
- Drivers: Create/edit/delete ride offers (using route planning from Sprint 2)
- Riders: Browse and request rides
- Ride data models and Firebase Firestore integration
- Basic ride matching based on route proximity
- **Deliverable:** Functional ride posting and browsing system

**Current Focus:**
- Leveraging existing Google Maps integration for ride posting
- Building ride posting UI with route selection
- Implementing ride browsing and filtering
- Creating ride booking system

## Sprint 4: Enhanced Ride Features & Matching (PLANNED)
**Oct 20 – Nov 2 (Weeks 5–6)**
- Advanced ride matching algorithm using route data
- Ride details with seat management and cost calculation
- Driver verification and rating system
- Real-time ride status updates
- **Deliverable:** Smart ride matching with comprehensive ride management

## Sprint 5: Communication & Safety (PLANNED)
**Nov 3 – Nov 9 (Week 7)**
- In-app messaging between drivers and riders
- Real-time location sharing during rides
- Safety features (emergency contacts, panic button)
- Push notifications for ride updates
- **Deliverable:** Complete communication and safety framework

## Sprint 6: Payment Integration (PLANNED)
**Nov 10 – Nov 16 (Week 8)**
- Integrate Stripe Connect for secure payments
- Cost breakdown and fare calculation
- Automated payment processing
- Refund and cancellation handling
- **Deliverable:** Secure payment system with Stripe integration

## Sprint 7: Final Polish & Launch (PLANNED)
**Nov 17 – Nov 23 (Week 9)**
- Comprehensive testing and bug fixes
- Performance optimization
- UI/UX polish and accessibility improvements
- App store preparation and deployment
- **Deliverable:** Production-ready MVP with full feature set

## Architecture Evolution

### Completed Infrastructure
- **State Management**: Provider pattern with AuthProvider, UserProfileProvider, RoutesProvider
- **Service Layer**: LocationService, RoutesService, AddressSearchService, AuthService
- **Database**: Firebase Firestore with user profiles and authentication
- **Maps Integration**: Google Maps, Places API, Geocoding API
- **UI Framework**: Material Design 3 with UVA branding

### Next Technical Priorities
1. **Ride Data Models**: Define Firestore schema for rides, bookings, and matching
2. **Advanced Providers**: RideProvider, BookingProvider for ride management
3. **Notification System**: Firebase Cloud Messaging for push notifications
4. **Payment Infrastructure**: Stripe SDK integration and secure payment processing
5. **Real-time Features**: Firestore real-time listeners for live updates