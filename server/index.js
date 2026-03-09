// Kawabel — API Proxy Server
// Keeps the OpenAI API key on the server, never exposed to students
//
// Deploy options:
//   - Vercel: vercel deploy (uses api/ folder)
//   - Railway/Render: node server/index.js
//   - Local: node server/index.js

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');
const cron = require('node-cron');
const path = require('path');
const { filterInput, filterOutput } = require('./middleware/safety');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Serve admin dashboard static files
app.use('/admin', express.static(path.join(__dirname, 'public', 'admin')));

// Serve public pages (leaderboard, etc.)
app.use(express.static(path.join(__dirname, 'public')));

// Serve question bank data
app.use('/data', express.static(path.join(__dirname, 'data')));

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const FONNTE_TOKEN = process.env.FONNTE_TOKEN;

if (!OPENAI_API_KEY) {
  console.error('ERROR: Set OPENAI_API_KEY environment variable');
  process.exit(1);
}

if (!FONNTE_TOKEN) {
  console.warn('WARNING: FONNTE_TOKEN not set — WhatsApp notifications will be disabled');
}

// ---------------------------------------------------------------------------
// Database setup
// ---------------------------------------------------------------------------
const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'kawabel.db');
const db = new Database(DB_PATH);

// Enable WAL mode for better concurrency
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

