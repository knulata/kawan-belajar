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

// ─── WhatsApp Integration ───────────────────────────────────────────
// Uses WhatsApp Business API (Meta Cloud API)
// Set WHATSAPP_TOKEN and WHATSAPP_PHONE_ID env vars

const WHATSAPP_TOKEN = process.env.WHATSAPP_TOKEN;
const WHATSAPP_PHONE_ID = process.env.WHATSAPP_PHONE_ID;

// In-memory scheduled reminders (use a database in production)
const scheduledReminders = [];

async function sendWhatsAppMessage(phone, message) {
  if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
    console.log('[WhatsApp] Skipped (no credentials):', phone, message);
    return { success: true, simulated: true };
  }

  try {
    const response = await fetch(
      `https://graph.facebook.com/v18.0/${WHATSAPP_PHONE_ID}/messages`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: phone,
          type: 'text',
          text: { body: message },
        }),
      }
    );

    const data = await response.json();
    return { success: response.ok, data };
  } catch (error) {
    console.error('[WhatsApp] Send error:', error);
    return { success: false, error: error.message };
  }
}

// Send WhatsApp alert (immediate)
app.post('/api/whatsapp/send', async (req, res) => {
  const { phone, parent_name, student_name, alert_type, message } = req.body;

  if (!phone || !message) {
    return res.status(400).json({ error: 'Phone and message required' });
  }

  const header = `🦉 *Kawan Belajar*\n\n`;
  const fullMessage = header + message;

  const result = await sendWhatsAppMessage(phone, fullMessage);
  console.log(`[WhatsApp] Alert sent to ${phone} (${alert_type}):`, result.success);
  res.json({ success: result.success });
});

// Schedule a reminder
app.post('/api/whatsapp/schedule', async (req, res) => {
  const { phone, parent_name, student_name, title, subject, due_date, type } = req.body;

  if (!phone || !title || !due_date) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const reminder = {
    id: Date.now().toString(),
    phone,
    parent_name,
    student_name,
    title,
    subject,
    due_date: new Date(due_date),
    type,
    notified_1day: false,
    notified_same_day: false,
    created_at: new Date(),
  };

  scheduledReminders.push(reminder);
  console.log(`[WhatsApp] Reminder scheduled: "${title}" for ${due_date}`);
  res.json({ success: true, id: reminder.id });
});

// Send daily study summary
app.post('/api/whatsapp/daily-summary', async (req, res) => {
  const {
    phone,
    parent_name,
    student_name,
    minutes_studied,
    stars_earned,
    subjects_studied,
    streak_days,
  } = req.body;

  if (!phone || !student_name) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const subjectList = subjects_studied && subjects_studied.length > 0
    ? subjects_studied.join(', ')
    : 'Belum belajar hari ini';

  const message =
    `🦉 *Kawan Belajar — Laporan Harian*\n\n` +
    `Halo ${parent_name}! Ini laporan belajar ${student_name} hari ini:\n\n` +
    `⏱️ Waktu belajar: ${minutes_studied} menit\n` +
    `⭐ Bintang diraih: ${stars_earned}\n` +
    `📚 Pelajaran: ${subjectList}\n` +
    `🔥 Streak: ${streak_days} hari berturut-turut\n\n` +
    (minutes_studied > 30
      ? `${student_name} belajar dengan rajin hari ini! 💪`
      : minutes_studied > 0
        ? `${student_name} sudah mulai belajar. Semangat terus!`
        : `${student_name} belum belajar hari ini. Ingatkan ya! 📖`);

  const result = await sendWhatsAppMessage(phone, message);
  res.json({ success: result.success });
});

// Check scheduled reminders every hour
setInterval(() => {
  const now = new Date();

  for (const reminder of scheduledReminders) {
    const dueDate = new Date(reminder.due_date);
    const hoursUntilDue = (dueDate - now) / (1000 * 60 * 60);

    // 1-day before reminder
    if (hoursUntilDue > 0 && hoursUntilDue <= 24 && !reminder.notified_1day) {
      const typeLabel = reminder.type === 'test' ? 'Ujian' : 'PR';
      const message =
        `🦉 *Kawan Belajar — Pengingat*\n\n` +
        `Halo ${reminder.parent_name}!\n\n` +
        `⏰ *${typeLabel} besok!*\n` +
        `📚 ${reminder.subject}: ${reminder.title}\n` +
        `📅 Tenggat: ${dueDate.toLocaleDateString('id-ID')}\n\n` +
        `Ingatkan ${reminder.student_name} untuk mempersiapkan ya!`;

      sendWhatsAppMessage(reminder.phone, message);
      reminder.notified_1day = true;
      console.log(`[WhatsApp] 1-day reminder sent for: ${reminder.title}`);
    }

    // Same-day morning reminder
    if (hoursUntilDue > 0 && hoursUntilDue <= 12 && !reminder.notified_same_day) {
      const typeLabel = reminder.type === 'test' ? 'Ujian' : 'PR';
      const message =
        `🦉 *Kawan Belajar — Pengingat HARI INI*\n\n` +
        `Halo ${reminder.parent_name}!\n\n` +
        `🚨 *${typeLabel} HARI INI!*\n` +
        `📚 ${reminder.subject}: ${reminder.title}\n\n` +
        `Pastikan ${reminder.student_name} sudah siap ya! Semangat! 💪`;

      sendWhatsAppMessage(reminder.phone, message);
      reminder.notified_same_day = true;
      console.log(`[WhatsApp] Same-day reminder sent for: ${reminder.title}`);
    }
  }

  // Clean up old reminders (past due by more than 2 days)
  const twoDaysAgo = new Date(now - 2 * 24 * 60 * 60 * 1000);
  for (let i = scheduledReminders.length - 1; i >= 0; i--) {
    if (new Date(scheduledReminders[i].due_date) < twoDaysAgo) {
      scheduledReminders.splice(i, 1);
    }
  }
}, 60 * 60 * 1000); // Check every hour

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Kawan Belajar API',
    whatsapp_configured: !!(WHATSAPP_TOKEN && WHATSAPP_PHONE_ID),
    scheduled_reminders: scheduledReminders.length,
  });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🦉 Kawan Belajar API running on port ${PORT}`);
});
