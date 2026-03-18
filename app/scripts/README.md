# Database Population Scripts

This directory contains scripts to populate your Firebase database with test data for development and testing.

## Scripts

### `firebase_seed.js` (Basic)
Node.js script that creates randomized test data using Firebase Admin SDK.

### `enhanced_seed.js` (Recommended)
Advanced Node.js script with realistic routing patterns, smart pricing, and contextual data generation.

### `populate_database.dart` 
Dart script that uses the app's models and services to create realistic test data.

### `create_test_user.js`
Creates test user accounts for Apple App Review and demo purposes.

## Usage

### Prerequisites
1. **Firebase Service Account Key**: Download from Firebase Console → Project Settings → Service Accounts
2. **Node.js**: Install Node.js on your system
3. **Test User Accounts**: Create test users in Firebase Auth
4. Update the `testDriverIds` in the scripts with actual test user IDs

### Setup (Node.js Script - Recommended)

1. **Download Service Account Key**:
   - Go to Firebase Console → Your Project → Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save as `serviceAccountKey.json` in the `scripts/` directory

2. **Install Dependencies**:
   ```bash
   cd scripts
   npm install
   ```

3. **Update Configuration**:
   - Edit `firebase_seed.js` and replace `your-project-id` with your actual Firebase project ID
   - Update the `testDriverIds` and `testRiderIds` arrays with valid test user email addresses

### Running the Scripts

#### Option 1: Enhanced Script (Recommended)
```bash
cd scripts

# Install dependencies first
npm install

# Generate 15 realistic ride offers with smart routing and pricing
node enhanced_seed.js --offers 15

# Clear existing data and generate 20 realistic ride offers
node enhanced_seed.js --clear --offers 20
```

#### Option 2: Basic Script
```bash
cd scripts

# Create 10 test ride offers and 10 ride requests
node firebase_seed.js --rides 10 --requests 10

# Create 20 test ride offers and clear existing data
node firebase_seed.js --clear --rides 20 --requests 15

# NPM shortcuts
npm run seed        # Creates 10 offers and 10 requests
npm run seed:20     # Creates 20 offers with clearing
```

#### Option 2: Dart Scripts (Alternative)
```bash
# Simple test routes (from app root directory)
flutter run --target=scripts/create_test_routes.dart

# Or try with dart command (may have dependency issues)
dart run scripts/create_test_routes.dart --rides 20
```

## Test Data Created

### Enhanced Script Data (Recommended)
- **Realistic Route Patterns**: Common university commute routes, shopping trips, airport runs
- **Smart Departure Times**: Peak hours (7-9 AM, 5-7 PM), weekend patterns, event-based timing
- **Dynamic Pricing**: Distance-based with surge pricing for peak times and airport trips
- **Contextual Notes**: Personalized messages based on driver preferences and route type
- **User Consistency**: Driver preferences and vehicle info match across offers
- **Status Distribution**: 75% active, 25% full for realistic marketplace simulation

### Basic Script Data
- **Start/End Locations**: Random combinations from Charlottesville area locations
- **Departure Times**: Random future times (1-72 hours from now)
- **Prices**: Distance-based with variation ($0.25 - $0.60 per mile)
- **Seats**: Based on actual driver vehicle capacity
- **Preferences**: Matches individual driver/rider profiles
- **Status**: Mixed active/full for offers, pending/matched for requests

### Ride Requests (Both Scripts)
- **Smart Flexibility**: Shorter trips have less time flexibility (15-45 min), longer trips more (30-120 min)
- **Realistic Pricing**: Max prices set 10-40% above estimated costs
- **User Consistency**: Preferences match individual rider profiles
- **Contextual Notes**: Route-specific and preference-based messaging

### Sample Locations
- UVA Main Campus
- Downtown Mall
- Barracks Road Shopping Center
- UVA Hospital
- Walmart Supercenter
- Target Charlottesville
- Fashion Square Mall
- CHO Airport
- Scott Stadium

## Testing the Route Simulation

After creating test routes:

1. **Start the app** and log in as a test driver
2. **Accept a ride** from the requests tab
3. **Start the ride** from the preview screen
4. **Use the simulation controls** in the active ride screen:
   - Toggle test controls with the visibility button
   - Use "Auto" mode for automatic movement
   - Use arrow buttons for manual step-by-step movement
   - Reset to start position anytime

## Customization

### Adding New Locations
Edit the `_locations` array in either script to add more test locations:

```dart
{
  'name': 'Your Location Name',
  'address': 'Full Address, City, State ZIP',
  'coordinates': {'latitude': 38.1234, 'longitude': -78.5678},
}
```

### Adding Test Users
Update the `_testDriverIds` and `_samplePassengerIds` arrays with actual user IDs from your Firebase Auth.

### Adjusting Data Ranges
Modify the random generation functions to change:
- Price ranges
- Time windows
- Available seats
- Preference distributions

## Troubleshooting

### Common Issues
1. **Firebase not initialized**: Ensure your Firebase configuration is correct
2. **Permission denied**: Check your Firestore security rules
3. **Invalid user IDs**: Make sure test user accounts exist in Firebase Auth
4. **Import errors**: Verify package dependencies in pubspec.yaml

### Firestore Security Rules
Ensure your rules allow the test user accounts to create and read documents:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /ride_offers/{document} {
      allow read, write: if request.auth != null && request.auth.token.email.matches('.*@virginia.edu');
    }
  }
}
```