function initDatabase() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS centers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      address TEXT,
      admin_phone TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS students (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      grade TEXT,
      phone TEXT,
      parent_phone TEXT,
      parent_name TEXT,
      center_id INTEGER REFERENCES centers(id),
      stars INTEGER DEFAULT 0,
      level INTEGER DEFAULT 1,
      pin TEXT UNIQUE,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL REFERENCES students(id),
      subject TEXT,
      topic TEXT,
      started_at TEXT DEFAULT (datetime('now')),
      ended_at TEXT,
      last_activity TEXT DEFAULT (datetime('now')),
      messages_count INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS progress (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL REFERENCES students(id),
      subject TEXT,
      topic TEXT,
      score INTEGER,
      total INTEGER,
      type TEXT CHECK(type IN ('homework','test','dictation')),
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS assignments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      center_id INTEGER REFERENCES centers(id),
      title TEXT NOT NULL,
      subject TEXT,
      topic TEXT,
      type TEXT CHECK(type IN ('homework','test','dictation')),
      grade TEXT,
      description TEXT,
      due_date TEXT,
      created_by TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER REFERENCES students(id),
      assignment_id INTEGER REFERENCES assignments(id),
      phone TEXT,
      message TEXT,
      sent_at TEXT,
      status TEXT DEFAULT 'pending'
    );

    CREATE TABLE IF NOT EXISTS usage (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id TEXT NOT NULL,
      date TEXT NOT NULL,
      request_count INTEGER DEFAULT 0,
      image_count INTEGER DEFAULT 0,
      UNIQUE(student_id, date)
    );
  `);

  console.log('Database initialized at', DB_PATH);
}

initDatabase();

// ---------------------------------------------------------------------------
// PIN helpers & migration for existing students
// ---------------------------------------------------------------------------
function generateUniquePin() {
  const existing = new Set(
    db.prepare("SELECT pin FROM students WHERE pin IS NOT NULL").all().map(r => r.pin)
  );
  let pin;
  let attempts = 0;
  do {
    pin = String(Math.floor(1000 + Math.random() * 9000)); // 1000-9999
    attempts++;
    if (attempts > 5000) throw new Error('Cannot generate unique PIN — table may be full');
  } while (existing.has(pin));
  return pin;
}

// Add pin column if it doesn't exist (for existing databases)
try {
  db.prepare("SELECT pin FROM students LIMIT 1").get();
} catch {
  db.exec("ALTER TABLE students ADD COLUMN pin TEXT UNIQUE");
  console.log('Added pin column to students table');
}

// Add last_activity column to sessions if missing
try {
  db.prepare("SELECT last_activity FROM sessions LIMIT 1").get();
} catch {
  db.exec("ALTER TABLE sessions ADD COLUMN last_activity TEXT DEFAULT (datetime('now'))");
  console.log('Added last_activity column to sessions table');
}

// Auto-generate PINs for existing students that don't have one
{
  const withoutPin = db.prepare("SELECT id FROM students WHERE pin IS NULL").all();
  if (withoutPin.length > 0) {
    const updateStmt = db.prepare("UPDATE students SET pin = ? WHERE id = ?");
    const assign = db.transaction(() => {
      for (const row of withoutPin) {
        updateStmt.run(generateUniquePin(), row.id);
      }
    });
    assign();
    console.log(`Auto-generated PINs for ${withoutPin.length} existing student(s)`);
  }
}

// ---------------------------------------------------------------------------
// Rate limiting per student (simple in-memory)
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// WhatsApp notification via Fonnte
// ---------------------------------------------------------------------------
async function sendWhatsApp(phone, message) {
  if (!FONNTE_TOKEN) {
    console.warn('Fonnte token not configured, skipping notification to', phone);
    return { success: false, reason: 'no_token' };
  }

  try {
    const response = await fetch('https://api.fonnte.com/send', {
      method: 'POST',
      headers: {
        'Authorization': FONNTE_TOKEN,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        target: phone,
        message: message,
        countryCode: '62',
      }),
    });

    const data = await response.json();
    return { success: response.ok, data };
  } catch (error) {
    console.error('Fonnte API error:', error);
    return { success: false, error: error.message };
  }
}

async function sendHomeworkReminder(student, assignment) {
  const message =
    `Halo ${student.parent_name}! ${student.name} punya tugas ${assignment.subject}: ${assignment.topic} yang harus dikerjakan sebelum ${assignment.due_date}. Yuk ingatkan untuk belajar dengan Kawabel! \u{1F989}`;

  const result = await sendWhatsApp(student.parent_phone, message);

  db.prepare(`
    INSERT INTO notifications (student_id, assignment_id, phone, message, sent_at, status)
    VALUES (?, ?, ?, ?, datetime('now'), ?)
  `).run(
    student.id,
    assignment.id,
    student.parent_phone,
    message,
    result.success ? 'sent' : 'failed'
  );

  return result;
}

async function sendTestReminder(student, subject, date) {
  const message =
    `Halo ${student.parent_name}! ${student.name} akan ada ujian ${subject} tanggal ${date}. Yuk latihan di Kawabel! \u{1F989}`;

  const result = await sendWhatsApp(student.parent_phone, message);

  db.prepare(`
    INSERT INTO notifications (student_id, phone, message, sent_at, status)
    VALUES (?, ?, ?, datetime('now'), ?)
  `).run(
    student.id,
    student.parent_phone,
    message,
    result.success ? 'sent' : 'failed'
  );

  return result;
}

async function sendWeeklyReport(student) {
  // Count sessions in last 7 days
  const sessionCount = db.prepare(`
    SELECT COUNT(*) as count FROM sessions
    WHERE student_id = ? AND started_at >= datetime('now', '-7 days')
  `).get(student.id).count;

  // Best and weakest topics in last 7 days
  const topicScores = db.prepare(`
    SELECT subject, topic, AVG(CAST(score AS REAL) / total) as avg_pct
    FROM progress
    WHERE student_id = ? AND created_at >= datetime('now', '-7 days') AND total > 0
    GROUP BY subject, topic
    ORDER BY avg_pct DESC
  `).all(student.id);

  const best = topicScores.length > 0
    ? `${topicScores[0].subject} - ${topicScores[0].topic}`
    : '-';
  const weak = topicScores.length > 1
    ? `${topicScores[topicScores.length - 1].subject} - ${topicScores[topicScores.length - 1].topic}`
    : '-';

  const message =
    `Laporan Mingguan ${student.name}:\n\u{2B50} Bintang: ${student.stars}\n\u{1F4CA} Sesi belajar: ${sessionCount}\n\u{1F4AA} Topik terkuat: ${best}\n\u{1F4DA} Perlu latihan: ${weak}\n\nTerus semangat! \u{1F989}`;

  const result = await sendWhatsApp(student.parent_phone, message);

  db.prepare(`
    INSERT INTO notifications (student_id, phone, message, sent_at, status)
    VALUES (?, ?, ?, datetime('now'), ?)
  `).run(
    student.id,
    student.parent_phone,
    message,
    result.success ? 'sent' : 'failed'
  );

  return result;
}

// ---------------------------------------------------------------------------
// Scheduled jobs (node-cron)
// ---------------------------------------------------------------------------

// Daily at 16:00 WIB (09:00 UTC) — homework reminders for assignments due in next 2 days
cron.schedule('0 9 * * *', async () => {
  console.log('Running daily homework reminder job...');
  try {
    const assignments = db.prepare(`
      SELECT * FROM assignments
      WHERE due_date BETWEEN date('now') AND date('now', '+2 days')
    `).all();

    for (const assignment of assignments) {
      // Get students at the same center (or all students if no center_id)
      const students = assignment.center_id
        ? db.prepare('SELECT * FROM students WHERE center_id = ? AND parent_phone IS NOT NULL').all(assignment.center_id)
        : db.prepare('SELECT * FROM students WHERE parent_phone IS NOT NULL').all();

      for (const student of students) {
        await sendHomeworkReminder(student, assignment);
      }
    }

    console.log(`Sent reminders for ${assignments.length} assignments`);
  } catch (error) {
    console.error('Homework reminder job error:', error);
  }
}, { timezone: 'Asia/Jakarta' });

// Weekly on Sunday at 10:00 WIB (03:00 UTC) — weekly progress reports
cron.schedule('0 3 * * 0', async () => {
  console.log('Running weekly progress report job...');
  try {
    const students = db.prepare('SELECT * FROM students WHERE parent_phone IS NOT NULL').all();

    for (const student of students) {
      await sendWeeklyReport(student);
    }

    console.log(`Sent weekly reports for ${students.length} students`);
  } catch (error) {
    console.error('Weekly report job error:', error);
  }
}, { timezone: 'Asia/Jakarta' });

// ---------------------------------------------------------------------------
// Daily usage limits (persistent, per student)
// ---------------------------------------------------------------------------
const DAILY_TEXT_LIMIT = 30;
const DAILY_IMAGE_LIMIT = 10;

function getTodayStr() {
  return new Date().toISOString().slice(0, 10); // YYYY-MM-DD
}

function getOrCreateUsage(studentId) {
  const today = getTodayStr();
  const key = String(studentId || 'anonymous');

  let row = db.prepare('SELECT * FROM usage WHERE student_id = ? AND date = ?').get(key, today);
  if (!row) {
    db.prepare('INSERT INTO usage (student_id, date, request_count, image_count) VALUES (?, ?, 0, 0)').run(key, today);
    row = db.prepare('SELECT * FROM usage WHERE student_id = ? AND date = ?').get(key, today);
  }
  return row;
}

function incrementUsage(studentId, hasImage) {
  const today = getTodayStr();
  const key = String(studentId || 'anonymous');

  if (hasImage) {
    db.prepare('UPDATE usage SET request_count = request_count + 1, image_count = image_count + 1 WHERE student_id = ? AND date = ?').run(key, today);
  } else {
    db.prepare('UPDATE usage SET request_count = request_count + 1 WHERE student_id = ? AND date = ?').run(key, today);
  }
}

// ---------------------------------------------------------------------------
// API: Chat
// ---------------------------------------------------------------------------
app.post('/api/chat', async (req, res) => {
  const { messages, student_id, max_tokens = 1500, temperature = 0.7 } = req.body;

  if (!checkRateLimit(student_id)) {
    return res.status(429).json({ error: 'Terlalu banyak permintaan. Tunggu sebentar ya!' });
  }

  // --- Content safety: filter student input ---
  const lastUserMsg = messages && messages.slice().reverse().find(m => m.role === 'user');
  if (lastUserMsg) {
    const textContent = typeof lastUserMsg.content === 'string'
      ? lastUserMsg.content
      : Array.isArray(lastUserMsg.content)
        ? lastUserMsg.content.filter(c => c.type === 'text').map(c => c.text).join(' ')
        : '';

    const inputCheck = filterInput(textContent);
    if (!inputCheck.safe) {
      return res.json({
        choices: [{
          message: {
            role: 'assistant',
            content: 'Hmm, ayo kita fokus belajar ya! \u{1F989} Ada soal yang bisa Kawi bantu?',
          },
        }],
        usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
        _filtered: true,
      });
    }
  }

  // --- Daily usage limits ---
  const hasImage = messages && messages.some(m =>
    Array.isArray(m.content) && m.content.some(c => c.type === 'image_url')
  );

  const usageRow = getOrCreateUsage(student_id);

  if (hasImage && usageRow.image_count >= DAILY_IMAGE_LIMIT) {
    return res.status(429).json({
      error: 'Kawi sudah capek hari ini! \u{1F634} Kamu bisa latihan pakai bank soal, atau coba lagi besok ya!',
      limit_type: 'image',
    });
  }

  if (usageRow.request_count >= DAILY_TEXT_LIMIT) {
    return res.status(429).json({
      error: 'Kawi sudah capek hari ini! \u{1F634} Kamu bisa latihan pakai bank soal, atau coba lagi besok ya!',
      limit_type: 'text',
    });
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

    // --- Content safety: filter AI output ---
    if (data.choices && data.choices[0] && data.choices[0].message) {
      const outputCheck = filterOutput(data.choices[0].message.content);
      if (!outputCheck.safe) {
        data.choices[0].message.content = outputCheck.cleaned;
      }
    }

    // Increment usage counter after successful response
    incrementUsage(student_id, hasImage);

    res.json(data);
  } catch (error) {
    console.error('Server error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// API: Usage stats
// ---------------------------------------------------------------------------
app.get('/api/usage/:student_id', (req, res) => {
  try {
    const { student_id } = req.params;
    const usage = getOrCreateUsage(student_id);

    res.json({
      student_id,
      date: usage.date,
      requests_used: usage.request_count,
      requests_limit: DAILY_TEXT_LIMIT,
      requests_remaining: Math.max(0, DAILY_TEXT_LIMIT - usage.request_count),
      images_used: usage.image_count,
      images_limit: DAILY_IMAGE_LIMIT,
      images_remaining: Math.max(0, DAILY_IMAGE_LIMIT - usage.image_count),
    });
  } catch (error) {
    console.error('Error getting usage:', error);
    res.status(500).json({ error: 'Failed to get usage' });
  }
});

app.get('/api/dashboard/usage', (req, res) => {
  try {
    const today = getTodayStr();

    // Today's totals
    const todayStats = db.prepare(`
      SELECT COALESCE(SUM(request_count), 0) as total_requests,
             COALESCE(SUM(image_count), 0) as total_images,
             COUNT(DISTINCT student_id) as active_students
      FROM usage WHERE date = ?
    `).get(today);

    // This week (last 7 days)
    const weekStart = new Date();
    weekStart.setDate(weekStart.getDate() - 6);
    const weekStartStr = weekStart.toISOString().slice(0, 10);

    const weekStats = db.prepare(`
      SELECT COALESCE(SUM(request_count), 0) as total_requests,
             COALESCE(SUM(image_count), 0) as total_images,
             COUNT(DISTINCT student_id) as active_students
      FROM usage WHERE date >= ?
    `).get(weekStartStr);

    // This month
    const monthStart = today.slice(0, 7) + '-01';

    const monthStats = db.prepare(`
      SELECT COALESCE(SUM(request_count), 0) as total_requests,
             COALESCE(SUM(image_count), 0) as total_images,
             COUNT(DISTINCT student_id) as active_students
      FROM usage WHERE date >= ?
    `).get(monthStart);

    // Estimated costs
    const textCost = 0.01;
    const imageCost = 0.03;

    res.json({
      today: {
        ...todayStats,
        estimated_cost: +(todayStats.total_requests * textCost + todayStats.total_images * imageCost).toFixed(2),
      },
      week: {
        ...weekStats,
        estimated_cost: +(weekStats.total_requests * textCost + weekStats.total_images * imageCost).toFixed(2),
      },
      month: {
        ...monthStats,
        estimated_cost: +(monthStats.total_requests * textCost + monthStats.total_images * imageCost).toFixed(2),
      },
    });
  } catch (error) {
    console.error('Error getting dashboard usage:', error);
    res.status(500).json({ error: 'Failed to get usage stats' });
  }
});

// ---------------------------------------------------------------------------
// API: Students
// ---------------------------------------------------------------------------
app.post('/api/students', (req, res) => {
  try {
    const { name, grade, phone, parent_phone, parent_name, center_id, pin } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'name is required' });
    }

    const studentPin = pin || generateUniquePin();

    const result = db.prepare(`
      INSERT INTO students (name, grade, phone, parent_phone, parent_name, center_id, pin)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(name, grade || null, phone || null, parent_phone || null, parent_name || null, center_id || null, studentPin);

    const student = db.prepare('SELECT * FROM students WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(student);
  } catch (error) {
    console.error('Error creating student:', error);
    res.status(500).json({ error: 'Failed to create student' });
  }
});

