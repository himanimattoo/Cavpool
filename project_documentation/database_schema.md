# Firebase Database Schema

## Collections Overview

### Users Collection (`users`)
```javascript
{
  uid: "string", // Firebase Auth UID
  email: "string", // @virginia.edu email
  profile: {
    firstName: "string",
    lastName: "string",
    displayName: "string",
    photoURL: "string", // Firebase Storage URL
    pronouns: "string",
    bio: "string",
    phoneNumber: "string" // optional
  },
  accountType: "rider" | "driver",
  isVerified: boolean,
  emergencyContacts: [
    {
      name: "string",
      phoneNumber: "string",
      relationship: "string"
    }
  ],
  preferences: {
    allowSmoking: boolean,
    allowPets: boolean,
    musicPreference: "driver_choice" | "passenger_choice" | "no_music",
    communicationStyle: "chatty" | "friendly" | "quiet",
    preferredGenders: ["any"] | ["male"] | ["female"] | ["male", "female"],
    maxPassengers: "number"
  },
  ratings: {
    averageRating: "number",
    totalRatings: "number",
    asDriver: {
      averageRating: "number",
      totalRatings: "number"
    },
    asRider: {
      averageRating: "number",
      totalRatings: "number"
    }
  },
  driverVerificationStatus: "pending" | "approved" | "rejected" | null,
  vehicleInfo: {
    make: "string",
    model: "string",
    year: "number",
    color: "string",
    licensePlate: "string",
    seats: "number",
    cargoSpace: "small" | "medium" | "large"
  } | null,
  createdAt: "timestamp",
  updatedAt: "timestamp"
}
```

### Ride Offers Collection (`ride_offers`)
```javascript
{
  id: "string", // Auto-generated document ID
  driverId: "string", // Reference to users collection
  startLocation: {
    coordinates: {
      latitude: "number",
      longitude: "number"
    },
    address: "string",
    name: "string" // optional display name
  },
  endLocation: {
    coordinates: {
      latitude: "number", 
      longitude: "number"
    },
    address: "string",
    name: "string" // optional display name
  },
  departureTime: "timestamp",
  availableSeats: "number",
  totalSeats: "number",
  pricePerSeat: "number",
  passengerIds: ["string"], // Array of user IDs
  pendingRequestIds: ["string"], // Array of ride request IDs
  status: "active" | "full" | "inProgress" | "completed" | "cancelled",
  passengerPickupStatus: {
    "[passengerId]": "pending" | "driverArrived" | "passengerPickedUp" | "completed"
  },
  preferences: {
    allowSmoking: boolean,
    allowPets: boolean,
    musicPreference: "driver_choice" | "passenger_choice" | "no_music" | "low_volume",
    communicationStyle: "chatty" | "friendly" | "quiet" | "business",
    preferredGenders: ["any"] | ["male"] | ["female"] | ["male", "female"],
    maxPassengers: "number"
  },
  notes: "string" | null,
  waypoints: [
    {
      coordinates: { latitude: "number", longitude: "number" },
      address: "string",
      name: "string"
    }
  ] | null,
  estimatedDistance: "number", // miles
  estimatedDuration: "number", // minutes
  isArchived: boolean,
  createdAt: "timestamp",
  updatedAt: "timestamp"
}
```

### Ride Requests Collection (`ride_requests`)
```javascript
{
  id: "string", // Auto-generated document ID
  requesterId: "string", // Reference to users collection
  startLocation: {
    coordinates: {
      latitude: "number",
      longitude: "number"
    },
    address: "string",
    name: "string" // optional display name
  },
  endLocation: {
    coordinates: {
      latitude: "number",
      longitude: "number"
    },
    address: "string", 
    name: "string" // optional display name
  },
  preferredDepartureTime: "timestamp",
  flexibilityWindow: "number", // minutes of flexibility
  seatsNeeded: "number",
  maxPricePerSeat: "number",
  status: "pending" | "matched" | "accepted" | "declined" | "completed" | "cancelled",
  matchedOfferId: "string" | null, // ID of matched ride offer
  declinedOfferIds: ["string"], // Array of declined offer IDs
  preferences: {
    allowSmoking: boolean,
    allowPets: boolean,
    musicPreference: "driver_choice" | "passenger_choice" | "no_music" | "low_volume",
    communicationStyle: "chatty" | "friendly" | "quiet" | "business", 
    preferredGenders: ["any"] | ["male"] | ["female"] | ["male", "female"],
    maxPassengers: "number"
  },
  notes: "string" | null,
  isArchived: boolean,
  createdAt: "timestamp",
  updatedAt: "timestamp"
}
```

