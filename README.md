# NeverGone Take‑Home Assignment

A complete demo of NeverGone featuring a SwiftUI iOS app, Supabase backend with Edge Functions and Postgres, real-time streaming via SSE, email/password authentication, and long-term memory capture.

## Demo

[![Watch Demo](https://img.youtube.com/vi/qV8aeACZUmI/maxresdefault.jpg)](https://www.youtube.com/watch?v=qV8aeACZUmI)

---

## Repository Structure

```
nevergone-takehome/
├── ios/
│   ├── NeverGoneDemo/
│   │   └── NeverGoneDemo/
│   │       ├── App/                  # App entry point
│   │       ├── Models/               # Data structures
│   │       ├── ViewModels/           # Business logic
│   │       ├── Views/                # UI screens
│   │       └── Services/             # Supabase client
│   ├── NeverGoneDemoTests/           # XCTests
│   └── README.md
├── backend/
│   ├── supabase/
│   │   ├── functions/
│   │   │   ├── chat_stream/          # Streaming chat endpoint
│   │   │   └── summarize_memory/     # Memory summarization
│   │   ├── migrations/               # Database schema + prompt versioning
│   │   └── config.toml               # Supabase config
│   ├── admin.html                    # Admin dashboard UI
│   └── README.md
└── README.md
```

---

## Running Locally

### Prerequisites

- **macOS** with Xcode 15.0+
- **Docker Desktop** (for local Supabase)
- **Supabase CLI**: `brew install supabase/tap/supabase`
- **Gemini API Key**: [Get from Google AI Studio](https://makersuite.google.com/app/apikey)

### Backend

```bash
cd backend

# Start Supabase (Docker must be running)
supabase start

# Apply database migrations
supabase db reset

# Create .env file with your Gemini API key
echo "GEMINI_API_KEY=your_key_here" > .env

# Start Edge Functions (keep this terminal open)
supabase functions serve --env-file .env --no-verify-jwt
```

**Auth locally:** Email confirmation is disabled in `config.toml`.

**Environment variables:** The only required variable is `GEMINI_API_KEY` in the `backend/.env` file. Supabase automatically provides `SUPABASE_URL` and `SUPABASE_ANON_KEY` to Edge Functions.

### iOS

**Configure Supabase URL + anon key:** Open `App/NeverGoneDemoApp.swift` and verify the URL and key match your local Supabase instance. The defaults work for all local setups:

```swift
let supabaseURL = "http://127.0.0.1:54321"
let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

Get your anon key with `cd backend && supabase status`.

**Run the app in Simulator:**

1. Open Xcode → create project named `NeverGoneDemo`
2. Add Supabase Swift package: `https://github.com/supabase/supabase-swift`
3. Add source files from `ios/NeverGoneDemo/NeverGoneDemo/`
4. Select an iPhone simulator and press ⌘R

**Sign up a test user:** Launch the app, enter any email (e.g. `test@example.com`) and password (min 6 chars), tap Sign Up. You're logged in immediately.

**Trigger a streaming response:** Create a new chat session with the + button, type a message, tap send. The AI response streams in word by word. Tap the red stop button to cancel mid-stream.

---

## What's Included

### iOS App (SwiftUI)

- Supabase email/password auth (sign up, sign in, sign out)
- Create and list chat sessions
- Chat screen with streaming assistant responses
- Cancel in-progress stream with stop button
- Memory summarization via brain icon
- MVVM architecture with Swift Concurrency (`async/await`)

### Backend (Supabase Edge Functions)

- **`chat_stream`** — Accepts `session_id` and `message`, persists the user message, streams a Gemini response via SSE, persists the assistant message when complete
- **`summarize_memory`** — Accepts `session_id`, fetches all messages, generates a summary via Gemini, saves to `memories` table

### Database (Postgres with RLS)

- `profiles` — User profiles, auto-created on signup
- `chat_sessions` — Chat conversations with user ownership
- `chat_messages` — Individual messages with role constraint
- `memories` — AI-generated conversation summaries
- `prompt_versions` — Versioned system prompts for AI behavior control

All tables have Row Level Security enabled. Users can only access their own data via `auth.uid()`.

### Prompt Versioning

System prompts are stored in the `prompt_versions` database table instead of being hardcoded. The `chat_stream` Edge Function fetches the active prompt before each Gemini API call. To change AI behavior, insert a new prompt version and mark it active — no code changes or redeployment needed.

### Admin Dashboard

A single-file web UI (`backend/admin.html`) for managing the backend locally. Open it in a browser, connect with your Supabase service role key, and you can:

- View all users, chat sessions, and memories across all users
- Create new prompt versions and switch the active prompt with one click
- See overview stats (user count, message count, etc.)

### Tests

- **iOS:** XCTests for streaming text accumulation, SSE parsing, role encoding, cancel behavior
- **Backend:** Deno tests for SSE format, request validation, Gemini format conversion, UUID validation

---

## Streaming Chat Flow

```
1. User types message in ChatView
         │
         ▼
2. ChatViewModel.sendMessage()
   - Adds message to UI optimistically
   - Calls streamResponse()
         │
         ▼
3. POST /functions/v1/chat_stream
   - Saves user message to DB
   - Calls Gemini API with streaming
         │
         ▼
4. SSE stream back to iOS
   data: {"content": "Hello"}
   data: {"content": " world"}
         │
         ▼
5. ChatViewModel parses SSE
   - Updates @Published streamingText
   - UI re-renders progressively
         │
         ▼
6. Stream completes
   - Full message saved to DB
   - Added to messages array
```

---

## Design Decisions & Tradeoffs

**SSE vs WebSockets** — Chose SSE because chat responses are one-way (server → client). Simpler than WebSockets, easy cancellation via HTTP abort, sufficient for this use case.

**Optimistic UI** — User messages appear immediately before server confirmation for better perceived performance. Slight chance of UI/DB mismatch, acceptable for a demo.

**RLS at database level** — Row Level Security enforced in Postgres rather than application code. Defense in depth, single source of truth for access control, works with any client.

**Prompt versioning in DB** — System prompts stored in Postgres rather than hardcoded in Edge Function code. Enables changing AI behavior without redeploying, keeps a history of all prompt versions, and a unique partial index ensures only one prompt is active at a time.

---

## Running Tests

### Backend (Deno)

```bash
cd backend/supabase/functions/chat_stream
deno test --no-check --allow-net index.test.ts
```

### iOS (XCTest)

In Xcode: **⌘U** or **Product → Test**

---

## Troubleshooting

**Supabase won't start** — Ensure Docker Desktop is running. Try `supabase stop` then `supabase start`.

**Streaming not working** — Ensure Edge Functions are running: `supabase functions serve --env-file .env --no-verify-jwt`. Check Gemini API key is set in `.env`. Look at terminal output for errors.

**iOS build fails** — Ensure Supabase package is added. Check iOS deployment target is 16.0+. Clean build folder: ⇧⌘K.

**Auth fails** — Email confirmation is disabled by default for local dev. Check `backend/supabase/config.toml` settings.

---




