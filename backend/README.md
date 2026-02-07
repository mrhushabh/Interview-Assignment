# NeverGone Backend

Supabase backend with Edge Functions for streaming chat and memory summarization.

## Prerequisites

1. **Docker Desktop** - Required for local Supabase
   - Download: https://www.docker.com/products/docker-desktop

2. **Supabase CLI** - Install via Homebrew:
   ```bash
   brew install supabase/tap/supabase
   ```

3. **Gemini API Key** - Get from Google AI Studio:
   - https://makersuite.google.com/app/apikey

## Setup

### 1. Start Supabase

```bash
cd backend
supabase start
```

This starts local instances of:
- **PostgreSQL** (port 54322)
- **Auth** (port 54321)
- **Studio** (port 54323) - Web UI for database
- **Edge Functions Runtime**

### 2. Apply Database Migrations

```bash
supabase db reset
```

This creates the tables:
- `profiles` - User profiles
- `chat_sessions` - Chat conversations
- `chat_messages` - Individual messages
- `memories` - Summarized memories

### 3. Set Environment Variables

Create a `.env` file in the `backend` directory:

```bash
# backend/.env
GEMINI_API_KEY=your_gemini_api_key_here
```

### 4. Start Edge Functions

```bash
supabase functions serve --env-file .env --no-verify-jwt
```

> **Note:** The `--no-verify-jwt` flag is used for local development simplicity.

This starts the Edge Functions:
- `chat_stream` - Streaming chat responses
- `summarize_memory` - Memory summarization

## Local URLs

After `supabase start`, you'll see output like:

| Service | URL |
|---------|-----|
| API URL | `http://127.0.0.1:54321` |
| Studio | `http://127.0.0.1:54323` |
| Inbucket (Email) | `http://127.0.0.1:54324` |
| anon key | `eyJhbGci...` (copy this for iOS app) |

## Authentication

- **Local mode**: Email confirmation is **disabled** by default
- Users can sign up and immediately use the app
- Check `config.toml` → `[auth.email]` → `enable_confirmations = false`

## Edge Functions

### `chat_stream`

Streams AI responses via Server-Sent Events (SSE).

**Endpoint:** `POST /functions/v1/chat_stream`

**Headers:**
```
Authorization: Bearer <user_access_token>
apikey: <supabase_anon_key>
Content-Type: application/json
```

**Body:**
```json
{
  "session_id": "uuid",
  "message": "Hello, how are you?"
}
```

**Response:** SSE stream
```
data: {"content": "Hello"}

data: {"content": "! I'm"}

data: {"content": " doing great"}

```

### `summarize_memory`

Creates a memory summary from a chat session.

**Endpoint:** `POST /functions/v1/summarize_memory`

**Headers:** Same as above

**Body:**
```json
{
  "session_id": "uuid"
}
```

**Response:**
```json
{
  "memory": {
    "id": "uuid",
    "user_id": "uuid",
    "session_id": "uuid",
    "summary": "User discussed...",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

## Running Tests

```bash
cd backend/supabase/functions/chat_stream
deno test --allow-net index.test.ts
```

## Database Schema

```
┌─────────────────┐
│   auth.users    │  (Supabase built-in)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    profiles     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  chat_sessions  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│  chat_messages  │     │    memories     │
└─────────────────┘     └─────────────────┘
```

## Row Level Security (RLS)

All tables have RLS enabled:
- Users can only access their own data
- No hardcoded user IDs
- Uses `auth.uid()` for ownership checks

## Troubleshooting

### "Docker is not running"
Start Docker Desktop before running `supabase start`

### "Port already in use"
```bash
supabase stop
supabase start
```

### "Edge function not found"
Make sure you're running `supabase functions serve` from the `backend` directory

### "Gemini API error"
- Check your API key is correct in `.env`
- Verify the key has access to Gemini API
