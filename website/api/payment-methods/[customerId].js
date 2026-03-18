// /api/payment-methods/[customerId].js
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { customerId } = req.query;

    if (!customerId) {
      return res.status(400).json({ error: 'Customer ID is required' });
    }

    // Get customer's payment methods
    let paymentMethods = [];
    try {
      const customer = await stripe.customers.retrieve(customerId);
      const methods = await stripe.paymentMethods.list({
        customer: customer.id,
        type: 'card',
      });
      paymentMethods = methods.data;
    } catch (error) {
      // Customer might not exist yet
      console.log('Customer not found:', customerId);
    }

    // Format payment methods for frontend
    const formattedMethods = paymentMethods.map(method => ({
      id: method.id,
      type: method.type,
      card: method.card ? {
        brand: method.card.brand,
        last4: method.card.last4,
        exp_month: method.card.exp_month,
        exp_year: method.card.exp_year,
      } : null,
    }));

    res.status(200).json({
      success: true,
      payment_methods: formattedMethods,
    });

  } catch (error) {
    console.error('Error fetching payment methods:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch payment methods',
    });
  }
}