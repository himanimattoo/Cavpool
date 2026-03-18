#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Sample locations around UVA campus and Charlottesville
const locations = [
  {
    name: 'UVA Main Campus',
    address: 'University of Virginia, Charlottesville, VA',
    coordinates: { latitude: 38.0356, longitude: -78.5034 }
  },
  {
    name: 'Downtown Mall',
    address: '200 2nd St NE, Charlottesville, VA 22902',
    coordinates: { latitude: 38.0293, longitude: -78.4767 }
  },
  {
    name: 'Barracks Road Shopping Center',
    address: '1117 Emmet St N, Charlottesville, VA 22903',
    coordinates: { latitude: 38.0625, longitude: -78.5089 }
  },
  {
    name: 'UVA Hospital',
    address: '1215 Lee St, Charlottesville, VA 22908',
    coordinates: { latitude: 38.0247, longitude: -78.5005 }
  },
  {
    name: 'Walmart Supercenter',
    address: '100 Zan Rd, Charlottesville, VA 22901',
    coordinates: { latitude: 38.0891, longitude: -78.5428 }
  },
  {
    name: 'Target Charlottesville',
    address: '1941 Commonwealth Dr, Charlottesville, VA 22901',
    coordinates: { latitude: 38.0752, longitude: -78.5312 }
  },
  {
    name: 'Fashion Square Mall',
    address: '1600 Rio Rd E, Charlottesville, VA 22901',
    coordinates: { latitude: 38.0701, longitude: -78.4889 }
  },
  {
    name: 'CHO Airport',
    address: '100 Bowen Loop, Charlottesville, VA 22911',
    coordinates: { latitude: 38.1386, longitude: -78.4529 }
  },
  {
    name: 'Scott Stadium',
    address: '295 Massie Rd, Charlottesville, VA 22903',
    coordinates: { latitude: 38.0457, longitude: -78.5113 }
  }
];

// Test driver profiles with realistic data
const testDriverProfiles = [
  {
    id: '0V55sbIpRNNvOD2ekBPRqDVyLMk1',
    name: 'Alex Rodriguez',
    vehicleInfo: { make: 'Honda', model: 'Civic', year: 2020, seats: 4 },
    preferences: { allowSmoking: false, allowPets: true, musicPreference: 'driver_choice', communicationStyle: 'friendly' }
  },
  {
    id: 'U4gkfsAGyBgrMvT5GzSbiLOJ9xB2',
    name: 'Maria Chen',
    vehicleInfo: { make: 'Toyota', model: 'Prius', year: 2021, seats: 4 },
    preferences: { allowSmoking: false, allowPets: false, musicPreference: 'no_music', communicationStyle: 'quiet' }
  },
  {
    id: 'xhQAOJqaMXfGhDsvXFdu7qIIdKs2',
    name: 'Mike Johnson',
    vehicleInfo: { make: 'Ford', model: 'Explorer', year: 2019, seats: 6 },
    preferences: { allowSmoking: false, allowPets: true, musicPreference: 'passenger_choice', communicationStyle: 'chatty' }
  }
];

// Test rider profiles with realistic preferences
const testRiderProfiles = [
  {
    id: '4HddyRh70GSk9TwQ3r8GAy4I0NK2',
    name: 'Sarah Williams',
    preferences: { allowSmoking: false, allowPets: true, musicPreference: 'driver_choice', communicationStyle: 'friendly' }
  },
  {
    id: '4p6HE6noIuUd7kBtwzT2NbFJLha2',
    name: 'David Park',
    preferences: { allowSmoking: false, allowPets: false, musicPreference: 'no_music', communicationStyle: 'quiet' }
  },
  {
    id: '5kK4jfzWkdUWqmChMkNkk1ckwlc2',
    name: 'Emma Thompson',
    preferences: { allowSmoking: false, allowPets: true, musicPreference: 'passenger_choice', communicationStyle: 'chatty' }
  },
  {
    id: '8Ns4RQ7dkQPJJPMJB6usgGn5SNj1',
    name: 'James Wilson',
    preferences: { allowSmoking: false, allowPets: false, musicPreference: 'driver_choice', communicationStyle: 'business' }
  }
];

// Extract IDs for backwards compatibility
const testDriverIds = testDriverProfiles.map(driver => driver.id);
const testRiderIds = testRiderProfiles.map(rider => rider.id);

