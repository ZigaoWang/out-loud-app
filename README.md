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

### Backend
```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your API keys
npm run dev
```

### Web App
```bash
cd web
cp config.example.json config.json
# Edit config.json with Supabase credentials
open index.html
```

### iOS App
1. Open `OutLoud/OutLoud.xcodeproj` in Xcode
2. Copy `Config.example.plist` to `Config.plist`
3. Add Supabase credentials to `Config.plist`
4. Build and run

### Database
Run `backend/supabase-schema.sql` in your Supabase SQL Editor.

## Environment Variables

Backend (.env):
```
SUPABASE_URL=your-url
SUPABASE_SERVICE_KEY=your-service-key
SONIOX_API_KEY=your-soniox-key
```

Web (config.json):
```json
{
  "SUPABASE_URL": "your-url",
  "SUPABASE_ANON_KEY": "your-anon-key"
}
```
