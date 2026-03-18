# Stripe Identity Verification Setup

This document outlines how to set up Stripe Identity verification for driver verification in the Flutter app.

## Frontend Implementation (COMPLETED)

The Flutter app now includes:

- **Stripe Identity Service** (`lib/services/stripe_identity_service.dart`)
- **Two-step verification flow** in the driver verification screen
- **Identity verification first**, then vehicle information collection
- **Visual progress indicators** showing verification status
- **Integration with existing user profile system**

## Backend Setup Required

To complete the Stripe Identity integration, backend endpoints need to be set up:

### 1. Create Verification Session Endpoint

Create an endpoint that:
- Creates a Stripe Identity verification session
- Returns the session ID and ephemeral key secret

```javascript
// Example Node.js/Express endpoint
app.post('/api/create-verification-session', async (req, res) => {
  try {
    const { userId } = req.body;
    
    const verificationSession = await stripe.identity.verificationSessions.create({
      type: 'document',
      metadata: {
        user_id: userId,
      },
    });

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: userId },
      { apiVersion: '2020-08-27' }
    );

    res.json({
      success: true,
      verificationSessionId: verificationSession.id,
      ephemeralKeySecret: ephemeralKey.secret,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: error.message,
    });
  }
});
```

### 2. Webhook for Verification Status

Set up a webhook to handle verification completion:

```javascript
app.post('/api/stripe-webhook', express.raw({type: 'application/json'}), (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return res.status(400).send(`Webhook signature verification failed.`);
  }

  if (event.type === 'identity.verification_session.verified') {
    const verificationSession = event.data.object;
    // Update user verification status in database
    updateUserVerificationStatus(verificationSession.metadata.user_id, 'verified');
  }

  res.json({received: true});
});
```

### 3. Environment Variables

Add to backend environment:

```env
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

### 4. Frontend Configuration

Update the `StripeIdentityService` in the Flutter app:

```dart
// In lib/services/stripe_identity_service.dart
// Replace the mock backend call with actual HTTP request
static const String _backendUrl = 'https://your-backend.com/api';
```

## Testing

### Development Testing

The current implementation includes mock responses for development testing. The app will:

1. Show "Start Identity Verification" button
2. Simulate successful verification (2-step delay)
3. Enable vehicle information form
4. Store verification data in Firestore

### Production Testing

Once backend is set up:

1. Use Stripe test mode initially
2. Test with Stripe's test document images
3. Verify webhook handling
4. Test error scenarios (rejected verification, etc.)

## Stripe Dashboard Configuration

1. Enable Stripe Identity in the dashboard
2. Configure verification settings:
   - Document types accepted
   - Countries supported
   - Verification requirements
3. Set up webhook endpoints
4. Configure test/live modes

## Security Notes

- Never expose Stripe secret keys in the frontend
- Use HTTPS for all webhook endpoints
- Validate webhook signatures
- Store verification results securely
- Consider implementing rate limiting

## Current Status

**Frontend**: Complete two-step verification flow
**UI/UX**: Step-by-step progress indicators
**Data Models**: Driver verification status tracking
**Integration**: Connected to existing user system

**Backend**: Mock implementation (needs real Stripe endpoints)
**Webhooks**: Need to implement status updates
**Production**: Ready for backend integration

## Next Steps

1. Set up Stripe Identity in the Stripe dashboard
2. Implement backend endpoints as described above
3. Replace mock functions in `StripeIdentityService`
4. Test with real Stripe verification flow
5. Deploy and configure webhooks