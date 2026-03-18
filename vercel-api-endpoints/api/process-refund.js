// /api/process-refund.js
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { payment_intent_id, amount, reason = 'requested_by_customer' } = req.body;

    if (!payment_intent_id) {
      return res.status(400).json({ error: 'Payment intent ID is required' });
    }

    // Create refund
    const refundData = {
      payment_intent: payment_intent_id,
      reason,
    };

    // If partial refund amount is specified
    if (amount && amount > 0) {
      refundData.amount = Math.round(amount * 100); // Convert to cents
    }

    const refund = await stripe.refunds.create(refundData);

    res.status(200).json({
      success: true,
      refund_id: refund.id,
      amount_refunded: refund.amount / 100, // Convert back to dollars
      status: refund.status,
    });

  } catch (error) {
    console.error('Error processing refund:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to process refund',
    });
  }
}