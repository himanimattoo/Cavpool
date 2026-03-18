# CavPool

A Flutter ride-sharing app exclusively for UVA students that connects drivers and riders to carpool to off-Grounds destinations such as airports, sporting events, and major cities.

## Team Members
- Yovanny Vasquez (yav9zb)
- Cole Popielec (kzw4dz)
- Himani Mattoo (ets4ar)
- Norah Alghamdi (nwm3fj)

## Builds
- iOS Simulator:
   flutter pub clean
   flutter pub get
   open -a Simulator
   flutter devices (find your device_name)
   flutter run -d device name
- Android Simulator:
   flutter pub clean
   flutter pub get
   flutter devices (find your device_name)
   flutter run -d device_name
   
   *Optional Android solution*
   On Windows, run .\run_flutter.ps1 from capstone-orange-1/app to cold boot an installed Google Pixel 6 simulator (may have to adjust $emulatorName and/or SDK paths in .\run_flutter.ps1...probably just better to run use flutter run)

## Installation Instructions
1) Clone and enter the app:
```bash
git clone https://github.com/your-username/capstone-orange-1.git
cd capstone-orange-1/app
```
2) Install dependencies: `flutter pub get`
3) Add platform configs:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - Set Google Maps API key from Google Cloud Console

## Usage Instructions
- Run on simulator/device using the instructions from the Builds and Installation Instructions sections
- Sign in with a test driver account (see next section)
- Create a ride offer, remembering the time, pickup and dropoff destinations
- Sign out of driver account and sign into rider account
- Create a ride request with similar parameters to the ride offer you created on the driver account, the ride offer you made will likely be the top offer
- Request to join the ride, then sign back into the driver account and accept the ride request
- From here, users can wait until the day of the ride to continue or simply simulate the ride by manually tapping through the pickup and dropoff screens from either the driver or rider account

## Test Accounts
- Driver: mike.driver@virginia.edu / TestPass123!
- Rider: lisa.student@virginia.edu / TestPass123!

## Sources Used
- Flutter 3.x (Dart)
- Firebase Auth/Firestore/Storage
- Google Maps, Places, Geolocator
- CI/CD: GitHub Actions
- ChatGPT (GPT-4 and GPT-5)
- Claude
