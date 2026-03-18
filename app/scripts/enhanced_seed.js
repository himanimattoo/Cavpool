#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Enhanced test data generator with realistic patterns
class EnhancedDataGenerator {
  constructor() {
    this.locations = [
      {
        name: 'UVA Main Campus',
        address: 'University of Virginia, Charlottesville, VA',
        coordinates: { latitude: 38.0356, longitude: -78.5034 },
        type: 'university'
      },
      {
        name: 'Downtown Mall',
        address: '200 2nd St NE, Charlottesville, VA 22902',
        coordinates: { latitude: 38.0293, longitude: -78.4767 },
        type: 'entertainment'
      },
      {
        name: 'Barracks Road Shopping Center',
        address: '1117 Emmet St N, Charlottesville, VA 22903',
        coordinates: { latitude: 38.0625, longitude: -78.5089 },
        type: 'shopping'
      },
      {
        name: 'UVA Hospital',
        address: '1215 Lee St, Charlottesville, VA 22908',
        coordinates: { latitude: 38.0247, longitude: -78.5005 },
        type: 'medical'
      },
      {
        name: 'CHO Airport',
        address: '100 Bowen Loop, Charlottesville, VA 22911',
        coordinates: { latitude: 38.1386, longitude: -78.4529 },
        type: 'airport'
      },
      {
        name: 'Scott Stadium',
        address: '295 Massie Rd, Charlottesville, VA 22903',
        coordinates: { latitude: 38.0457, longitude: -78.5113 },
        type: 'sports'
      },
      {
        name: 'Fashion Square Mall',
        address: '1600 Rio Rd E, Charlottesville, VA 22901',
        coordinates: { latitude: 38.0701, longitude: -78.4889 },
        type: 'shopping'
      },
      {
        name: 'Target Charlottesville',
        address: '1941 Commonwealth Dr, Charlottesville, VA 22901',
        coordinates: { latitude: 38.0752, longitude: -78.5312 },
        type: 'shopping'
      }
    ];

    this.driverProfiles = [
      {
        id: '0V55sbIpRNNvOD2ekBPRqDVyLMk1',
        name: 'Alex Rodriguez',
        vehicleInfo: { make: 'Honda', model: 'Civic', year: 2020, seats: 4 },
        preferences: { allowSmoking: false, allowPets: true, musicPreference: 'driver_choice', communicationStyle: 'friendly' },
        drivingPatterns: ['commute', 'shopping', 'social']
      },
      {
        id: 'U4gkfsAGyBgrMvT5GzSbiLOJ9xB2',
        name: 'Maria Chen',
        vehicleInfo: { make: 'Toyota', model: 'Prius', year: 2021, seats: 4 },
        preferences: { allowSmoking: false, allowPets: false, musicPreference: 'no_music', communicationStyle: 'quiet' },
        drivingPatterns: ['commute', 'medical', 'airport']
      },
      {
        id: 'xhQAOJqaMXfGhDsvXFdu7qIIdKs2',
        name: 'Mike Johnson',
        vehicleInfo: { make: 'Ford', model: 'Explorer', year: 2019, seats: 6 },
        preferences: { allowSmoking: false, allowPets: true, musicPreference: 'passenger_choice', communicationStyle: 'chatty' },
        drivingPatterns: ['sports', 'social', 'shopping', 'airport']
      }
    ];

    this.riderProfiles = [
      {
        id: '4HddyRh70GSk9TwQ3r8GAy4I0NK2',
        name: 'Sarah Williams',
        preferences: { allowSmoking: false, allowPets: true, musicPreference: 'driver_choice', communicationStyle: 'friendly' },
        travelPatterns: ['commute', 'shopping', 'entertainment']
      },
      {
        id: '4p6HE6noIuUd7kBtwzT2NbFJLha2',
        name: 'David Park',
        preferences: { allowSmoking: false, allowPets: false, musicPreference: 'no_music', communicationStyle: 'quiet' },
        travelPatterns: ['commute', 'university', 'shopping']
      },
      {
        id: '5kK4jfzWkdUWqmChMkNkk1ckwlc2',
        name: 'Emma Thompson',
        preferences: { allowSmoking: false, allowPets: true, musicPreference: 'passenger_choice', communicationStyle: 'chatty' },
        travelPatterns: ['social', 'entertainment', 'university']
      },
      {
        id: '8Ns4RQ7dkQPJJPMJB6usgGn5SNj1',
        name: 'James Wilson',
        preferences: { allowSmoking: false, allowPets: false, musicPreference: 'driver_choice', communicationStyle: 'business' },
        travelPatterns: ['commute', 'airport', 'medical']
      }
    ];
  }