app.get('/api/students', (req, res) => {
  try {
    const { center_id } = req.query;

    const students = center_id
      ? db.prepare('SELECT * FROM students WHERE center_id = ? ORDER BY name').all(center_id)
      : db.prepare('SELECT * FROM students ORDER BY name').all();

    res.json(students);
  } catch (error) {
    console.error('Error listing students:', error);
    res.status(500).json({ error: 'Failed to list students' });
  }
});

app.get('/api/students/:id/progress', (req, res) => {
  try {
    const { id } = req.params;
    const { subject, limit } = req.query;

    let query = 'SELECT * FROM progress WHERE student_id = ?';
    const params = [id];

    if (subject) {
      query += ' AND subject = ?';
      params.push(subject);
    }

    query += ' ORDER BY created_at DESC';

    if (limit) {
      query += ' LIMIT ?';
      params.push(parseInt(limit, 10));
    }

    const progress = db.prepare(query).all(...params);
    res.json(progress);
  } catch (error) {
    console.error('Error getting progress:', error);
    res.status(500).json({ error: 'Failed to get progress' });
  }
});

// ---------------------------------------------------------------------------
// API: Authentication (PIN-based)
// ---------------------------------------------------------------------------
app.post('/api/auth/login', (req, res) => {
  try {
    const { pin } = req.body;

    if (!pin || pin.length !== 4) {
      return res.status(400).json({ error: 'PIN harus 4 digit' });
    }

    const student = db.prepare('SELECT * FROM students WHERE pin = ?').get(pin);
    if (!student) {
      return res.status(401).json({ error: 'PIN salah, coba lagi ya!' });
    }

    // Create a new session record
    const session = db.prepare(`
      INSERT INTO sessions (student_id, started_at, last_activity)
      VALUES (?, datetime('now'), datetime('now'))
    `).run(student.id);

    res.json({
      student,
      session_id: session.lastInsertRowid,
    });
  } catch (error) {
    console.error('Error during login:', error);
    res.status(500).json({ error: 'Login gagal' });
  }
});

