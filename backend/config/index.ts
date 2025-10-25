import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: process.env.PORT || 3799,
  soniox: {
    apiKey: process.env.SONIOX_API_KEY || '',
    wsUrl: 'wss://stt-rt.soniox.com/transcribe-websocket',  // FIXED: Correct Soniox URL
    model: 'stt-rt-preview',
  },
  openai: {
    apiKey: process.env.OPENAI_API_KEY || '',
    baseUrl: (process.env.OPENAI_BASE_URL || 'https://api.uniapi.io') + '/v1',
    model: 'gpt-4.1',  // UniAPI model
  },
  supabase: {
    url: process.env.SUPABASE_URL || '',
    serviceKey: process.env.SUPABASE_SERVICE_KEY || '',
    anonKey: process.env.SUPABASE_ANON_KEY || '',
  },
  security: {
    allowedOrigins: process.env.ALLOWED_ORIGINS || '',
    rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
    rateLimitMax: parseInt(process.env.RATE_LIMIT_MAX || '100', 10),
  },
};
