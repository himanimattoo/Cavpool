// Test basic Stripe connectivity
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY_LIVE || process.env.STRIPE_SECRET_KEY);

export default async function handler(req, res) {
  try {
    // Simple test - list payment methods (should work if keys are valid)
    const customers = await stripe.customers.list({ limit: 1 });
    
    res.status(200).json({
      success: true,
      message: 'Stripe connection works',
      hasCustomers: customers.data.length > 0
    });
  } catch (error) {
    console.error('Stripe test error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      type: error.type
    });
  }
}