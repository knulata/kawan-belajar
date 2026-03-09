# Kawan Belajar

**Your AI Study Buddy** — An iPad/tablet app that uses AI to help Indonesian students with homework and test preparation across all school subjects.

<p align="center">
  <img src="docs/assets/kawi-hero.png" alt="Kawi the Owl" width="200">
  <br>
  <em>Meet Kawi — your friendly AI tutor owl</em>
</p>

---

## What is Kawan Belajar?

Kawan Belajar ("Learning Buddy") is a revolutionary AI-powered tutoring app designed for tuition centers and home use. Students snap a photo of their worksheet or textbook, and **Kawi the Owl** — their AI teacher companion — guides them through understanding and solving problems step by step.

### Key Features

- **Snap & Learn** — Take a photo of any worksheet, textbook page, or homework. AI reads and understands the content instantly.
- **Guided Problem Solving** — Kawi doesn't give answers. He asks guiding questions, gives hints, and helps students think through problems themselves.
- **Chinese Dictation Mode (听写)** — Kawi reads out Chinese words/sentences aloud while the student writes. Handwriting is recognized and graded in real-time.
- **Test Prep Mode** — Upload a test topic or syllabus photo. Kawi generates practice questions, mock tests, and tracks weak areas.
- **All Subjects Covered** — Math, Bahasa Indonesia, Chinese (Mandarin), Science (IPA), Social Studies (IPS), English, PKN, and more.
- **Tuition Center + Home** — Start at the center, continue at home. Progress syncs seamlessly.
- **Gamified Learning** — Earn stars, unlock badges, level up with Kawi. Weekly streaks and leaderboards at the tuition center.

---

## Target Users

| Segment | Details |
|---------|---------|
| **Primary** | SD students (grades 1-6, ages 6-12) |
| **Secondary** | SMP students (grades 7-9, ages 12-15) |
| **Setting** | Tuition centers (bimbel) with shared iPads/tablets + home use on personal devices |

---

## Meet Kawi 🦉

Kawi is a wise, friendly owl who serves as the student's AI tutor. He adapts his personality based on the student's age:

- **For younger students (SD 1-3):** Playful, uses simple language, lots of encouragement, animated reactions
- **For older students (SD 4-6):** Supportive coach, explains concepts clearly, celebrates effort
- **For SMP students:** More mature mentor, deeper explanations, encourages independent thinking

Kawi speaks Bahasa Indonesia by default, switches to Chinese for Chinese class, and uses English for English class.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  FLUTTER APP                     │
│  ┌───────────┐ ┌───────────┐ ┌───────────────┐  │
│  │  Camera /  │ │   Kawi    │ │  Handwriting  │  │
│  │  Scanner   │ │  Chat UI  │ │  Canvas       │  │
│  └─────┬─────┘ └─────┬─────┘ └──────┬────────┘  │
│        │              │              │            │
│  ┌─────┴──────────────┴──────────────┴────────┐  │
│  │           Local State & Offline Cache       │  │
│  └─────────────────────┬──────────────────────┘  │
└────────────────────────┼─────────────────────────┘
                         │ API
┌────────────────────────┼─────────────────────────┐
│              BACKEND (Supabase + Edge)            │
│  ┌─────────┐ ┌────────┴───────┐ ┌─────────────┐ │
│  │ Auth &   │ │  AI Service    │ │  Progress   │ │
│  │ Profiles │ │  (Claude API)  │ │  Tracking   │ │
│  └─────────┘ └────────────────┘ └─────────────┘ │
│  ┌──────────┐ ┌───────────────┐ ┌─────────────┐ │
│  │ Center   │ │  Question     │ │  TTS / STT  │ │
│  │ Mgmt     │ │  Bank         │ │  Service    │ │
│  └──────────┘ └───────────────┘ └─────────────┘ │
└──────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| **App** | Flutter (Dart) | Cross-platform iPad + Android tablets, single codebase, excellent tablet UI support |
| **AI Brain** | Claude API (Anthropic) | Best-in-class reasoning for math, language, and multi-subject tutoring |
| **Vision** | Claude Vision API | Photo → text extraction, diagram understanding, handwriting recognition |
| **Speech** | Google Cloud TTS/STT | Chinese dictation (text-to-speech for reading out words), speech recognition for pronunciation practice |
| **Backend** | Supabase | Auth, PostgreSQL database, real-time sync, edge functions, file storage |
| **Handwriting** | Google ML Kit / Apple Pencil API | Real-time Chinese character recognition on the canvas |
| **Analytics** | PostHog | Learning analytics, engagement tracking, A/B testing |

