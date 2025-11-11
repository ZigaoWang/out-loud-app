# Out Loud

Voice recording app with real-time transcription and AI analysis.

## Features
- **Instant capture** – SwiftUI client streams 16 kHz PCM audio over WebSocket with Soniox-powered transcription updates.
- **AI feedback loop** – OpenAI (via UniAPI) summarizes sessions, generates captions, and surfaces interactive follow-up questions in real time.
- **Unified auth** – Supabase authentication works across iOS, the admin web dashboard, and the standalone status page, so every session stays tied to one account.
- **Session review console** – Web dashboard lists recordings, supports inline editing/deletion, and hosts password reset / resend-confirmation flows via `status.html`.
- **Deployable backend** – TypeScript/Express server with rate limiting, CORS controls, and environment-driven Soniox/OpenAI/Supabase integrations.

## Setup

For detailed setup and deployment instructions, see [SETUP.md](SETUP.md).

## License
See [`LICENSE`](LICENSE) for proprietary licensing terms and usage restrictions.
