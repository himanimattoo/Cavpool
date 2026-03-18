const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// You'll need to set up your service account key
const serviceAccount = require('./serviceAccountKey.json'); // You'll need to download this from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://cavpool-default-rtdb.firebaseio.com'
});

const auth = admin.auth();
const firestore = admin.firestore();

async function createTestUser() {
  try {
    // Create test user for Apple Review
    const testUserData = {
      email: 'reviewer@virginia.edu',
      password: 'AppReview2024!',
      displayName: 'App Reviewer'
    };

    console.log('Creating test user...');

    // Create user in Firebase Auth
    const userRecord = await auth.createUser({
      email: testUserData.email,
      password: testUserData.password,
      displayName: testUserData.displayName,
      emailVerified: true
    });

    console.log('User created successfully:', userRecord.uid);

    // Create user document in Firestore
    const userDoc = {
      uid: userRecord.uid,
      email: testUserData.email,
      profile: {
        firstName: 'App',
        lastName: 'Reviewer',
        displayName: testUserData.displayName,
        photoURL: '',
        pronouns: 'they/them',
        bio: 'Test account for Apple App Review',
        phoneNumber: '+1-555-0123'
      },
      accountType: 'rider',
      isVerified: true, // Pre-verify for testing
      emergencyContacts: [
        {
          name: 'Emergency Contact',
          phone: '+1-555-0199',
          relationship: 'Family'
        }
      ],
      preferences: {
        allowSmoking: false,
        allowPets: true,
        musicPreference: 'driver_choice',
        communicationStyle: 'friendly',
        preferredGenders: ['any'],
        maxPassengers: 4
      },
      ratings: {
        averageRating: 4.8,
        totalRatings: 12,
        asDriver: {
          averageRating: 4.9,
          totalRatings: 5
        },
        asRider: {
          averageRating: 4.7,
          totalRatings: 7
        }
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await firestore.collection('users').doc(userRecord.uid).set(userDoc);
    console.log('User document created in Firestore');

    // Create some sample ride offer data for testing
    const sampleRides = [
      {
        driverId: userRecord.uid,
        startLocation: {
          address: 'University of Virginia, Charlottesville, VA',
          coordinates: {
            latitude: 38.0336,
            longitude: -78.5080
          },
          name: 'UVA Campus'
        },
        endLocation: {
          address: '1500 E Main St, Richmond, VA 23219',
          coordinates: {
            latitude: 37.5407,
            longitude: -77.4360
          },
          name: 'Richmond Main Street Station'
        },
        departureTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 24 * 60 * 60 * 1000)),
        availableSeats: 3,
        totalSeats: 4,
        pricePerSeat: 25.00,
        passengerIds: [],
        pendingRequestIds: [],
        status: 'active',
        passengerPickupStatus: {},
        preferences: {
          allowSmoking: false,
          allowPets: true,
          musicPreference: 'driver_choice',
          communicationStyle: 'friendly',
          preferredGenders: ['any'],
          maxPassengers: 4
        },
        notes: 'Comfortable ride to Richmond. AC and music available.',
        estimatedDistance: 71.2,
        estimatedDuration: 95,
        isArchived: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      {
        driverId: userRecord.uid,
        startLocation: {
          address: 'University of Virginia, Charlottesville, VA',
          coordinates: {
            latitude: 38.0336,
            longitude: -78.5080
          },
          name: 'UVA Campus'
        },
        endLocation: {
          address: '50 Massachusetts Ave NE, Washington, DC 20002',
          coordinates: {
            latitude: 38.8973,
            longitude: -77.0065
          },
          name: 'Washington DC Union Station'
        },
        departureTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 5 * 24 * 60 * 60 * 1000)),
        availableSeats: 2,
        totalSeats: 4,
        pricePerSeat: 35.00,
        passengerIds: [],
        pendingRequestIds: [],
        status: 'active',
        passengerPickupStatus: {},
        preferences: {
          allowSmoking: false,
          allowPets: false,
          musicPreference: 'passenger_choice',
          communicationStyle: 'quiet',
          preferredGenders: ['any'],
          maxPassengers: 4
        },
        notes: 'Going to DC for the weekend. Safe and reliable.',
        estimatedDistance: 117.8,
        estimatedDuration: 140,
        isArchived: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }
    ];

    // Add sample ride offers
    for (const ride of sampleRides) {
      await firestore.collection('ride_offers').add(ride);
      console.log('Sample ride offer added');
    }

    console.log('\\nTest user creation completed successfully.');
    console.log('\\nTest Account Details for Apple Review:');
    console.log(`Email: ${testUserData.email}`);
    console.log(`Password: ${testUserData.password}`);
    console.log(`\\nUser ID: ${userRecord.uid}`);
    console.log('\\nAccount Features:');
    console.log('- Account is pre-verified for testing');
    console.log('- Sample ride data has been added');
    console.log('- Emergency contact information is populated');
    console.log('- User has sample ratings for credibility');

  } catch (error) {
    console.error('Error creating test user:', error);
  }
}

// Create demo user as well
async function createDemoUser() {
  try {
    const demoUserData = {
      email: 'demo.reviewer@virginia.edu',
      password: 'DemoAccount123!',
      displayName: 'Demo User'
    };

    console.log('\\nCreating demo user...');

    const userRecord = await auth.createUser({
      email: demoUserData.email,
      password: demoUserData.password,
      displayName: demoUserData.displayName,
      emailVerified: true
    });

    const userDoc = {
      uid: userRecord.uid,
      email: demoUserData.email,
      profile: {
        firstName: 'Demo',
        lastName: 'User',
        displayName: demoUserData.displayName,
        photoURL: '',
        pronouns: 'they/them',
        bio: 'Demo account for testing features',
        phoneNumber: '+1-555-0124'
      },
      accountType: 'driver',
      isVerified: true,
      emergencyContacts: [],
      preferences: {
        allowSmoking: false,
        allowPets: false,
        musicPreference: 'passenger_choice',
        communicationStyle: 'quiet',
        preferredGenders: ['any'],
        maxPassengers: 4
      },
      ratings: {
        averageRating: 4.6,
        totalRatings: 8,
        asDriver: {
          averageRating: 4.8,
          totalRatings: 5
        },
        asRider: {
          averageRating: 4.3,
          totalRatings: 3
        }
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await firestore.collection('users').doc(userRecord.uid).set(userDoc);
    console.log('Demo user document created in Firestore');

    console.log('\\nDemo user creation completed successfully.');
    console.log(`Email: ${demoUserData.email}`);
    console.log(`Password: ${demoUserData.password}`);

  } catch (error) {
    console.error('Error creating demo user:', error);
  }
}

async function main() {
  await createTestUser();
  await createDemoUser();
  process.exit(0);
}

main();