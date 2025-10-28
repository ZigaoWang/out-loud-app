import express from 'express';
import { createServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import cors, { CorsOptions } from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config } from '../config';
import { TranscriptionController } from './controllers/transcription.controller';
import { SupabaseService } from './services/supabase.service';
import authRoutes from './routes/auth.routes';
import sessionsRoutes from './routes/sessions.routes';
import uploadRoutes from './routes/upload.routes';

const app = express();
const server = createServer(app);
const wss = new WebSocketServer({ server });

const transcriptionController = new TranscriptionController();
const supabaseService = new SupabaseService();

const allowedOrigins = config.security.allowedOrigins
  ? config.security.allowedOrigins
      .split(',')
      .map(origin => origin.trim())
      .filter(Boolean)
  : [];

const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    if (allowedOrigins.length === 0) {
      callback(new Error('CORS not configured'));
      return;
    }
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
};

const apiRateLimiter = rateLimit({
  windowMs: config.security.rateLimitWindowMs,
  max: config.security.rateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(helmet());
app.use(cors(corsOptions));
app.use(apiRateLimiter);
app.use(express.json({ limit: '1mb' }));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/auth', authRoutes);
app.use('/sessions', sessionsRoutes);
app.use('/upload', uploadRoutes);

// WebSocket connection handler
wss.on('connection', async (ws: WebSocket, req) => {
  const url = new URL(req.url!, `http://${req.headers.host}`);
  const sessionId = url.searchParams.get('sessionId');

  if (!sessionId || sessionId.length > 255) {
    ws.send(JSON.stringify({ type: 'error', message: 'Invalid session ID' }));
    ws.close(1008, 'Invalid session ID');
    return;
  }

  const authHeader = req.headers['authorization'];
  const rawToken = Array.isArray(authHeader) ? authHeader[0] : authHeader;

  if (!rawToken || !rawToken.toLowerCase().startsWith('bearer ')) {
    ws.send(JSON.stringify({ type: 'error', message: 'Unauthorized WebSocket connection' }));
    ws.close(1008, 'Unauthorized');
    return;
  }

  const accessToken = rawToken.replace(/^[Bb]earer\s+/, '');

  try {
    const { data, error } = await supabaseService.verifyToken(accessToken);

    if (error || !data?.user?.id) {
      ws.send(JSON.stringify({ type: 'error', message: 'Invalid or expired token' }));
      ws.close(1008, 'Unauthorized');
      return;
    }

    console.log(`New WebSocket connection: ${sessionId} (user: ${data.user.id})`);

    transcriptionController.handleConnection(ws, sessionId, data.user.id);
  } catch (err) {
    console.error('WebSocket auth error:', err);
    ws.send(JSON.stringify({ type: 'error', message: 'Authentication failed' }));
    ws.close(1011, 'Authentication failed');
  }
});

server.listen(config.port, () => {
  console.log(`🎙 Out Loud Backend running on port ${config.port}`);
  console.log(`WebSocket available at ws://localhost:${config.port}`);
});
