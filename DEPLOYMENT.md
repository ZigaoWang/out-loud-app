# Out Loud - Production Deployment Guide

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
2. Run `backend/supabase-schema.sql`
3. Run `backend/supabase-storage-setup.sql`

### Configure Authentication
1. Go to Authentication > Settings
2. Disable email confirmations (or configure SMTP)
3. Set minimum password length to 6

### Storage Bucket
The storage bucket `audio-recordings` is created automatically by the SQL script with proper RLS policies.

## 2. Backend Deployment

### Environment Variables
```bash
cd backend
cp ../.env.example .env
# Edit .env with your actual keys
```

### Deploy Options

#### Option A: Railway/Render/Fly.io
1. Connect your GitHub repo
2. Set environment variables in dashboard
3. Deploy from `backend` directory
4. Set start command: `npm start`

#### Option B: AWS/GCP/Azure
1. Build: `npm run build`
2. Deploy `dist/` folder
3. Set environment variables
4. Run: `node dist/index.js`

## 3. iOS App Configuration

### Update Supabase Keys
Edit `OutLoud/OutLoud/Services/SupabaseService.swift`:
```swift
client = SupabaseClient(
    supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
    supabaseKey: "YOUR_SUPABASE_ANON_KEY"
)
```

### Update Backend URL
Edit `OutLoud/OutLoud/ViewModels/SessionViewModel.swift`:
```swift
init(serverURL: String = "wss://your-backend.com", ...)
```

### App Store Submission
1. Update bundle identifier
2. Add privacy policy URL
3. Configure App Store Connect
4. Submit for review

## 4. Web App Deployment

### Update Keys
Edit `web/index.html`:
```javascript
const supabase = createClient(
    'YOUR_SUPABASE_URL',
    'YOUR_SUPABASE_ANON_KEY'
);
```

### Deploy Options
- **Vercel**: `vercel deploy web/`
- **Netlify**: Drag & drop `web/` folder
- **GitHub Pages**: Push to gh-pages branch

## 5. Security Checklist

✅ All API keys in environment variables (not hardcoded)
✅ Row Level Security enabled on Supabase
✅ Storage bucket has proper RLS policies
✅ HTTPS/WSS only in production
✅ .env files in .gitignore
✅ Supabase anon key (not service key) in client apps

## 6. Scaling Considerations

### Database
- Supabase auto-scales with your plan
- Add indexes for performance (already included)
- Monitor query performance in dashboard

### Storage
- Audio files stored in Supabase Storage
- Automatic CDN distribution
- Upgrade plan as needed

### Backend
- Stateless design allows horizontal scaling
- WebSocket connections handled per instance
- Use load balancer for multiple instances

## 7. Monitoring

### Supabase Dashboard
- Monitor database usage
- Check storage usage
- View API logs

### Backend Logs
- Check application logs for errors
- Monitor WebSocket connections
- Track API response times

## 8. Cost Optimization

### Free Tier Limits
- Supabase: 500MB database, 1GB storage
- Upgrade when needed

### Recommendations
- Delete old audio files periodically
- Compress audio before upload
- Monitor usage in dashboard

## Support
For issues, check:
- Supabase docs: https://supabase.com/docs
- GitHub issues
- Application logs