---

## Core User Flows

### Flow 1: Snap & Learn (Homework Help)

```
Student stuck on homework
        │
        ▼
  📸 Takes photo of the problem
        │
        ▼
  🔍 AI extracts text/math from image
        │
        ▼
  🦉 Kawi identifies the subject & topic
        │
        ▼
  💬 Kawi asks: "What have you tried so far?"
        │
        ▼
  🧠 Guided conversation:
     - Gives hints, not answers
     - Breaks down into smaller steps
     - Uses visual aids & examples
     - Checks understanding along the way
        │
        ▼
  ⭐ Student solves it → earns stars!
        │
        ▼
  📝 Weak area logged for test prep
```

### Flow 2: Chinese Dictation (听写 Tīngxiě)

```
Student selects "Latihan Dikte" (Dictation Practice)
        │
        ▼
  📚 Picks lesson/chapter from textbook
     (or teacher assigns word list)
        │
        ▼
  🦉 Kawi says: "Ready? Let's begin!"
        │
        ▼
  🔊 Kawi reads a word/phrase aloud (TTS)
     e.g. "请写：学校" (Please write: school)
        │
        ▼
  ✍️  Student writes on canvas with finger/stylus
        │
        ▼
  🔍 Handwriting recognized in real-time
     - Stroke order feedback
     - Character accuracy scoring
        │
        ▼
  ✅ Correct → "太棒了!" + star
  ❌ Wrong → Kawi shows correct strokes,
     adds to review list
        │
        ▼
  📊 Results summary with score
```

### Flow 3: Test Prep Mode

```
Upcoming test announced
        │
        ▼
  📸 Student photos the syllabus/topic list
     OR selects subject + chapter
        │
        ▼
  🦉 Kawi generates a study plan:
     "Your test is in 5 days. Here's our plan!"
        │
        ▼
  📋 Day-by-day breakdown:
     Day 1: Review key concepts (flashcards)
     Day 2: Practice problems (easy → hard)
     Day 3: Weak areas deep dive
     Day 4: Mock test
     Day 5: Quick review + confidence boost
        │
        ▼
  🧪 Mock test with timer
     - Auto-generated from topic
     - Difficulty matches real test
        │
        ▼
  📊 Results + weak area analysis
     "Focus on fractions — let's practice more!"
```

---

## App Screens

### 1. Home Screen
- Kawi greeting (time-aware: "Selamat pagi!" / "Selamat sore!")
- Today's learning streak & stars
- Quick actions: Snap Homework, Test Prep, Dictation
- Recent activity feed
- Subject tiles with progress rings

### 2. Camera/Scanner Screen
- Full-screen camera with guide overlay
- "Point at your homework" instruction
- Auto-crop & enhance
- Gallery picker option

### 3. Chat with Kawi
- Chat-style interface with Kawi's avatar
- Rich messages: text, math (LaTeX), images, diagrams
- Interactive elements: multiple choice, drag & drop
- Voice input option
- "Show me the steps" button

### 4. Chinese Dictation Screen
- Large writing canvas (full tablet width)
- Audio playback controls (repeat, slower)
- Stroke order animation guide
- Progress bar (word 3 of 10)
- Score display

### 5. Test Prep Dashboard
- Calendar with test dates
- Subject-wise readiness meter
- Practice history
- "Start Mock Test" button
- Study plan timeline