### Supporting Collections

#### Live Locations Collection (`live_locations`)
```javascript
{
  id: "string", // Auto-generated document ID
  rideOfferId: "string", // Reference to ride_offers collection
  driverId: "string",
  currentLocation: {
    latitude: "number",
    longitude: "number"
  },
  timestamp: "timestamp",
  isActive: boolean
}
```

#### Ride Notifications Collection (`ride_notifications`)
```javascript
{
  id: "string", // Auto-generated document ID
  recipientId: "string", // User who receives the notification
  senderId: "string", // User who triggered the notification
  rideId: "string", // Reference to ride offer or request
  type: "ride_request" | "ride_accepted" | "ride_declined" | "ride_cancelled",
  message: "string",
  isRead: boolean,
  createdAt: "timestamp"
}
```

#### Emergency Contacts Collection (`emergency_contacts`)
```javascript
{
  id: "string", // Auto-generated document ID
  userId: "string", // Reference to users collection
  name: "string",
  phoneNumber: "string",
  relationship: "string",
  createdAt: "timestamp"
}
```

#### Driver Verification Requests Collection (`driver_verification_requests`)
```javascript
{
  id: "string", // Auto-generated document ID
  userId: "string", // Reference to users collection
  licenseImageUrl: "string", // Firebase Storage URL
  insuranceImageUrl: "string", // Firebase Storage URL
  status: "pending" | "approved" | "rejected",
  reviewedBy: "string" | null, // Admin user ID
  reviewedAt: "timestamp" | null,
  createdAt: "timestamp"
}
```

#### Vehicles Collection (`vehicles`)
```javascript
{
  id: "string", // Auto-generated document ID
  ownerId: "string", // Reference to users collection
  make: "string",
  model: "string",
  year: "number",
  color: "string",
  licensePlate: "string",
  seats: "number",
  cargoSpace: "small" | "medium" | "large",
  isActive: boolean,
  createdAt: "timestamp",
  updatedAt: "timestamp"
}
```

## Security Rules

### Users Collection Rules
- Users can read/write their own profile
- Public profile info readable by authenticated users
- Driver verification status readable by authenticated users
- Emergency contacts only readable by user themselves

### Ride Offers Collection Rules
- Drivers can create/update/delete their own ride offers
- All authenticated users can read active ride offers
- Only ride participants can read full ride details
- Passengers can update their own status within the ride

### Ride Requests Collection Rules
- Users can create/update/delete their own ride requests
- Drivers can read pending ride requests for matching
- Only request owner and matched driver can read full request details

### Supporting Collections Rules
- Live locations: Only readable by ride participants
- Notifications: Only readable by recipient
- Emergency contacts: Only readable by owner
- Driver verification: Only readable by owner and admins
- Vehicles: Only readable/writable by owner

## Database Indexes

Current indexes defined in `firestore.indexes.json`:

### Ride Offers Collection (`ride_offers`)
- Composite index: `departureTime + status`
- Composite index: `driverId + departureTime`

### Ride Requests Collection (`ride_requests`) 
- Composite index: `status + preferredDepartureTime`
- Composite index: `requesterId + preferredDepartureTime`

### Routes Collection (`routes`)
- Composite index: `createdBy + createdAt`

## Implementation Notes

This schema reflects the actual database structure as implemented in the application. The collection names use snake_case convention (`ride_offers`, `ride_requests`) rather than camelCase. The structure uses flat objects rather than deeply nested structures for better query performance and simpler data access patterns.

Test data can be generated using the scripts in the `/app/scripts/` directory which are configured to work with this exact schema structure.