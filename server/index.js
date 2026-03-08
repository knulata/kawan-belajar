// Kawan Belajar — API Proxy Server
// Keeps the OpenAI API key on the server, never exposed to students
//
// Deploy options:
//   - Vercel: vercel deploy (uses api/ folder)
//   - Railway/Render: node server/index.js
//   - Local: node server/index.js

const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!OPENAI_API_KEY) {
  console.error('ERROR: Set OPENAI_API_KEY environment variable');
  process.exit(1);
}

// Rate limiting per student (simple in-memory)
const rateLimits = new Map();
const RATE_LIMIT = 30; // requests per minute
const RATE_WINDOW = 60 * 1000;

function checkRateLimit(studentId) {
  const now = Date.now();
  const key = studentId || 'anonymous';

  if (!rateLimits.has(key)) {
    rateLimits.set(key, []);
  }

  const timestamps = rateLimits.get(key).filter(t => now - t < RATE_WINDOW);

  if (timestamps.length >= RATE_LIMIT) {
    return false;
  }

  timestamps.push(now);
  rateLimits.set(key, timestamps);
  return true;
}

// Main chat endpoint
app.post('/api/chat', async (req, res) => {
  const { messages, student_id, max_tokens = 1500, temperature = 0.7 } = req.body;

  if (!checkRateLimit(student_id)) {
    return res.status(429).json({ error: 'Terlalu banyak permintaan. Tunggu sebentar ya!' });
  }

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        messages,
        max_tokens,
        temperature,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('OpenAI API error:', response.status, error);
      return res.status(response.status).json({ error: 'AI sedang sibuk, coba lagi ya!' });
    }

    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Server error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'Kawan Belajar API' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🦉 Kawan Belajar API running on port ${PORT}`);
});
