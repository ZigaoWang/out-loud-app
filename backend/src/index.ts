import express from 'express';
import { createServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import cors from 'cors';
import { config } from '../config';
import { TranscriptionController } from './controllers/transcription.controller';

const app = express();
const server = createServer(app);
const wss = new WebSocketServer({ server });

const transcriptionController = new TranscriptionController();

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// WebSocket connection handler
wss.on('connection', (ws: WebSocket, req) => {
  const url = new URL(req.url!, `http://${req.headers.host}`);
  const sessionId = url.searchParams.get('sessionId') || `session_${Date.now()}`;

  console.log(`New WebSocket connection: ${sessionId}`);

  transcriptionController.handleConnection(ws, sessionId);
});

server.listen(config.port, () => {
  console.log(`🎙 Out Loud Backend running on port ${config.port}`);
  console.log(`WebSocket available at ws://localhost:${config.port}`);
});