function getRandomElement(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function getRandomLocation() {
  return getRandomElement(locations);
}

function getRandomLocationExcluding(exclude) {
  let location;
  do {
    location = getRandomLocation();
  } while (location.name === exclude.name);
  return location;
}

function getRandomFutureTime() {
  const now = new Date();
  
  // Generate more realistic departure times
  const timePatterns = [
    // Morning commute (7-9 AM, next day)
    { weight: 20, minHours: 15, maxHours: 17, timeOfDay: [7, 9] },
    // Evening commute (5-7 PM, today or tomorrow)
    { weight: 20, minHours: 1, maxHours: 25, timeOfDay: [17, 19] },
    // Weekend trips (flexible times)
    { weight: 30, minHours: 12, maxHours: 48, timeOfDay: [9, 18] },
    // Random other times
    { weight: 30, minHours: 2, maxHours: 72, timeOfDay: null }
  ];
  
  // Weighted random selection
  const totalWeight = timePatterns.reduce((sum, pattern) => sum + pattern.weight, 0);
  let random = Math.random() * totalWeight;
  
  for (const pattern of timePatterns) {
    random -= pattern.weight;
    if (random <= 0) {
      const hoursFromNow = Math.floor(Math.random() * (pattern.maxHours - pattern.minHours)) + pattern.minHours;
      const baseTime = new Date(now.getTime() + hoursFromNow * 60 * 60 * 1000);
      
      if (pattern.timeOfDay) {
        // Set specific time of day
        const [minHour, maxHour] = pattern.timeOfDay;
        const hour = Math.floor(Math.random() * (maxHour - minHour)) + minHour;
        const minute = Math.floor(Math.random() * 12) * 5; // Round to 5-minute intervals
        
        baseTime.setHours(hour, minute, 0, 0);
      }
      
      return baseTime;
    }
  }
  
  // Fallback
  const hoursFromNow = Math.floor(Math.random() * 72) + 1;
  return new Date(now.getTime() + hoursFromNow * 60 * 60 * 1000);
}

function generateRandomPrice() {
  return Math.round((5.0 + Math.random() * 15.0) * 100) / 100; // $5.00 - $20.00
}

function generatePreferences(userProfile = null) {
  if (userProfile && userProfile.preferences) {
    // Use specific user preferences if provided
    return {
      allowSmoking: userProfile.preferences.allowSmoking,
      allowPets: userProfile.preferences.allowPets,
      musicPreference: userProfile.preferences.musicPreference,
      communicationStyle: userProfile.preferences.communicationStyle,
      preferredGenders: ['any'], // Default for now
      maxPassengers: userProfile.vehicleInfo ? userProfile.vehicleInfo.seats : 4
    };
  }

  // Fallback to random preferences
  const musicOptions = ['driver_choice', 'passenger_choice', 'no_music', 'low_volume'];
  const commOptions = ['chatty', 'friendly', 'quiet', 'business'];
  const genderOptions = [['any'], ['male'], ['female'], ['male', 'female']];
  
  return {
    allowSmoking: Math.random() < 0.2, // Lower smoking preference (20%)
    allowPets: Math.random() < 0.6, // Higher pet acceptance (60%)
    musicPreference: getRandomElement(musicOptions),
    communicationStyle: getRandomElement(commOptions),
    preferredGenders: getRandomElement(genderOptions),
    maxPassengers: Math.floor(Math.random() * 3) + 2 // 2-4 passengers
  };
}

function generateRandomNotes() {
  const notes = [
    null,
    'Please be on time!',
    'I have snacks and water',
    'Non-smoking vehicle',
    'Pet-friendly ride',
    'Quiet ride preferred',
    'Happy to chat during the ride',
    'Air conditioning available',
    'Large trunk space for luggage'
  ];
  return getRandomElement(notes);
}

function generateContextualNotes(driverProfile, startLocation, endLocation) {
  const baseNotes = [
    null,
    `Hi! I'm ${driverProfile.name.split(' ')[0]}, looking forward to the ride.`,
    'Please be ready 5 minutes before departure time.',
    'Vehicle is clean and well-maintained.',
    'Feel free to adjust the temperature or ask about music preferences.',
    'I can make brief stops if needed (gas, restroom, etc.).',
  ];

  // Add contextual notes based on driver preferences
  if (driverProfile.preferences.allowPets) {
    baseNotes.push('Pet-friendly vehicle! Your furry friends are welcome.');
  }
  
  if (driverProfile.preferences.communicationStyle === 'chatty') {
    baseNotes.push('Love meeting new people and having good conversations!');
  } else if (driverProfile.preferences.communicationStyle === 'quiet') {
    baseNotes.push('Prefer quiet rides, but happy to help if you need anything.');
  }

  // Add route-specific notes
  if (startLocation.name.includes('Airport') || endLocation.name.includes('Airport')) {
    baseNotes.push('Airport trips welcome! Extra space for luggage.');
  }

  if (startLocation.name.includes('Hospital') || endLocation.name.includes('Hospital')) {
    baseNotes.push('Medical appointments? No worries about timing flexibility.');
  }

  return getRandomElement(baseNotes);
}

function calculateDistance(start, end) {
  const earthRadius = 3959; // Earth's radius in miles
  
  const lat1 = start.coordinates.latitude * (Math.PI / 180);
  const lat2 = end.coordinates.latitude * (Math.PI / 180);
  const deltaLat = (end.coordinates.latitude - start.coordinates.latitude) * (Math.PI / 180);
  const deltaLng = (end.coordinates.longitude - start.coordinates.longitude) * (Math.PI / 180);

  const a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) *
    Math.sin(deltaLng / 2) * Math.sin(deltaLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return Math.round(earthRadius * c * 100) / 100;
}

function calculateDuration(start, end) {
  const distance = calculateDistance(start, end);
  const estimatedSpeed = distance > 10 ? 45.0 : 25.0;
  const hours = distance / estimatedSpeed;
  return Math.round(hours * 60); // Return minutes
}

function generateRideOffer() {
  const startLocation = getRandomLocation();
  const endLocation = getRandomLocationExcluding(startLocation);
  const driverProfile = getRandomElement(testDriverProfiles);
  const departureTime = getRandomFutureTime();
  const now = new Date();
  const distance = calculateDistance(startLocation, endLocation);
  
  // Calculate realistic pricing based on distance
  const basePricePerMile = 0.25 + (Math.random() * 0.35); // $0.25 - $0.60 per mile
  const calculatedPrice = Math.max(5.0, distance * basePricePerMile);
  const priceWithVariation = calculatedPrice * (0.8 + Math.random() * 0.4); // ±20% variation
  
  const totalSeats = driverProfile.vehicleInfo.seats;
  const availableSeats = Math.floor(Math.random() * (totalSeats - 1)) + 1; // 1 to totalSeats-1
  
  return {
    driverId: driverProfile.id,
    startLocation: startLocation,
    endLocation: endLocation,
    departureTime: admin.firestore.Timestamp.fromDate(departureTime),
    availableSeats: availableSeats,
    totalSeats: totalSeats,
    pricePerSeat: Math.round(priceWithVariation * 100) / 100,
    passengerIds: [],
    pendingRequestIds: [],
    status: getRandomElement(['active', 'active', 'active', 'full']), // 75% active, 25% full
    passengerPickupStatus: {},
    preferences: generatePreferences(driverProfile),
    notes: generateContextualNotes(driverProfile, startLocation, endLocation),
    estimatedDistance: distance,
    estimatedDuration: calculateDuration(startLocation, endLocation),
    isArchived: false,
    createdAt: admin.firestore.Timestamp.fromDate(now),
    updatedAt: admin.firestore.Timestamp.fromDate(now)
  };
}

function generateRideRequest() {
  const startLocation = getRandomLocation();
  const endLocation = getRandomLocationExcluding(startLocation);
  const riderProfile = getRandomElement(testRiderProfiles);
  const departureTime = getRandomFutureTime();
  const now = new Date();
  const distance = calculateDistance(startLocation, endLocation);
  
  // Create realistic flexibility window based on trip length
  let flexibilityOptions;
  if (distance < 10) {
    flexibilityOptions = [15, 30, 45]; // Shorter trips, less flexibility
  } else {
    flexibilityOptions = [30, 45, 60, 90, 120]; // Longer trips, more flexibility
  }
  const flexibilityWindow = getRandomElement(flexibilityOptions);
  
  // Calculate reasonable max price (slightly higher than estimated cost)
  const estimatedCost = Math.max(5.0, distance * 0.4); // $0.40 per mile estimate
  const maxPrice = estimatedCost * (1.1 + Math.random() * 0.3); // 10-40% above estimate
  
  return {
    requesterId: riderProfile.id,
    startLocation: startLocation,
    endLocation: endLocation,
    preferredDepartureTime: admin.firestore.Timestamp.fromDate(departureTime),
    flexibilityWindow: flexibilityWindow,
    seatsNeeded: Math.floor(Math.random() * 2) + 1, // 1-2 seats (more realistic)
    maxPricePerSeat: Math.round(maxPrice * 100) / 100,
    status: getRandomElement(['pending', 'pending', 'pending', 'matched']), // 75% pending, 25% matched
    matchedOfferId: null, // Will be set if status is 'matched'
    declinedOfferIds: [],
    preferences: generatePreferences(riderProfile),
    notes: generateRiderNotes(riderProfile, startLocation, endLocation),
    isArchived: false,
    createdAt: admin.firestore.Timestamp.fromDate(now),
    updatedAt: admin.firestore.Timestamp.fromDate(now)
  };
}

function generateRiderNotes(riderProfile, startLocation, endLocation) {
  const baseNotes = [
    null,
    `Looking forward to the ride! I'm ${riderProfile.name.split(' ')[0]}.`,
    'Happy to share gas money and good conversation.',
    'I travel light and am always on time.',
    'Flexible with pickup location within reason.',
    'Can help with navigation if needed.',
  ];

  // Add contextual notes based on rider preferences
  if (riderProfile.preferences.communicationStyle === 'quiet') {
    baseNotes.push('Prefer quiet rides - will bring headphones.');
  } else if (riderProfile.preferences.communicationStyle === 'chatty') {
    baseNotes.push('Love meeting new people and sharing stories!');
  }

  // Add route-specific notes
  if (startLocation.name.includes('Airport') || endLocation.name.includes('Airport')) {
    baseNotes.push('Airport run - have boarding passes ready for easy pickup.');
  }

  if (startLocation.name.includes('UVA') || endLocation.name.includes('UVA')) {
    baseNotes.push('UVA student - familiar with campus pickup spots.');
  }

  return getRandomElement(baseNotes);
}

async function clearTestData() {
  console.log('Clearing existing test data...');
  
  // Clear ride offers
  const rideOffers = await db.collection('ride_offers')
    .where('driverId', 'in', testDriverIds)
    .get();
  
  // Clear ride requests
  const rideRequests = await db.collection('ride_requests')
    .where('requesterId', 'in', testRiderIds)
    .get();
  
  const batch = db.batch();
  rideOffers.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  rideRequests.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  
  await batch.commit();
  console.log(`Cleared ${rideOffers.docs.length} existing test ride offers`);
  console.log(`Cleared ${rideRequests.docs.length} existing test ride requests`);
}

async function createTestRideOffers(count = 10) {
  console.log(`Creating ${count} test ride offers...`);
  
  for (let i = 0; i < count; i++) {
    try {
      const rideOffer = generateRideOffer();
      const docRef = await db.collection('ride_offers').add(rideOffer);
      
      console.log(`Created ride offer ${docRef.id}: ${rideOffer.startLocation.name} → ${rideOffer.endLocation.name}`);
      
      // Small delay to avoid hitting rate limits
      await new Promise(resolve => setTimeout(resolve, 200));
      
    } catch (error) {
      console.error(`Error creating ride offer ${i + 1}:`, error);
    }
  }
}

async function createTestRideRequests(count = 10) {
  console.log(`Creating ${count} test ride requests...`);
  
  for (let i = 0; i < count; i++) {
    try {
      const rideRequest = generateRideRequest();
      const docRef = await db.collection('ride_requests').add(rideRequest);
      
      console.log(`Created ride request ${docRef.id}: ${rideRequest.startLocation.name} → ${rideRequest.endLocation.name}`);
      
      // Small delay to avoid hitting rate limits
      await new Promise(resolve => setTimeout(resolve, 200));
      
    } catch (error) {
      console.error(`Error creating ride request ${i + 1}:`, error);
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  const shouldClear = args.includes('--clear');
  const rideCount = parseInt(args[args.indexOf('--rides') + 1]) || 10;
  const requestCount = parseInt(args[args.indexOf('--requests') + 1]) || 10;
  
  console.log('Starting Firebase database population...');
  
  try {
    if (shouldClear) {
      await clearTestData();
    }
    
    await createTestRideOffers(rideCount);
    await createTestRideRequests(requestCount);
    
    console.log('Database population completed successfully.');
    console.log('Test ride data has been created for navigation testing.');
    console.log(`Created ${rideCount} ride offers and ${requestCount} ride requests`);
    
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

// Handle command line arguments and run
if (require.main === module) {
  main();
}

module.exports = { generateRideOffer, generateRideRequest, createTestRideOffers, createTestRideRequests, clearTestData };