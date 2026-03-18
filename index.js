import app, { auth, db, storage } from './firebase-config.js';

// Example usage
console.log('Firebase app initialized successfully');

// Example function to test connection
async function testFirebaseConnection() {
  try {
    // Test Firestore connection
    const testDoc = await db.collection('test').add({
      message: 'Hello Firebase!',
      timestamp: new Date()
    });
    console.log('Successfully connected to Firestore. Document ID:', testDoc.id);
  } catch (error) {
    console.error('Error connecting to Firebase:', error);
  }
}

// Uncomment to test connection
// testFirebaseConnection();