app.post('/api/auth/logout', (req, res) => {
  try {
    const { session_id } = req.body;

    if (!session_id) {
      return res.status(400).json({ error: 'session_id is required' });
    }

    db.prepare(`
      UPDATE sessions SET ended_at = datetime('now') WHERE id = ? AND ended_at IS NULL
    `).run(session_id);

    res.json({ success: true });
  } catch (error) {
    console.error('Error during logout:', error);
    res.status(500).json({ error: 'Logout gagal' });
  }
});

app.get('/api/auth/verify/:pin', (req, res) => {
  try {
    const { pin } = req.params;

    const student = db.prepare('SELECT id, name, grade, stars, level, pin FROM students WHERE pin = ?').get(pin);
    if (!student) {
      return res.status(404).json({ error: 'PIN tidak ditemukan' });
    }

    res.json({ name: student.name, grade: student.grade });
  } catch (error) {
    console.error('Error verifying PIN:', error);
    res.status(500).json({ error: 'Verifikasi gagal' });
  }
});

// Onboard parent — save parent info and send welcome WhatsApp
app.post('/api/students/:id/onboard-parent', async (req, res) => {
  try {
    const { id } = req.params;
    const { parent_phone, parent_name } = req.body;

    if (!parent_phone || !parent_name) {
      return res.status(400).json({ error: 'parent_phone dan parent_name wajib diisi' });
    }

    const student = db.prepare('SELECT * FROM students WHERE id = ?').get(id);
    if (!student) {
      return res.status(404).json({ error: 'Siswa tidak ditemukan' });
    }

    // Update student record
    db.prepare('UPDATE students SET parent_phone = ?, parent_name = ? WHERE id = ?')
      .run(parent_phone, parent_name, id);

    // Send welcome WhatsApp message
    const message =
      `Halo ${parent_name}! Selamat datang di *Kawabel* (Kawan Belajar).\n\n` +
      `Anak Anda, *${student.name}*, telah terdaftar di Kawabel dengan PIN: *${student.pin}*.\n\n` +
      `Kawabel adalah teman belajar pintar yang membantu anak belajar Matematika, Bahasa Indonesia, dan IPA secara interaktif.\n\n` +
      `Anda akan menerima notifikasi:\n` +
      `- Pengingat tugas/PR\n` +
      `- Laporan belajar mingguan\n\n` +
      `Terima kasih sudah mendukung proses belajar ${student.name}! \u{1F989}`;

    const waResult = await sendWhatsApp(parent_phone, message);

    // Log the notification
    db.prepare(`
      INSERT INTO notifications (student_id, phone, message, sent_at, status)
      VALUES (?, ?, ?, datetime('now'), ?)
    `).run(student.id, parent_phone, message, waResult.success ? 'sent' : 'failed');

    const updated = db.prepare('SELECT * FROM students WHERE id = ?').get(id);
    res.json({ success: true, student: updated, whatsapp: waResult });
  } catch (error) {
    console.error('Error onboarding parent:', error);
    res.status(500).json({ error: 'Gagal menghubungkan orang tua' });
  }
});

