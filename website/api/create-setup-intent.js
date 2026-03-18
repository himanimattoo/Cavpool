// /api/create-setup-intent.js
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { customer_id } = req.body;

    if (!customer_id) {
      return res.status(400).json({ error: 'Customer ID is required' });
    }

    // Create or get customer
    let customer;
    try {
      customer = await stripe.customers.retrieve(customer_id);
    } catch (error) {
      // If customer doesn't exist, create one
      customer = await stripe.customers.create({
        id: customer_id,
        metadata: {
          firebase_uid: customer_id,
        },
      });
    }

    // Create setup intent
    const setupIntent = await stripe.setupIntents.create({
      customer: customer.id,
      payment_method_types: ['card'],
      usage: 'off_session',
    });

    res.status(200).json({
      success: true,
      client_secret: setupIntent.client_secret,
      setup_intent_id: setupIntent.id,
    });

  } catch (error) {
    console.error('Error creating setup intent:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to create setup intent',
    });
  }
}