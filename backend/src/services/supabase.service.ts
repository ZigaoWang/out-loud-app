import { createClient, SupabaseClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabaseClient = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

export const supabase = supabaseClient;

export class SupabaseService {
  private supabase: SupabaseClient;

  constructor() {
    this.supabase = supabaseClient;
  }

  async signUp(email: string, password: string) {
    const { data, error } = await this.supabase.auth.signUp({ email, password });
    if (error) throw error;
    return data;
  }

  async signIn(email: string, password: string) {
    const { data, error } = await this.supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  }

  async saveSession(userId: string, sessionData: any) {
    const { data, error } = await this.supabase
      .from('sessions')
      .insert({
        user_id: userId,
        session_id: sessionData.id,
        transcript: sessionData.transcript,
        transcript_segments: sessionData.transcriptSegments,
        start_time: sessionData.startTime,
        end_time: sessionData.endTime,
        duration: sessionData.duration,
        analysis: sessionData.analysis,
        title: sessionData.title,
      })
      .select()
      .single();
    if (error) throw error;
    return data;
  }

  async getSessions(userId: string) {
    const { data, error } = await this.supabase
      .from('sessions')
      .select('*')
      .eq('user_id', userId)
      .order('start_time', { ascending: false });
    if (error) throw error;
    return data;
  }

  async getSession(userId: string, sessionId: string) {
    const { data, error } = await this.supabase
      .from('sessions')
      .select('*')
      .eq('user_id', userId)
      .eq('session_id', sessionId)
      .single();
    if (error) throw error;
    return data;
  }

  async deleteSession(userId: string, sessionId: string) {
    const { error } = await this.supabase
      .from('sessions')
      .delete()
      .eq('user_id', userId)
      .eq('session_id', sessionId);
    if (error) throw error;
  }

  verifyToken(token: string) {
    return this.supabase.auth.getUser(token);
  }
}
