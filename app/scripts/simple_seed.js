#!/usr/bin/env node

// This script creates sample data that you can manually add to Firebase
// Run with: node simple_seed.js > sample_data.json

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
    name: 'Target Charlottesville',
    address: '1941 Commonwealth Dr, Charlottesville, VA 22901',
    coordinates: { latitude: 38.0752, longitude: -78.5312 }
  },
  {
    name: 'CHO Airport',
    address: '100 Bowen Loop, Charlottesville, VA 22911',
    coordinates: { latitude: 38.1386, longitude: -78.4529 }
  }
];

function getRandomElement(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function getRandomLocationExcluding(exclude) {
  let location;
  do {
    location = getRandomElement(locations);
  } while (location.name === exclude.name);
  return location;
}

function getRandomFutureTime() {
  const now = new Date();
  const hoursFromNow = Math.floor(Math.random() * 72) + 1; // 1-72 hours from now
  return new Date(now.getTime() + hoursFromNow * 60 * 60 * 1000);
}

function generateRideOffer() {
  const startLocation = getRandomElement(locations);
  const endLocation = getRandomLocationExcluding(startLocation);
  const departureTime = getRandomFutureTime();
  const now = new Date();
  
  return {
    driverId: 'test_driver@virginia.edu', // Replace with actual test user ID
    startLocation: startLocation,
    endLocation: endLocation,
    departureTime: departureTime.toISOString(),
    availableSeats: Math.floor(Math.random() * 3) + 1, // 1-3 seats
    totalSeats: 4,
    pricePerSeat: Math.round((5.0 + Math.random() * 15.0) * 100) / 100,
    passengerIds: [],
    pendingRequestIds: [],
    status: 'active',
    passengerPickupStatus: {},
    preferences: {
      allowSmoking: Math.random() < 0.5,
      allowPets: Math.random() < 0.5,
      musicPreference: getRandomElement(['driver_choice', 'passenger_choice', 'no_music']),
      communicationStyle: getRandomElement(['chatty', 'friendly', 'quiet']),
      preferredGenders: ['any'],
      maxPassengers: 4
    },
    notes: getRandomElement([null, 'Please be on time!', 'Non-smoking vehicle', 'Pet-friendly ride']),
    estimatedDistance: Math.round((Math.random() * 30 + 5) * 100) / 100, // 5-35 miles
    estimatedDuration: Math.floor(Math.random() * 60) + 15, // 15-75 minutes
    isArchived: false,
    createdAt: now.toISOString(),
    updatedAt: now.toISOString()
  };
}

// Generate sample ride offers
const rideOffers = [];
const count = parseInt(process.argv[2]) || 10;

console.log(`// Generated ${count} sample ride offers`);
console.log('// Copy this data to Firebase Console → Firestore Database');
console.log('// Create documents in the "ride_offers" collection');
console.log('');

for (let i = 0; i < count; i++) {
  const ride = generateRideOffer();
  console.log(`// Ride Offer ${i + 1}: ${ride.startLocation.name} → ${ride.endLocation.name}`);
  console.log(JSON.stringify(ride, null, 2));
  if (i < count - 1) {
    console.log(',');
  }
  console.log('');
}

console.log(`// Successfully generated ${count} ride offers!`);