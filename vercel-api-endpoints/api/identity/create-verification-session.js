// /api/identity/create-verification-session.js
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    // Create verification session
    const verificationSession = await stripe.identity.verificationSessions.create({
      type: 'document',
      metadata: {
        user_id: userId,
      },
      options: {
        document: {
          allowed_types: ['driving_license', 'passport', 'id_card'],
          require_id_number: true,
          require_live_capture: true,
          require_matching_selfie: true,
        },
      },
    });

    // Create ephemeral key for the verification session
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { verification_session: verificationSession.id },
      { apiVersion: '2022-11-15' }
    );

    res.status(200).json({
      success: true,
      verificationSessionId: verificationSession.id,
      ephemeralKeySecret: ephemeralKey.secret,
    });

  } catch (error) {
    console.error('Error creating verification session:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to create verification session',
    });
  }
}