# Deprecated Screens

This folder contains ride-related screens that have been deprecated in favor of the enhanced driver active ride workflow.

## Moved Files:

### `active_ride_screen.dart`
- **Reason**: Redundant generic active ride screen
- **Replaced by**: `driver_active_ride_screen.dart` (enhanced with live navigation)
- **Features missing**: Turn-by-turn navigation, live location tracking, test controls

### `active_route_screen.dart` 
- **Reason**: Basic route display screen with placeholder functionality
- **Replaced by**: `driver_active_ride_screen.dart` (enhanced with live navigation)
- **Features missing**: Proper navigation integration, passenger management

### `start_ride_screen.dart`
- **Reason**: Contains duplicate `ActiveRideScreen` class and basic functionality
- **Replaced by**: Proper flow using `RidePreviewScreen` → `DriverActiveRideScreen`
- **Features missing**: Integration with ride state management

## Current Working Flow:

1. **RidePreviewScreen** - Shows ride details before starting (when status = `active`)
2. **DriverActiveRideScreen** - Enhanced active ride with navigation (when status = `inProgress`)

## Notes:

- All deprecated files are preserved in case any important functionality needs to be recovered
- The new flow is managed by `ActiveTabScreen` which intelligently routes based on ride status
- Do not import these deprecated files in new code

## Migration Date:
November 2024