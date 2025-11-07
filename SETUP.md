# Out Loud - Setup Guide

> [!WARNING]
> This guide was AI-generated and may contain inaccuracies. Verify all setup steps before use.

## Prerequisites
- Supabase account (https://supabase.com)
- Soniox API key (https://soniox.com)
- OpenAI/UniAPI key
- Node.js 18+ for backend
- Xcode 15+ for iOS app

## 1. Supabase Setup

### Create Project
1. Go to https://supabase.com/dashboard
2. Create new project
3. Save your project URL and keys

### Run Database Schema
1. Go to SQL Editor in Supabase dashboard
2. Run `backend/supabase-setup.sql`

### Configure Authentication
1. Go to Authentication > Settings
2. Disable email confirmations (or configure SMTP)
3. Set minimum password length to 8

### Storage Bucket
The storage bucket `audio-recordings` is created automatically by the SQL script with proper RLS policies.

## 2. Backend Deployment

### Environment Variables
```bash
cd backend
cp ../.env.example .env
# Edit .env with your actual keys:
# SONIOX_API_KEY, OPENAI_API_KEY, OPENAI_BASE_URL,
# SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY, ALLOWED_ORIGINS
```


## 3. iOS App Configuration

### Create Config.plist
1. Copy `OutLoud/Config.example.plist` to `OutLoud/OutLoud/Config.plist`
2. Update values:
```xml
SUPABASE_URL: your-supabase-url
SUPABASE_ANON_KEY: your-anon-key
BACKEND_URL: https://your-backend.com
SUPABASE_EMAIL_REDIRECT_URL: https://your-web-app.com/status.html
```

### Update Production URLs
Edit `OutLoud/OutLoud/Utils/AppConstants.swift`:
```swift
static let productionWebSocketURL = "wss://your-backend.com"
```


## 4. Web App Deployment

### Create config.json
1. Copy `web/config.example.json` to `web/config.json`
2. Update values:
```json
{
  "SUPABASE_URL": "your-supabase-url",
  "SUPABASE_ANON_KEY": "your-anon-key"
}
```


## Support
For issues: https://github.com/ZigaoWang/out-loud-app/issues or contact a@zigao.wang
