// /api/stripe-webhook.js
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const admin = require('firebase-admin');

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    }),
  });
}

const db = admin.firestore();

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const sig = req.headers['stripe-signature'];
  let event;

  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    // Handle the event
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSuccess(event.data.object);
        break;
      
      case 'payment_intent.payment_failed':
        await handlePaymentFailure(event.data.object);
        break;
      
      case 'identity.verification_session.verified':
        await handleIdentityVerified(event.data.object);
        break;
      
      case 'identity.verification_session.requires_input':
        await handleIdentityRequiresInput(event.data.object);
        break;
      
      default:
        console.log(`Unhandled event type ${event.type}`);
    }

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Error processing webhook:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
}

async function handlePaymentSuccess(paymentIntent) {
  const { metadata } = paymentIntent;
  
  if (metadata.ride_id && metadata.customer_id) {
    try {
      // Update ride status in Firestore
      await db.collection('rides').doc(metadata.ride_id).update({
        paymentStatus: 'paid',
        paymentIntentId: paymentIntent.id,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update user's payment history
      await db.collection('users').doc(metadata.customer_id).collection('payments').add({
        paymentIntentId: paymentIntent.id,
        rideId: metadata.ride_id,
        amount: paymentIntent.amount / 100,
        status: 'succeeded',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Payment succeeded for ride ${metadata.ride_id}`);
    } catch (error) {
      console.error('Error updating payment status:', error);
    }
  }
}

async function handlePaymentFailure(paymentIntent) {
  const { metadata } = paymentIntent;
  
  if (metadata.ride_id) {
    try {
      await db.collection('rides').doc(metadata.ride_id).update({
        paymentStatus: 'failed',
        paymentError: paymentIntent.last_payment_error?.message || 'Payment failed',
      });

      console.log(`Payment failed for ride ${metadata.ride_id}`);
    } catch (error) {
      console.error('Error updating payment failure:', error);
    }
  }
}

async function handleIdentityVerified(verificationSession) {
  const { metadata } = verificationSession;
  
  if (metadata.user_id) {
    try {
      await db.collection('users').doc(metadata.user_id).update({
        driverVerificationStatus: 'approved',
        identityVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Identity verified for user ${metadata.user_id}`);
    } catch (error) {
      console.error('Error updating identity verification:', error);
    }
  }
}

async function handleIdentityRequiresInput(verificationSession) {
  const { metadata } = verificationSession;
  
  if (metadata.user_id) {
    try {
      await db.collection('users').doc(metadata.user_id).update({
        driverVerificationStatus: 'requires_input',
      });

      console.log(`Identity verification requires input for user ${metadata.user_id}`);
    } catch (error) {
      console.error('Error updating identity verification status:', error);
    }
  }
}

// This is important for Vercel
export const config = {
  api: {
    bodyParser: {
      sizeLimit: '1mb',
    },
  },
}