// Reset PIN for a student
app.post('/api/students/:id/reset-pin', (req, res) => {
  try {
    const { id } = req.params;

    const student = db.prepare('SELECT * FROM students WHERE id = ?').get(id);
    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    const newPin = generateUniquePin();
    db.prepare('UPDATE students SET pin = ? WHERE id = ?').run(newPin, id);

    res.json({ id: Number(id), pin: newPin });
  } catch (error) {
    console.error('Error resetting PIN:', error);
    res.status(500).json({ error: 'Failed to reset PIN' });
  }
});

// ---------------------------------------------------------------------------
// API: Progress
// ---------------------------------------------------------------------------
app.post('/api/progress', (req, res) => {
  try {
    const { student_id, subject, topic, score, total, type } = req.body;

    if (!student_id || score == null || total == null) {
      return res.status(400).json({ error: 'student_id, score, and total are required' });
    }

    const validTypes = ['homework', 'test', 'dictation'];
    if (type && !validTypes.includes(type)) {
      return res.status(400).json({ error: `type must be one of: ${validTypes.join(', ')}` });
    }

    const result = db.prepare(`
      INSERT INTO progress (student_id, subject, topic, score, total, type)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(student_id, subject || null, topic || null, score, total, type || null);

    // Award stars based on score percentage
    const pct = total > 0 ? score / total : 0;
    if (pct >= 0.8) {
      db.prepare('UPDATE students SET stars = stars + 1 WHERE id = ?').run(student_id);
    }

    const entry = db.prepare('SELECT * FROM progress WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(entry);
  } catch (error) {
    console.error('Error saving progress:', error);
    res.status(500).json({ error: 'Failed to save progress' });
  }
});

// ---------------------------------------------------------------------------
// API: Assignments
// ---------------------------------------------------------------------------
app.post('/api/assignments', (req, res) => {
  try {
    const { center_id, title, subject, topic, type, grade, description, due_date, created_by } = req.body;

    if (!title) {
      return res.status(400).json({ error: 'title is required' });
    }

    const validTypes = ['homework', 'test', 'dictation'];
    if (type && !validTypes.includes(type)) {
      return res.status(400).json({ error: `type must be one of: ${validTypes.join(', ')}` });
    }

    const result = db.prepare(`
      INSERT INTO assignments (center_id, title, subject, topic, type, grade, description, due_date, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(center_id || null, title, subject || null, topic || null, type || null, grade || null, description || null, due_date || null, created_by || null);

    const assignment = db.prepare('SELECT * FROM assignments WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(assignment);
  } catch (error) {
    console.error('Error creating assignment:', error);
    res.status(500).json({ error: 'Failed to create assignment' });
  }
});

app.get('/api/assignments', (req, res) => {
  try {
    const { center_id, type } = req.query;

    let query = 'SELECT * FROM assignments WHERE 1=1';
    const params = [];

    if (center_id) {
      query += ' AND center_id = ?';
      params.push(center_id);
    }
    if (type) {
      query += ' AND type = ?';
      params.push(type);
    }

    query += ' ORDER BY due_date ASC';

    const assignments = db.prepare(query).all(...params);
    res.json(assignments);
  } catch (error) {
    console.error('Error listing assignments:', error);
    res.status(500).json({ error: 'Failed to list assignments' });
  }
});

// ---------------------------------------------------------------------------
// API: Notifications
// ---------------------------------------------------------------------------
app.post('/api/notifications/send', async (req, res) => {
  try {
    const { phone, message, student_id, assignment_id } = req.body;

    if (!phone || !message) {
      return res.status(400).json({ error: 'phone and message are required' });
    }

    const result = await sendWhatsApp(phone, message);

    db.prepare(`
      INSERT INTO notifications (student_id, assignment_id, phone, message, sent_at, status)
      VALUES (?, ?, ?, ?, datetime('now'), ?)
    `).run(
      student_id || null,
      assignment_id || null,
      phone,
      message,
      result.success ? 'sent' : 'failed'
    );

    res.json(result);
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ error: 'Failed to send notification' });
  }
});

app.post('/api/notifications/homework-reminder', async (req, res) => {
  try {
    const { assignment_id } = req.body;

    if (!assignment_id) {
      return res.status(400).json({ error: 'assignment_id is required' });
    }

    const assignment = db.prepare('SELECT * FROM assignments WHERE id = ?').get(assignment_id);
    if (!assignment) {
      return res.status(404).json({ error: 'Assignment not found' });
    }

    const students = assignment.center_id
      ? db.prepare('SELECT * FROM students WHERE center_id = ? AND parent_phone IS NOT NULL').all(assignment.center_id)
      : db.prepare('SELECT * FROM students WHERE parent_phone IS NOT NULL').all();

    const results = [];
    for (const student of students) {
      const r = await sendHomeworkReminder(student, assignment);
      results.push({ student_id: student.id, name: student.name, ...r });
    }

    res.json({ sent: results.length, results });
  } catch (error) {
    console.error('Error sending homework reminders:', error);
    res.status(500).json({ error: 'Failed to send reminders' });
  }
});

// ---------------------------------------------------------------------------
// API: Dashboard stats
// ---------------------------------------------------------------------------
app.get('/api/dashboard/stats', (req, res) => {
  try {
    const totalStudents = db.prepare('SELECT COUNT(*) as count FROM students').get().count;

    const sessionsToday = db.prepare(`
      SELECT COUNT(*) as count FROM sessions
      WHERE date(started_at) = date('now')
    `).get().count;

    const avgScores = db.prepare(`
      SELECT AVG(CAST(score AS REAL) / total * 100) as avg_pct
      FROM progress
      WHERE total > 0
    `).get().avg_pct;

    const activeAssignments = db.prepare(`
      SELECT COUNT(*) as count FROM assignments
      WHERE due_date >= date('now')
    `).get().count;

    const totalCenters = db.prepare('SELECT COUNT(*) as count FROM centers').get().count;

    const recentProgress = db.prepare(`
      SELECT p.*, s.name as student_name
      FROM progress p
      JOIN students s ON s.id = p.student_id
      ORDER BY p.created_at DESC
      LIMIT 10
    `).all();

    res.json({
      total_students: totalStudents,
      sessions_today: sessionsToday,
      avg_score_pct: avgScores ? Math.round(avgScores * 10) / 10 : null,
      active_assignments: activeAssignments,
      total_centers: totalCenters,
      recent_progress: recentProgress,
    });
  } catch (error) {
    console.error('Error getting dashboard stats:', error);
    res.status(500).json({ error: 'Failed to get stats' });
  }
});

// ---------------------------------------------------------------------------
// API: Parent report
// ---------------------------------------------------------------------------
app.get('/api/reports/:student_id', (req, res) => {
  try {
    const { student_id } = req.params;

    const student = db.prepare('SELECT * FROM students WHERE id = ?').get(student_id);
    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    // All-time progress grouped by subject
    const subjectSummary = db.prepare(`
      SELECT subject,
             COUNT(*) as attempts,
             AVG(CAST(score AS REAL) / total * 100) as avg_pct,
             MAX(CAST(score AS REAL) / total * 100) as best_pct
      FROM progress
      WHERE student_id = ? AND total > 0
      GROUP BY subject
      ORDER BY subject
    `).all(student_id);

    // Recent progress (last 30 entries)
    const recentProgress = db.prepare(`
      SELECT * FROM progress
      WHERE student_id = ?
      ORDER BY created_at DESC
      LIMIT 30
    `).all(student_id);

    // Session count
    const sessionCount = db.prepare(`
      SELECT COUNT(*) as count FROM sessions WHERE student_id = ?
    `).get(student_id).count;

    // Sessions this week
    const sessionsThisWeek = db.prepare(`
      SELECT COUNT(*) as count FROM sessions
      WHERE student_id = ? AND started_at >= datetime('now', '-7 days')
    `).get(student_id).count;

    res.json({
      student: {
        id: student.id,
        name: student.name,
        grade: student.grade,
        stars: student.stars,
        level: student.level,
      },
      total_sessions: sessionCount,
      sessions_this_week: sessionsThisWeek,
      subject_summary: subjectSummary,
      recent_progress: recentProgress,
    });
  } catch (error) {
    console.error('Error generating report:', error);
    res.status(500).json({ error: 'Failed to generate report' });
  }
});

// ---------------------------------------------------------------------------
// API: Question bank (combined)
// ---------------------------------------------------------------------------
app.get('/api/questions', (req, res) => {
  try {
    const fs = require('fs');
    const questionsDir = path.join(__dirname, 'data', 'questions');
    const indexPath = path.join(questionsDir, 'index.json');

    if (!fs.existsSync(indexPath)) {
      return res.status(404).json({ error: 'Question bank index not found' });
    }

    const index = JSON.parse(fs.readFileSync(indexPath, 'utf8'));
    const result = { subjects: [] };

    for (const subject of index.subjects) {
      const filePath = path.join(questionsDir, subject.file);
      if (fs.existsSync(filePath)) {
        const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        result.subjects.push({
          id: subject.id,
          name: subject.name,
          icon: subject.icon,
          grades: data.grades || {},
        });
      }
    }

    result.metadata = index.metadata || {};
    result.cached_at = new Date().toISOString();

    res.json(result);
  } catch (error) {
    console.error('Error loading question bank:', error);
    res.status(500).json({ error: 'Failed to load question bank' });
  }
});

// ---------------------------------------------------------------------------
// API: Leaderboard (for center TV display)
// ---------------------------------------------------------------------------
app.get('/api/leaderboard', (req, res) => {
  try {
    const { center_id, period = 'week' } = req.query;

    const dateFilter = period === 'month'
      ? "datetime('now', '-30 days')"
      : period === 'all'
        ? "datetime('2020-01-01')"
        : "datetime('now', '-7 days')";

    const centerClause = center_id ? 'AND s.center_id = ?' : '';
    const params = center_id ? [center_id] : [];

    const leaderboard = db.prepare(`
      SELECT s.id, s.name, s.grade, s.stars, s.level,
             COUNT(DISTINCT p.id) as activities,
             COALESCE(AVG(CASE WHEN p.total > 0 THEN CAST(p.score AS REAL) / p.total * 100 END), 0) as avg_score,
             COUNT(DISTINCT date(p.created_at)) as active_days
      FROM students s
      LEFT JOIN progress p ON p.student_id = s.id AND p.created_at >= ${dateFilter}
      WHERE 1=1 ${centerClause}
      GROUP BY s.id
      ORDER BY s.stars DESC, activities DESC
      LIMIT 20
    `).all(...params);

    const ranked = leaderboard.map((row, i) => ({
      rank: i + 1,
      ...row,
      avg_score: Math.round(row.avg_score * 10) / 10,
      badge: row.stars >= 200 ? 'diamond' : row.stars >= 100 ? 'gold' : row.stars >= 50 ? 'silver' : row.stars >= 20 ? 'bronze' : null,
    }));

    res.json({ period, leaderboard: ranked });
  } catch (error) {
    console.error('Error getting leaderboard:', error);
    res.status(500).json({ error: 'Failed to get leaderboard' });
  }
});

// ---------------------------------------------------------------------------
// API: Monthly report (JSON data for PDF generation client-side or admin view)
// ---------------------------------------------------------------------------
app.get('/api/reports/:student_id/monthly', (req, res) => {
  try {
    const { student_id } = req.params;
    const { month, year } = req.query;

    const m = month || new Date().getMonth() + 1;
    const y = year || new Date().getFullYear();
    const startDate = `${y}-${String(m).padStart(2, '0')}-01`;
    const endDate = `${y}-${String(Number(m) + 1).padStart(2, '0')}-01`;

    const student = db.prepare('SELECT * FROM students WHERE id = ?').get(student_id);
    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    // Subject performance this month
    const subjects = db.prepare(`
      SELECT subject,
             COUNT(*) as attempts,
             AVG(CAST(score AS REAL) / total * 100) as avg_pct,
             MAX(CAST(score AS REAL) / total * 100) as best_pct,
             MIN(CAST(score AS REAL) / total * 100) as worst_pct,
             SUM(score) as total_correct,
             SUM(total) as total_questions
      FROM progress
      WHERE student_id = ? AND total > 0
        AND created_at >= ? AND created_at < ?
      GROUP BY subject
      ORDER BY avg_pct DESC
    `).all(student_id, startDate, endDate);

    // Daily activity count
    const dailyActivity = db.prepare(`
      SELECT date(created_at) as date, COUNT(*) as count
      FROM progress
      WHERE student_id = ?
        AND created_at >= ? AND created_at < ?
      GROUP BY date(created_at)
      ORDER BY date
    `).all(student_id, startDate, endDate);

    // Session count this month
    const sessions = db.prepare(`
      SELECT COUNT(*) as count,
             SUM(CASE WHEN ended_at IS NOT NULL
                 THEN (julianday(ended_at) - julianday(started_at)) * 24 * 60
                 ELSE 0 END) as total_minutes
      FROM sessions
      WHERE student_id = ?
        AND started_at >= ? AND started_at < ?
    `).get(student_id, startDate, endDate);

    // Strengths and weaknesses
    const strongest = subjects.length > 0 ? subjects[0].subject : null;
    const weakest = subjects.length > 1 ? subjects[subjects.length - 1].subject : null;

    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];

    res.json({
      student: {
        name: student.name,
        grade: student.grade,
        stars: student.stars,
        level: student.level,
      },
      period: `${monthNames[Number(m) - 1]} ${y}`,
      summary: {
        total_sessions: sessions.count,
        total_minutes: Math.round(sessions.total_minutes || 0),
        active_days: dailyActivity.length,
        total_attempts: subjects.reduce((sum, s) => sum + s.attempts, 0),
        overall_avg: subjects.length > 0
          ? Math.round(subjects.reduce((sum, s) => sum + s.avg_pct, 0) / subjects.length * 10) / 10
          : 0,
      },
      subjects: subjects.map(s => ({
        ...s,
        avg_pct: Math.round(s.avg_pct * 10) / 10,
        best_pct: Math.round(s.best_pct * 10) / 10,
      })),
      daily_activity: dailyActivity,
      insights: {
        strongest_subject: strongest,
        weakest_subject: weakest,
      },
      generated_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error generating monthly report:', error);
    res.status(500).json({ error: 'Failed to generate report' });
  }
});

// ---------------------------------------------------------------------------
// Health check
// ---------------------------------------------------------------------------
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Kawabel API',
    database: 'connected',
    fonnte: FONNTE_TOKEN ? 'configured' : 'not configured',
  });
});

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`\u{1F989} Kawabel API running on port ${PORT}`);
  console.log(`   Database: ${DB_PATH}`);
  console.log(`   Fonnte:   ${FONNTE_TOKEN ? 'configured' : 'NOT configured'}`);
  console.log(`   Cron:     homework reminders daily 16:00 WIB, weekly reports Sunday 10:00 WIB`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  db.close();
  process.exit(0);
});
process.on('SIGTERM', () => {
  db.close();
  process.exit(0);
});
