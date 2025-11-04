# Out Loud

Voice recording app with real-time transcription and AI analysis.

## Features
- Real-time audio recording
- Live transcription via Soniox
- AI-powered analysis
- Cloud sync with Supabase
- User authentication
- Web dashboard

## Setup

For detailed setup and deployment instructions, see [SETUP.md](SETUP.md).

## Environment Variables

Backend (.env):
```
SONIOX_API_KEY=your-soniox-key
OPENAI_API_KEY=your-openai-key
OPENAI_BASE_URL=https://api.uniapi.io
SUPABASE_URL=your-supabase-url
SUPABASE_SERVICE_KEY=your-service-key
SUPABASE_ANON_KEY=your-anon-key
ALLOWED_ORIGINS=null
```

Web (config.json):
```json
{
  "SUPABASE_URL": "your-url",
  "SUPABASE_ANON_KEY": "your-anon-key"
}
```
