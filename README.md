# Out Loud - Voice Recording & Transcription App

Real-time voice recording with AI transcription and analysis.

## Features
- 🎙️ Real-time audio recording
- 📝 Live transcription via Soniox
- 🧠 AI-powered analysis
- ☁️ Cloud sync with Supabase
- 🔒 Secure user authentication
- 🌐 Web dashboard

## Setup

### 1. Backend
```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your credentials
npm run dev
```

### 2. Web App
```bash
cd web
cp config.example.json config.json
# Edit config.json with your Supabase credentials
open index.html
```

### 3. iOS App
1. Open `OutLoud/OutLoud.xcodeproj` in Xcode
2. Copy `Config.example.plist` to `Config.plist`
3. Add your Supabase credentials to `Config.plist`
4. Add `Config.plist` to Xcode project
5. Build and run

### 4. Database Setup
Run the SQL in `backend/supabase-schema.sql` in your Supabase SQL Editor.

## Security
See [SECURITY.md](SECURITY.md) for security setup and policies.

## Environment Variables

### Backend (.env)
```
SUPABASE_URL=your-url
SUPABASE_SERVICE_KEY=your-service-key
SONIOX_API_KEY=your-soniox-key
```

### Web (config.json)
```json
{
  "SUPABASE_URL": "your-url",
  "SUPABASE_ANON_KEY": "your-anon-key"
}
```

## License
MIT
