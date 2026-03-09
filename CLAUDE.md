# CLAUDE.md

## Project Overview

Kawabel (Kawan Belajar) is an AI-powered tutoring tablet app for Indonesian students (SD & SMP). Students photograph homework/textbooks and get guided help from "Kawi" — an AI owl tutor. Features Chinese dictation with TTS + handwriting recognition, test prep with mock tests, and gamified learning across all school subjects. Deployed on iPads at tuition centers with home continuity.

## Tech Stack

- **App**: Flutter (Dart) — cross-platform iPad + Android tablets + web
- **Backend**: Express.js + SQLite (better-sqlite3)
- **AI**: OpenAI GPT-4o API — reasoning + vision for photo understanding
- **WhatsApp**: Fonnte API — notifications to parents (homework reminders, weekly reports)
- **Admin**: Static HTML dashboard with Tailwind CSS + Chart.js

## Brand

- **Name**: Kawabel (lowercase in logo), full name "kawan belajar"
- **Logo font**: Nunito (weight 900, extra bold)
- **Body font**: Poppins
- **Primary color**: #4CAF50 (green)
- **Mascot**: Kawi the Owl 🦉

## Project Structure

- `lib/features/` — Feature modules (auth, home, camera, chat, dictation, test_prep, progress)
- `lib/core/` — Shared services (ai, api, models)
- `server/` — Express.js API server with SQLite
- `server/public/admin/` — Teacher admin dashboard (HTML)
- `server/data/questions/` — Curriculum-aligned question banks

## Key Conventions

- Feature-first folder structure
- Kawi (the owl) is the AI persona — always guides, never gives direct answers
- All AI prompts must be age-appropriate and filtered
- "Kawabel" branding everywhere, lowercase in logo
- Indonesian (Bahasa) is the primary UI language
- Students can start at tuition center, continue at home (progress syncs via API)
