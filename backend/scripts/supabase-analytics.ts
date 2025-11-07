import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

async function generateAnalytics() {
  console.log('\n=== Out Loud Analytics Dashboard ===\n');

  // User metrics
  const { data: users, error: usersError } = await supabase.auth.admin.listUsers();
  if (usersError) {
    console.error('Error fetching users:', usersError);
    return;
  }

  const totalUsers = users.users.length;
  const last7Days = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const last30Days = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

  const newUsersLast7Days = users.users.filter(u => u.created_at > last7Days).length;
  const newUsersLast30Days = users.users.filter(u => u.created_at > last30Days).length;

  console.log('USERS');
  console.log(`  Total: ${totalUsers}`);
  console.log(`  New (7 days): ${newUsersLast7Days}`);
  console.log(`  New (30 days): ${newUsersLast30Days}`);
  console.log('');

  // Session metrics
  const { data: sessions, error: sessionsError } = await supabase
    .from('sessions')
    .select('*')
    .order('start_time', { ascending: false });

  if (sessionsError) {
    console.error('Error fetching sessions:', sessionsError);
    return;
  }

  const totalSessions = sessions.length;
  const sessionsLast7Days = sessions.filter(s => s.start_time > last7Days).length;
  const sessionsLast30Days = sessions.filter(s => s.start_time > last30Days).length;

  const durations = sessions.map(s => s.duration).filter(d => d > 0);
  const avgDuration = durations.length > 0 ? durations.reduce((a, b) => a + b, 0) / durations.length : 0;
  const medianDuration = durations.length > 0 ? durations.sort((a, b) => a - b)[Math.floor(durations.length / 2)] : 0;
  const maxDuration = durations.length > 0 ? Math.max(...durations) : 0;
  const minDuration = durations.length > 0 ? Math.min(...durations) : 0;

  const transcriptLengths = sessions.map(s => s.transcript?.length || 0).filter(l => l > 0);
  const avgTranscriptLength = transcriptLengths.length > 0 ? transcriptLengths.reduce((a, b) => a + b, 0) / transcriptLengths.length : 0;

  console.log('SESSIONS');
  console.log(`  Total: ${totalSessions}`);
  console.log(`  Last 7 days: ${sessionsLast7Days}`);
  console.log(`  Last 30 days: ${sessionsLast30Days}`);
  console.log(`  Avg duration: ${avgDuration.toFixed(1)}s`);
  console.log(`  Median duration: ${medianDuration.toFixed(1)}s`);
  console.log(`  Min/Max duration: ${minDuration.toFixed(1)}s / ${maxDuration.toFixed(1)}s`);
  console.log(`  Avg transcript length: ${avgTranscriptLength.toFixed(0)} chars`);
  console.log('');

  // User engagement
  const userSessionCounts = sessions.reduce((acc, s) => {
    acc[s.user_id] = (acc[s.user_id] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const sessionCounts = Object.values(userSessionCounts) as number[];
  const avgSessionsPerUser = sessionCounts.length > 0 ? sessionCounts.reduce((a, b) => a + b, 0) / sessionCounts.length : 0;
  const activeUsers = sessionCounts.filter(count => count >= 3).length;
  const powerUsers = sessionCounts.filter(count => count >= 10).length;

  console.log('ENGAGEMENT');
  console.log(`  Avg sessions per user: ${avgSessionsPerUser.toFixed(1)}`);
  console.log(`  Active users (3+ sessions): ${activeUsers}`);
  console.log(`  Power users (10+ sessions): ${powerUsers}`);
  console.log(`  Retention rate: ${totalUsers > 0 ? ((sessionCounts.length / totalUsers) * 100).toFixed(1) : 0}%`);
  console.log('');

  // Content analysis
  const sessionsWithAnalysis = sessions.filter(s => s.analysis).length;
  const analysisRate = totalSessions > 0 ? (sessionsWithAnalysis / totalSessions) * 100 : 0;

  const allKeywords = sessions
    .filter(s => s.analysis?.keywords)
    .flatMap(s => s.analysis.keywords);

  const keywordCounts = allKeywords.reduce((acc, kw) => {
    acc[kw] = (acc[kw] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const topKeywords = Object.entries(keywordCounts)
    .sort((a, b) => (b[1] as number) - (a[1] as number))
    .slice(0, 10);

  console.log('CONTENT');
  console.log(`  Sessions with AI analysis: ${sessionsWithAnalysis} (${analysisRate.toFixed(1)}%)`);
  if (topKeywords.length > 0) {
    console.log('  Top keywords:');
    topKeywords.forEach(([kw, count]) => {
      console.log(`    ${kw}: ${count}`);
    });
  }
  console.log('');

  // Time analysis
  const sessionsByHour = sessions.reduce((acc, s) => {
    const hour = new Date(s.start_time).getHours();
    acc[hour] = (acc[hour] || 0) + 1;
    return acc;
  }, {} as Record<number, number>);

  const peakHour = Object.entries(sessionsByHour)
    .sort((a, b) => (b[1] as number) - (a[1] as number))[0];

  const sessionsByDay = sessions.reduce((acc, s) => {
    const day = new Date(s.start_time).getDay();
    acc[day] = (acc[day] || 0) + 1;
    return acc;
  }, {} as Record<number, number>);

  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const peakDay = Object.entries(sessionsByDay)
    .sort((a, b) => (b[1] as number) - (a[1] as number))[0];

  console.log('USAGE PATTERNS');
  if (peakHour) {
    console.log(`  Peak hour: ${peakHour[0]}:00 (${peakHour[1]} sessions)`);
  }
  if (peakDay) {
    console.log(`  Peak day: ${days[parseInt(peakDay[0])]} (${peakDay[1]} sessions)`);
  }
  console.log('');

  console.log('=====================================\n');
}

generateAnalytics().catch(console.error);
