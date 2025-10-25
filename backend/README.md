# Out Loud Backend

Backend server for Out Loud app - handles real-time speech transcription and AI analysis.

## Stack

- **Node.js** + **Express** + **TypeScript**
- **WebSocket** for real-time audio streaming
- **Soniox API** for speech-to-text transcription
- **OpenAI API** (via UniAPI) for AI analysis and feedback

## Setup

1. Install dependencies:
```bash
cd backend
npm install
```

2. Configure environment variables (already in `.env`):
```env
SONIOX_API_KEY=your_key
OPENAI_API_KEY=your_key
OPENAI_BASE_URL=https://api.uniapi.io
```

3. Run development server:
```bash
npm run dev
```

4. Build for production:
```bash
npm run build
npm start
```

### Environment

Configure security-related environment variables before deploying:

- `ALLOWED_ORIGINS`: Comma-separated list of origins allowed via CORS (leave empty to allow all in local dev)
- `RATE_LIMIT_WINDOW_MS`: Optional window override for rate limiting (default 900000 / 15 minutes)
- `RATE_LIMIT_MAX`: Optional max requests per window for rate limiting (default 100)

## API Endpoints

### WebSocket Connection

Connect to: `wss://api.out-loud.app?sessionId=xxx&mode=solo`

For local development use: `ws://localhost:3799?sessionId=xxx&mode=solo`

**Headers:**
- `Authorization: Bearer <Supabase session access token>` (required)

**Query Parameters:**
- `sessionId`: Unique session identifier (optional, auto-generated if not provided)
- `mode`: `solo` or `interactive`

### Message Types

**Client → Server:**
- Binary audio data (PCM F32LE, 16kHz, mono)
- Empty buffer to signal end of session

**Server → Client:**
```json
// Transcript update
{
  "type": "transcript",
  "text": "transcribed text",
  "isFinal": true/false
}

// Real-time caption
{
  "type": "caption",
  "text": "Talking about Newton's law..."
}

// Interactive mode question
{
  "type": "interaction",
  "question": "Can you give an example?"
}

// Final analysis (sent at end)
{
  "type": "analysis",
  "data": {
    "summary": "...",
    "keywords": ["..."],
    "feedback": "...",
    "report": {
      "thinkingIntensity": 75,
      "pauseTime": 12,
      "coherenceScore": 80,
      "missingPoints": ["..."]
    },
    "followUpQuestion": "..."
  }
}
```

## Architecture

```
src/
├── index.ts                 # Server entry point
├── controllers/
│   └── transcription.controller.ts  # WebSocket handler
├── services/
│   ├── soniox.service.ts   # Soniox API integration
│   └── ai.service.ts       # OpenAI integration
config/
└── index.ts                # Configuration
```

## Audio Format

The backend expects audio in the following format:
- **Format**: PCM F32LE (32-bit float, little-endian)
- **Sample Rate**: 16kHz
- **Channels**: 1 (mono)

iOS app should capture and convert audio to this format before streaming.
