export default async function handler(req, res) {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { place_id, fields = 'geometry,formatted_address,name' } = req.query;

  if (!place_id) {
    return res.status(400).json({ error: 'place_id parameter is required' });
  }

  const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
  
  if (!GOOGLE_API_KEY) {
    return res.status(500).json({ error: 'Google Maps API key not configured' });
  }

  try {
    const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${encodeURIComponent(place_id)}&key=${GOOGLE_API_KEY}&fields=${fields}`;
    
    const response = await fetch(url);
    const data = await response.json();

    if (!response.ok) {
      return res.status(response.status).json({ error: 'Google API error', details: data });
    }

    res.status(200).json(data);
  } catch (error) {
    console.error('Places Details API error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}