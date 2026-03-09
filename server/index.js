// Kawabel — API Proxy Server
// Keeps the OpenAI API key on the server, never exposed to students
//
// Deploy options:
//   - Vercel: vercel deploy (uses api/ folder)
//   - Railway/Render: node server/index.js
//   - Local: node server/index.js

const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');
const cron = require('node-cron');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Serve admin dashboard static files
app.use('/admin', express.static(path.join(__dirname, 'public', 'admin')));

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
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL REFERENCES students(id),
      subject TEXT,
      topic TEXT,
      started_at TEXT DEFAULT (datetime('now')),
      ended_at TEXT,
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
  `);

  console.log('Database initialized at', DB_PATH);
}

initDatabase();

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
// API: Chat (existing)
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// API: Students
// ---------------------------------------------------------------------------
app.post('/api/students', (req, res) => {
  try {
    const { name, grade, phone, parent_phone, parent_name, center_id } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'name is required' });
    }

    const result = db.prepare(`
      INSERT INTO students (name, grade, phone, parent_phone, parent_name, center_id)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(name, grade || null, phone || null, parent_phone || null, parent_name || null, center_id || null);

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
