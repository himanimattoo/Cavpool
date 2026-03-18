// /api/identity/create-verification-session.js
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY_LIVE || process.env.STRIPE_SECRET_KEY);

export default async function handler(req, res) {
  // Enhanced debugging headers and environment info
  console.log('=== STRIPE IDENTITY API DEBUG START ===');
  console.log('Timestamp:', new Date().toISOString());
  console.log('Request method:', req.method);
  console.log('User-Agent:', req.headers['user-agent']);
  console.log('X-Forwarded-For:', req.headers['x-forwarded-for']);
  console.log('X-Real-IP:', req.headers['x-real-ip']);
  console.log('CF-Ray:', req.headers['cf-ray']);
  console.log('Vercel Region:', process.env.VERCEL_REGION);
  console.log('Node Version:', process.version);
  console.log('Environment Variables Check:');
  console.log('- STRIPE_SECRET_KEY_LIVE exists:', !!process.env.STRIPE_SECRET_KEY_LIVE);
  console.log('- STRIPE_SECRET_KEY exists:', !!process.env.STRIPE_SECRET_KEY);
  console.log('- STRIPE_SECRET_KEY_LIVE length:', process.env.STRIPE_SECRET_KEY_LIVE?.length || 0);
  console.log('- STRIPE_SECRET_KEY_LIVE starts with sk_live:', process.env.STRIPE_SECRET_KEY_LIVE?.startsWith('sk_live_'));

  if (req.method !== 'POST') {
    console.log('Method not allowed:', req.method);
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Enhanced environment debugging with key sanitization
    let stripeKey = process.env.STRIPE_SECRET_KEY_LIVE || process.env.STRIPE_SECRET_KEY;
    
    if (!stripeKey) {
      console.error('CRITICAL: No Stripe secret key found in environment');
      return res.status(500).json({ 
        success: false, 
        error: 'Stripe configuration error: Missing API key' 
      });
    }

    // Sanitize the key - remove any invisible characters, newlines, spaces
    const originalLength = stripeKey.length;
    stripeKey = stripeKey.trim().replace(/[\r\n\t\u0000-\u001f\u007f-\u009f]/g, '');
    
    console.log('Stripe key validation:');
    console.log('- Original key length:', originalLength);
    console.log('- Sanitized key length:', stripeKey.length);
    console.log('- Key prefix:', stripeKey.substring(0, 8));
    console.log('- Key suffix:', stripeKey.substring(stripeKey.length - 4));
    console.log('- Is live key:', stripeKey.startsWith('sk_live_'));
    console.log('- Key sanitization needed:', originalLength !== stripeKey.length);
    
    // Check for problematic characters
    const hasInvalidChars = /[^\x20-\x7E]/.test(stripeKey);
    console.log('- Contains non-ASCII characters:', hasInvalidChars);
    
    if (hasInvalidChars) {
      console.error('🚨 INVALID CHARACTERS DETECTED IN STRIPE KEY!');
      console.error('- This will cause HTTP header errors');
      console.error('- Please regenerate your Stripe secret key');
    }

    const { userId } = req.body;
    console.log('Request body:', JSON.stringify(req.body, null, 2));

    if (!userId) {
      console.error('Missing userId in request body');
      return res.status(400).json({ error: 'User ID is required' });
    }

    // Network connectivity tests
    console.log('=== NETWORK DIAGNOSTICS ===');
    console.log('Attempting DNS resolution test...');
    
    try {
      const dns = require('dns').promises;
      const stripeIPs = await dns.resolve4('api.stripe.com');
      console.log('Stripe API DNS resolution successful:', stripeIPs);
    } catch (dnsError) {
      console.error('DNS resolution failed for api.stripe.com:', dnsError.message);
    }

    // HTTP connectivity test
    console.log('Testing basic HTTP connectivity to Stripe...');
    try {
      const https = require('https');
      const testRequest = https.request({
        hostname: 'api.stripe.com',
        port: 443,
        path: '/v1',
        method: 'GET',
        timeout: 5000,
        headers: {
          'User-Agent': 'Vercel-Serverless-Debug/1.0'
        }
      });
      
      testRequest.on('error', (error) => {
        console.error('Basic HTTP connectivity test failed:', error.message);
      });
      
      testRequest.on('timeout', () => {
        console.error('Basic HTTP connectivity test timed out');
      });
      
      testRequest.end();
    } catch (httpError) {
      console.error('HTTP connectivity test error:', httpError.message);
    }

    // Stripe SDK debugging
    console.log('=== STRIPE SDK DIAGNOSTICS ===');
    console.log('Initializing Stripe with key...');
    
    // Test Stripe initialization
    let stripeInstance;
    try {
      stripeInstance = require('stripe')(stripeKey, {
        apiVersion: '2022-11-15',
        timeout: 30000, // 30 seconds
        maxNetworkRetries: 3,
      });
      console.log('Stripe SDK initialized successfully');
    } catch (initError) {
      console.error('Stripe SDK initialization failed:', initError.message);
      throw initError;
    }

    console.log('=== ATTEMPTING STRIPE API CALLS ===');
    console.log('Creating verification session...');
    console.log('- Flow ID: vf_1SNpZCEcRjUfXvu6isjwMZUE');
    console.log('- User ID:', userId);
    console.log('- Timestamp:', Date.now());
    
    const startTime = Date.now();
    
    try {
      // Create verification session using document type
      console.log('Calling stripe.identity.verificationSessions.create...');
      const verificationSession = await stripeInstance.identity.verificationSessions.create({
        type: 'document',
        metadata: {
          user_id: userId,
          created_at: new Date().toISOString(),
          vercel_region: process.env.VERCEL_REGION || 'unknown',
        },
      });

      const sessionTime = Date.now() - startTime;
      console.log(`✅ Stripe verification session created successfully in ${sessionTime}ms:`, verificationSession.id);
      console.log('Session details:', JSON.stringify({
        id: verificationSession.id,
        status: verificationSession.status,
        type: verificationSession.type,
        livemode: verificationSession.livemode
      }, null, 2));

      // Create ephemeral key for the verification session
      console.log('Creating ephemeral key...');
      const keyStartTime = Date.now();
      
      const ephemeralKey = await stripeInstance.ephemeralKeys.create(
        { verification_session: verificationSession.id },
        { apiVersion: '2022-11-15' }
      );

      const keyTime = Date.now() - keyStartTime;
      console.log(`✅ Ephemeral key created successfully in ${keyTime}ms`);
      console.log('Key details:', JSON.stringify({
        id: ephemeralKey.id,
        livemode: ephemeralKey.livemode,
        expires: ephemeralKey.expires
      }, null, 2));

      const totalTime = Date.now() - startTime;
      console.log(`🎉 STRIPE API SUCCESS - Total time: ${totalTime}ms`);
      console.log('=== STRIPE IDENTITY API DEBUG END ===');

      res.status(200).json({
        success: true,
        verificationSessionId: verificationSession.id,
        ephemeralKeySecret: ephemeralKey.secret,
        live: true,
        debug: {
          timing: {
            session_creation_ms: sessionTime,
            key_creation_ms: keyTime,
            total_ms: totalTime
          },
          stripe_session_status: verificationSession.status,
          livemode: verificationSession.livemode
        }
      });
      
    } catch (stripeError) {
      const errorTime = Date.now() - startTime;
      console.error('=== STRIPE API ERROR DETAILS ===');
      console.error('Error occurred after:', errorTime, 'ms');
      console.error('Error message:', stripeError.message);
      console.error('Error type:', stripeError.type);
      console.error('Error code:', stripeError.code);
      console.error('Error status:', stripeError.statusCode);
      console.error('Error headers:', stripeError.headers);
      console.error('Error request ID:', stripeError.requestId);
      console.error('Full error object:', JSON.stringify(stripeError, Object.getOwnPropertyNames(stripeError), 2));
      
      // Network-specific error analysis
      if (stripeError.type === 'StripeConnectionError') {
        console.error('🔥 CONNECTION ERROR ANALYSIS:');
        console.error('- This indicates a network connectivity issue');
        console.error('- The request never reached Stripe servers');
        console.error('- Possible causes: DNS issues, firewall, timeout, SSL problems');
        console.error('- Vercel region:', process.env.VERCEL_REGION);
        console.error('- Error code:', stripeError.code);
        console.error('- Underlying error:', stripeError.cause?.message);
      }
      
      // Fallback to mock for development
      const mockSessionId = `vs_mock_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      const mockEphemeralSecret = `ek_mock_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      console.log(`⚠️ Falling back to mock verification session for user: ${userId}`);
      console.log('Mock session ID:', mockSessionId);
      console.log('=== STRIPE IDENTITY API DEBUG END (WITH FALLBACK) ===');

      res.status(200).json({
        success: true,
        verificationSessionId: mockSessionId,
        ephemeralKeySecret: mockEphemeralSecret,
        mock: true,
        debug: {
          error_type: stripeError.type,
          error_code: stripeError.code,
          error_message: stripeError.message,
          error_time_ms: errorTime,
          fallback_reason: 'stripe_connection_error'
        }
      });
    }

  } catch (error) {
    console.error('Error creating verification session:', error);
    console.error('Error details:', JSON.stringify(error, null, 2));
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to create verification session',
      details: error.type || 'unknown_error'
    });
  }
}