  // Generate realistic route patterns
  generateRealisticRoute() {
    const patterns = [
      // University commute patterns
      { from: 'university', to: 'shopping', weight: 25 },
      { from: 'university', to: 'entertainment', weight: 20 },
      { from: 'shopping', to: 'university', weight: 25 },
      { from: 'entertainment', to: 'university', weight: 20 },
      
      // Airport trips
      { from: 'university', to: 'airport', weight: 15 },
      { from: 'airport', to: 'university', weight: 15 },
      
      // Medical trips
      { from: 'university', to: 'medical', weight: 10 },
      { from: 'medical', to: 'university', weight: 10 },
      
      // Shopping trips
      { from: 'shopping', to: 'shopping', weight: 5 },
      
      // Sports events
      { from: 'university', to: 'sports', weight: 8 },
      { from: 'sports', to: 'university', weight: 8 }
    ];

    const totalWeight = patterns.reduce((sum, p) => sum + p.weight, 0);
    let random = Math.random() * totalWeight;

    for (const pattern of patterns) {
      random -= pattern.weight;
      if (random <= 0) {
        const fromLocations = this.locations.filter(l => l.type === pattern.from);
        const toLocations = this.locations.filter(l => l.type === pattern.to);
        
        const startLocation = this.getRandomElement(fromLocations);
        let endLocation;
        
        if (pattern.from === pattern.to) {
          // Same type, ensure different location
          endLocation = this.getRandomElementExcluding(toLocations, startLocation);
        } else {
          endLocation = this.getRandomElement(toLocations);
        }

        return { startLocation, endLocation };
      }
    }

    // Fallback to random locations
    return this.getRandomRoute();
  }

  // Generate realistic departure times based on route type
  generateSmartDepartureTime(startLocation, endLocation) {
    const now = new Date();
    
    // University-related trips
    if (startLocation.type === 'university' || endLocation.type === 'university') {
      if (startLocation.type === 'university') {
        // Leaving campus - common times: after classes (3-6 PM), evening (7-10 PM)
        return this.generateTimeInRanges(now, [
          { hours: [15, 18], weight: 40, days: [1, 2] },
          { hours: [19, 22], weight: 30, days: [0, 1, 2] },
          { hours: [9, 12], weight: 20, days: [1, 2, 3] }, // Weekend trips
          { hours: [7, 9], weight: 10, days: [1] } // Early morning
        ]);
      } else {
        // Going to campus - common times: morning (7-10 AM), afternoon (1-3 PM)
        return this.generateTimeInRanges(now, [
          { hours: [7, 10], weight: 50, days: [1, 2] },
          { hours: [13, 15], weight: 30, days: [1, 2] },
          { hours: [17, 20], weight: 20, days: [0, 1, 2] }
        ]);
      }
    }

    // Airport trips - typically early morning or late evening
    if (startLocation.type === 'airport' || endLocation.type === 'airport') {
      return this.generateTimeInRanges(now, [
        { hours: [5, 8], weight: 40, days: [0, 1, 2, 3, 4, 5, 6] },
        { hours: [20, 23], weight: 35, days: [0, 1, 2, 3, 4, 5, 6] },
        { hours: [10, 14], weight: 25, days: [1, 2, 3, 4, 5] }
      ]);
    }

    // Shopping trips - typically afternoon/evening
    if (startLocation.type === 'shopping' || endLocation.type === 'shopping') {
      return this.generateTimeInRanges(now, [
        { hours: [14, 18], weight: 50, days: [0, 1, 2, 3, 4, 5, 6] },
        { hours: [10, 13], weight: 30, days: [0, 6] }, // Weekend mornings
        { hours: [19, 21], weight: 20, days: [1, 2, 3, 4, 5] }
      ]);
    }

    // Default pattern
    return this.generateTimeInRanges(now, [
      { hours: [9, 17], weight: 60, days: [1, 2, 3, 4, 5] },
      { hours: [10, 20], weight: 40, days: [0, 6] }
    ]);
  }

