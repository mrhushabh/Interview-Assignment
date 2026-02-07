# NeverGone iOS App

SwiftUI app with streaming chat, authentication, and memory features.

## Prerequisites

- **Xcode 15.0+** (download from App Store)
- **iOS 16.0+** deployment target
- **Supabase backend running** (see `backend/README.md`)

## Setup Instructions

### Step 1: Create Xcode Project

1. Open **Xcode**
2. **File → New → Project**
3. Select **iOS → App**
4. Configure:
   - **Product Name:** `NeverGoneDemo`
   - **Organization Identifier:** `com.yourname` (any identifier)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None
   - ✅ Include Tests
5. **Save location:** Inside the `ios/` directory (replace existing empty folders)

### Step 2: Add Supabase Package

1. In Xcode: **File → Add Package Dependencies**
2. Enter URL: `https://github.com/supabase/supabase-swift`
3. Click **Add Package**
4. Select version: **2.0.0** or later
5. Add to target: **NeverGoneDemo**

### Step 3: Add Source Files

1. In Finder, go to `ios/NeverGoneDemo/NeverGoneDemo/`
2. In Xcode, right-click on the **NeverGoneDemo** folder (blue icon)
3. Select **Add Files to "NeverGoneDemo"**
4. Select all folders: `App/`, `Models/`, `ViewModels/`, `Views/`, `Services/`
5. Ensure:
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ NeverGoneDemo target is checked
6. Click **Add**

### Step 4: Add Test Files

1. Right-click on **NeverGoneDemoTests** folder
2. **Add Files to "NeverGoneDemo"**
3. Navigate to `ios/NeverGoneDemo/NeverGoneDemoTests/`
4. Select `ChatViewModelTests.swift`
5. Ensure **NeverGoneDemoTests** target is checked
6. Click **Add**

### Step 5: Delete Default Files

Xcode creates some default files. Delete these (they're replaced by our files):
- `ContentView.swift` (if exists)
- `NeverGoneDemoApp.swift` (the default one - we have our own in `App/`)

### Step 6: Configure Supabase URL (if needed)

Open `App/NeverGoneDemoApp.swift` and verify:

```swift
let supabaseURL = "http://127.0.0.1:54321"
let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

The default anon key works for all local Supabase instances. If yours is different, get it from:
```bash
cd backend
supabase status
```

### Step 7: Build and Run

1. Select a simulator (e.g., **iPhone 15**)
2. Press **⌘R** to build and run

## Usage

### Sign Up

1. Launch the app
2. Enter any email (e.g., `test@example.com`)
3. Enter password (min 6 characters)
4. Tap **Sign Up**

Email confirmation is disabled for local development, so you'll be logged in immediately.

### Create a Chat

1. Tap **+** in the top right
2. Enter a title (optional)
3. Tap **Create**

### Send a Message

1. Open a chat
2. Type a message
3. Tap the send button (↑)
4. Watch the AI response stream in real-time!

### Cancel Streaming

While the AI is responding:
- Tap the **red stop button** (⏹) to cancel
- The partial response will be saved

### Create a Memory

1. In a chat with messages
2. Tap the **brain icon** (🧠) in the toolbar
3. A memory summary will be created

### Sign Out

- Tap **Sign Out** in the sessions list

## Architecture

```
┌─────────────────────────────────────────┐
│                 VIEWS                   │
│   AuthView → SessionsView → ChatView    │
└─────────────────┬───────────────────────┘
                  │ @StateObject
                  ▼
┌─────────────────────────────────────────┐
│              VIEW MODELS                │
│   AuthVM    SessionsVM    ChatVM        │
│   (login)   (CRUD)       (streaming)    │
└─────────────────┬───────────────────────┘
                  │ async/await
                  ▼
┌─────────────────────────────────────────┐
│           SUPABASE SERVICE              │
│   - Auth (sign in/up/out)               │
│   - Database (sessions, messages)       │
│   - Edge Functions (chat, summarize)    │
└─────────────────────────────────────────┘
```

## Streaming Implementation

The `ChatViewModel` handles SSE streaming:

1. **Send Request** → POST to `/functions/v1/chat_stream`
2. **Receive Bytes** → `URLSession.shared.bytes(for: request)`
3. **Parse SSE** → Extract `data: {"content": "..."}` lines
4. **Update UI** → Append to `@Published streamingText`
5. **Save Message** → Store complete response when done

Cancellation is handled via `Task.cancel()` which stops the byte iteration.

## Running Tests

In Xcode:
- **⌘U** to run all tests
- Or use **Test Navigator** (⌘6)

## Troubleshooting

### "Cannot find 'SupabaseClient' in scope"
- Ensure Supabase package is added (Step 2)
- Clean build: **Product → Clean Build Folder** (⇧⌘K)

### "Cannot connect to server"
- Ensure Supabase is running: `cd backend && supabase start`
- Ensure Edge Functions are running: `supabase functions serve --env-file .env`
- Check URL in `NeverGoneDemoApp.swift`

### "401 Unauthorized"
- Sign out and sign in again
- Check that the anon key matches your Supabase instance

### Streaming not working
- Check Edge Functions are running
- Look at Xcode console for error messages
- Verify Gemini API key is set in `.env`

### Build errors
- Verify iOS deployment target is 16.0+
- Ensure all files are added to the correct target