### 6. Progress & Rewards
- Star collection & level display
- Badge gallery (unlockable achievements)
- Subject mastery chart
- Weekly streak calendar
- Tuition center leaderboard (opt-in)

### 7. Tuition Center Admin Panel (Web)
- Student roster & progress overview
- Assign homework/dictation lists
- Set test dates & syllabi
- View engagement analytics
- Manage tablet devices

---

## Gamification System

### Stars ⭐
- Earn 1 star per problem solved with hints
- Earn 3 stars per problem solved independently
- Earn 5 stars for perfect dictation scores
- Earn 10 stars for mock test improvements

### Levels
- Level 1-10: Kawi Egg → Baby Owl → ... → Wise Owl
- Each level unlocks new Kawi outfits/accessories
- Visual evolution of the character

### Badges
- "Math Wizard" — Solve 50 math problems
- "词语大师" — Perfect score on 10 dictations
- "Science Explorer" — Complete all science chapters
- "Streak Master" — 7-day learning streak
- "Night Owl" — Study 3 evenings in a row

### Tuition Center Leaderboard
- Weekly top learners board displayed in center
- Team challenges between centers
- Monthly prizes for top performers

---

## Subject Coverage

### Mathematics (Matematika)
- Arithmetic, fractions, decimals, percentages
- Geometry with visual aids
- Word problems (bilingual: ID/EN)
- Step-by-step equation solving
- Graph & chart interpretation

### Bahasa Indonesia
- Reading comprehension with guided questions
- Grammar (SPOK structure)
- Essay writing assistance
- Vocabulary building
- Pantun & puisi analysis

### Chinese (Bahasa Mandarin)
- 听写 Dictation with TTS
- Character writing with stroke order
- Pinyin practice
- Reading comprehension
- Vocabulary by HSK/school level
- Conversation practice (basic)

### Science (IPA)
- Concept explanations with visuals
- Experiment walkthroughs
- Diagram labeling exercises
- Formula practice
- Real-world connections

### Social Studies (IPS)
- Map-based learning
- Timeline activities
- Key concept summaries
- Current events connections

### English
- Reading comprehension
- Grammar exercises
- Vocabulary building
- Simple writing prompts
- Pronunciation (with speech recognition)

### PKN (Civic Education)
- Pancasila values
- Government structure
- Rights & responsibilities
- Case study discussions

---

## Data Model

```sql
-- Core entities
students (id, name, grade, school, avatar, level, stars, center_id)
centers (id, name, address, admin_id, tablet_count)
sessions (id, student_id, device_id, start_time, end_time, location)

-- Learning
conversations (id, student_id, subject, topic, started_at)
messages (id, conversation_id, role, content, media_url)
photos (id, student_id, image_url, extracted_text, subject)

-- Chinese Dictation
dictation_sets (id, title, grade, lesson, created_by)
dictation_words (id, set_id, word, pinyin, meaning_id)
dictation_attempts (id, student_id, set_id, word_id, written_image, recognized, correct, stroke_score)

-- Test Prep
tests (id, student_id, subject, topic, test_date, study_plan)
practice_questions (id, test_id, question, answer, difficulty)
practice_attempts (id, question_id, student_id, response, correct, time_spent)

-- Progress & Gamification
progress (id, student_id, subject, topic, mastery_level, weak_areas)
achievements (id, student_id, badge_type, earned_at)
streaks (id, student_id, current_streak, longest_streak, last_active)
```

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-6)
- [ ] Flutter project setup with tablet-optimized layouts
- [ ] Supabase backend: auth, database, storage
- [ ] Kawi character design & basic animations
- [ ] Camera/photo capture & Claude Vision integration
- [ ] Basic chat UI with Claude API
- [ ] Student profile & login (PIN-based for young kids)