  generateTimeInRanges(now, ranges) {
    const totalWeight = ranges.reduce((sum, r) => sum + r.weight, 0);
    let random = Math.random() * totalWeight;

    for (const range of ranges) {
      random -= range.weight;
      if (random <= 0) {
        const day = this.getRandomElement(range.days);
        const hour = Math.floor(Math.random() * (range.hours[1] - range.hours[0])) + range.hours[0];
        const minute = Math.floor(Math.random() * 12) * 5; // 5-minute intervals

        const targetDate = new Date(now);
        targetDate.setDate(targetDate.getDate() + day);
        targetDate.setHours(hour, minute, 0, 0);

        return targetDate;
      }
    }

    // Fallback
    return new Date(now.getTime() + Math.random() * 72 * 60 * 60 * 1000);
  }

  async generateEnhancedRideOffers(count = 15) {
    console.log(`Generating ${count} enhanced ride offers...`);

    for (let i = 0; i < count; i++) {
      try {
        const driver = this.getRandomElement(this.driverProfiles);
        const { startLocation, endLocation } = this.generateRealisticRoute();
        const departureTime = this.generateSmartDepartureTime(startLocation, endLocation);
        const distance = this.calculateDistance(startLocation, endLocation);
        
        // Smart pricing based on distance, time, and demand
        const basePrice = this.calculateSmartPricing(distance, departureTime, startLocation, endLocation);
        
        const rideOffer = {
          driverId: driver.id,
          startLocation: startLocation,
          endLocation: endLocation,
          departureTime: admin.firestore.Timestamp.fromDate(departureTime),
          availableSeats: Math.floor(Math.random() * (driver.vehicleInfo.seats - 1)) + 1,
          totalSeats: driver.vehicleInfo.seats,
          pricePerSeat: basePrice,
          passengerIds: [],
          pendingRequestIds: [],
          status: this.getRandomElement(['active', 'active', 'active', 'full']),
          passengerPickupStatus: {},
          preferences: {
            allowSmoking: driver.preferences.allowSmoking,
            allowPets: driver.preferences.allowPets,
            musicPreference: driver.preferences.musicPreference,
            communicationStyle: driver.preferences.communicationStyle,
            preferredGenders: ['any'],
            maxPassengers: driver.vehicleInfo.seats
          },
          notes: this.generateSmartNotes(driver, startLocation, endLocation, departureTime),
          estimatedDistance: distance,
          estimatedDuration: this.calculateDuration(distance),
          isArchived: false,
          createdAt: admin.firestore.Timestamp.now(),
          updatedAt: admin.firestore.Timestamp.now()
        };

        await db.collection('ride_offers').add(rideOffer);
        console.log(`Created enhanced ride offer: ${startLocation.name} → ${endLocation.name} by ${driver.name}`);
        
        await new Promise(resolve => setTimeout(resolve, 100));

      } catch (error) {
        console.error(`Error creating enhanced ride offer ${i + 1}:`, error);
      }
    }
  }

  calculateSmartPricing(distance, departureTime, startLocation, endLocation) {
    let baseRate = 0.35; // Base rate per mile

    // Time-based pricing
    const hour = departureTime.getHours();
    if (hour >= 7 && hour <= 9 || hour >= 17 && hour <= 19) {
      baseRate *= 1.3; // Peak hours premium
    } else if (hour >= 22 || hour <= 6) {
      baseRate *= 1.2; // Late night/early morning premium
    }

    // Route-based pricing
    if (startLocation.type === 'airport' || endLocation.type === 'airport') {
      baseRate *= 1.4; // Airport premium
    }

    // Calculate final price
    const calculatedPrice = Math.max(5.0, distance * baseRate);
    const priceWithVariation = calculatedPrice * (0.85 + Math.random() * 0.3); // ±15% variation

    return Math.round(priceWithVariation * 100) / 100;
  }

