# Production Deployment Checklist

## ✅ Security
- [x] No secrets in code
- [x] RLS policies on database
- [x] Storage bucket policies
- [x] JWT authentication
- [x] Signed URLs for audio (1-hour expiry)
- [x] File type validation
- [x] File size limits (50MB)

## ✅ Scalability
- [x] Retry logic (3 attempts)
- [x] Database indexes
- [x] Configurable backend URL
- [x] Timeout handling (60s)

## 🔧 TODO for Production

### Backend
1. **Add rate limiting** ✅
   - Implemented via `express-rate-limit` with configurable `RATE_LIMIT_WINDOW_MS` and `RATE_LIMIT_MAX`
   - All HTTP routes (including WebSocket handshakes) now share the limiter

2. **Add logging**
   ```bash
   npm install winston
   ```

3. **Deploy backend**
   - Use Railway, Render, or AWS
   - Set environment variables
   - Update `BACKEND_URL` in iOS Config.plist

4. **Enable CORS properly** ✅
   - Enforced via `ALLOWED_ORIGINS` (comma-separated list) consumed in `backend/src/index.ts`
   - Defaults to open in development when the variable is not set

### Database
1. **Run the new index**
   ```sql
   CREATE INDEX idx_sessions_user_start ON sessions(user_id, start_time DESC);
   ```

2. **Set up backups** (Supabase does this automatically)

3. **Monitor query performance** in Supabase dashboard

### Storage
1. **Set bucket size limits** in Supabase dashboard
2. **Enable CDN** for faster audio delivery
3. **Set up lifecycle policies** to delete old files

### iOS App
1. **Update Config.plist** with production backend URL
2. **Add error tracking** (Sentry, Crashlytics)
3. **Test on real devices**
4. **Submit to App Store**

### Web App
1. **Deploy to Vercel/Netlify**
2. **Update config.json** with production values
3. **Add analytics** (optional)

## Monitoring

### Supabase Dashboard
- Monitor database queries
- Check storage usage
- Review auth logs

### Backend Logs
- Track upload success/failure rates
- Monitor response times
- Alert on errors

## Cost Optimization

### Supabase Free Tier Limits
- 500MB database
- 1GB storage
- 2GB bandwidth/month

### Upgrade When:
- Storage > 1GB
- Bandwidth > 2GB/month
- Need more than 50,000 monthly active users

## Performance Targets
- Audio upload: < 5s for 10MB file
- Database query: < 100ms
- Audio playback: < 2s to start