### Phase 2: Core Subjects (Weeks 7-12)
- [ ] Math problem solving with step-by-step guidance
- [ ] Bahasa Indonesia reading comprehension
- [ ] Chinese dictation with TTS & handwriting canvas
- [ ] Science concept explanations
- [ ] Subject detection from photos
- [ ] Basic progress tracking

### Phase 3: Test Prep & Gamification (Weeks 13-18)
- [ ] Test prep mode: study plans & mock tests
- [ ] Question generation from topics/syllabus photos
- [ ] Star & level system
- [ ] Badge achievements
- [ ] Streak tracking
- [ ] Offline support for core features

### Phase 4: Center Management (Weeks 19-22)
- [ ] Admin web dashboard
- [ ] Device management (shared tablet mode)
- [ ] Teacher assignment features
- [ ] Analytics dashboard
- [ ] Center leaderboard
- [ ] Parent progress reports (WhatsApp integration)

### Phase 5: Polish & Launch (Weeks 23-26)
- [ ] Performance optimization
- [ ] Accessibility features
- [ ] Content moderation & safety filters
- [ ] Beta testing at 2-3 tuition centers
- [ ] App Store & Play Store submission
- [ ] Marketing materials

---

## Safety & Content Guidelines

- **No direct answers** — Kawi always guides, never just gives the answer
- **Age-appropriate content** — Language and complexity adapts to grade level
- **Content filtering** — AI responses are filtered for appropriateness
- **Session limits** — Configurable time limits per session (center policy)
- **Privacy** — No personal data shared between students; COPPA-like compliance
- **Offline safety** — Core features work without internet; no external links

---

## Business Model

| Revenue Stream | Details |
|---------------|---------|
| **Center License** | Monthly per-center fee (includes X tablets) |
| **Home Subscription** | Monthly per-student for home use |
| **Freemium** | 3 free questions/day, unlimited with subscription |
| **Content Packs** | Premium test prep packs for specific exams |

---

## Getting Started (Development)

```bash
# Prerequisites
# - Flutter SDK 3.x
# - Dart SDK
# - Supabase CLI
# - Android Studio / Xcode

# Clone and setup
git clone https://github.com/your-username/kawan-belajar.git
cd kawan-belajar

# Install dependencies
flutter pub get

# Run on tablet/emulator
flutter run

# Run tests
flutter test
```

---

## Project Structure

```
kawan-belajar/
├── lib/
│   ├── main.dart                  # App entry point
│   ├── app/
│   │   ├── app.dart               # App widget & theme
│   │   ├── router.dart            # Navigation/routing
│   │   └── theme.dart             # Design system & colors
│   ├── features/
│   │   ├── auth/                  # Login, PIN, profiles
│   │   ├── home/                  # Home screen & dashboard
│   │   ├── camera/                # Photo capture & scanning
│   │   ├── chat/                  # Chat with Kawi
│   │   ├── dictation/             # Chinese dictation mode
│   │   ├── test_prep/             # Test preparation
│   │   ├── progress/              # Progress & achievements
│   │   └── settings/              # App settings
│   ├── core/
│   │   ├── ai/                    # Claude API integration
│   │   ├── speech/                # TTS & STT services
│   │   ├── handwriting/           # Handwriting recognition
│   │   ├── storage/               # Local & remote storage
│   │   └── models/                # Shared data models
│   └── shared/
│       ├── widgets/               # Reusable UI components
│       ├── kawi/                  # Kawi character & animations
│       └── utils/                 # Helpers & extensions
├── assets/
│   ├── images/                    # Kawi sprites, icons
│   ├── animations/                # Lottie/Rive animations
│   └── sounds/                    # Sound effects, Kawi voice
├── admin-dashboard/               # Web admin panel (Next.js)
├── supabase/
│   ├── migrations/                # Database migrations
│   └── functions/                 # Edge functions
├── test/                          # Flutter tests
├── docs/                          # Documentation & assets
├── pubspec.yaml                   # Flutter dependencies
└── README.md
```

---

## License

MIT

---

<p align="center">
  Built with 🦉 by the Kawan Belajar team
</p>