  generateSmartNotes(driver, startLocation, endLocation, departureTime) {
    const notes = [];
    const firstName = driver.name.split(' ')[0];
    
    // Personalized greeting
    notes.push(`Hi! I'm ${firstName}, looking forward to giving you a ride.`);
    
    // Vehicle and preference info
    if (driver.preferences.allowPets) {
      notes.push('Pet-friendly vehicle! Your furry friends are welcome.');
    }
    
    if (driver.preferences.communicationStyle === 'quiet') {
      notes.push('I prefer quieter rides, but feel free to ask if you need anything.');
    } else if (driver.preferences.communicationStyle === 'chatty') {
      notes.push('I love meeting new people and having good conversations!');
    }

    // Route-specific notes
    if (startLocation.type === 'airport' || endLocation.type === 'airport') {
      notes.push('Airport trips welcome! Extra space for luggage in my ' + driver.vehicleInfo.model + '.');
    }

    if (startLocation.type === 'medical' || endLocation.type === 'medical') {
      notes.push('Medical appointments? No worries about timing - I understand these can run long.');
    }

    const hour = departureTime.getHours();
    if (hour <= 7 || hour >= 22) {
      notes.push('Early/late trip - I\'ll keep the music low and maintain a comfortable atmosphere.');
    }

    // Add basic logistics
    notes.push('Please be ready 5 minutes before departure. Text me when you arrive!');

    return this.getRandomElement(notes);
  }

  // Utility methods
  getRandomElement(array) {
    return array[Math.floor(Math.random() * array.length)];
  }

  getRandomElementExcluding(array, exclude) {
    const filtered = array.filter(item => item.name !== exclude.name);
    return this.getRandomElement(filtered);
  }

  getRandomRoute() {
    const startLocation = this.getRandomElement(this.locations);
    const endLocation = this.getRandomElementExcluding(this.locations, startLocation);
    return { startLocation, endLocation };
  }

  calculateDistance(start, end) {
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

  calculateDuration(distance) {
    const estimatedSpeed = distance > 10 ? 45.0 : 25.0;
    const hours = distance / estimatedSpeed;
    return Math.round(hours * 60); // Return minutes
  }

  async clearEnhancedTestData() {
    console.log('Clearing enhanced test data...');
    
    const driverIds = this.driverProfiles.map(d => d.id);
    const riderIds = this.riderProfiles.map(r => r.id);
    
    const rideOffers = await db.collection('ride_offers')
      .where('driverId', 'in', driverIds)
      .get();
    
    const rideRequests = await db.collection('ride_requests')
      .where('requesterId', 'in', riderIds)
      .get();
    
    const batch = db.batch();
    
    rideOffers.docs.forEach(doc => batch.delete(doc.ref));
    rideRequests.docs.forEach(doc => batch.delete(doc.ref));
    
    await batch.commit();
    
    console.log(`Cleared ${rideOffers.docs.length} ride offers and ${rideRequests.docs.length} ride requests`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  const shouldClear = args.includes('--clear');
  const offerCount = parseInt(args[args.indexOf('--offers') + 1]) || 15;
  
  console.log('Starting enhanced Firebase data generation...');
  
  try {
    const generator = new EnhancedDataGenerator();
    
    if (shouldClear) {
      await generator.clearEnhancedTestData();
    }
    
    await generator.generateEnhancedRideOffers(offerCount);
    
    console.log('Enhanced data generation completed successfully.');
    console.log(`Generated ${offerCount} realistic ride offers with smart routing, timing, and pricing.`);
    
  } catch (error) {
    console.error('Error during enhanced data generation:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

if (require.main === module) {
  main();
}

module.exports = { EnhancedDataGenerator };