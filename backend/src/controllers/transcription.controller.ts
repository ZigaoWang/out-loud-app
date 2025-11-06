import { WebSocket } from 'ws';
import { SonioxService } from '../services/soniox.service';
import { AIService } from '../services/ai.service';
import { SupabaseService } from '../services/supabase.service';
import logger from '../utils/logger';

interface TranscriptWord {
  word: string;
  startTime: number;
  endTime: number;
}

interface Session {
  id: string;
  transcript: string;
  startTime: number;
  pauseTimes: number[];
  sonioxService: SonioxService;
  clientWs: WebSocket;
  sentFinalTexts: Set<string>;
  words: TranscriptWord[];
  userId?: string;
}

export class TranscriptionController {
  private sessions: Map<string, Session> = new Map();
  private aiService: AIService;
  private supabaseService: SupabaseService;

  constructor() {
    this.aiService = new AIService();
    this.supabaseService = new SupabaseService();
  }

  async handleConnection(ws: WebSocket, sessionId: string, userId?: string) {
    const sonioxService = new SonioxService();

    const session: Session = {
      id: sessionId,
      transcript: '',
      startTime: Date.now(),
      pauseTimes: [],
      sonioxService,
      clientWs: ws,
      sentFinalTexts: new Set(),
      words: [],
      userId,
    };

    this.sessions.set(sessionId, session);

    try {
      await sonioxService.connect();

      // Handle transcription from Soniox
      sonioxService.onTranscript(async (text: string, isFinal: boolean, words?: TranscriptWord[]) => {
        // Clean the text - remove markers and trim
        const cleanedText = text.replace(/<end>/gi, '').replace(/<\/end>/gi, '').trim();

        if (!cleanedText) return; // Skip empty text

        // Clean words too
        let cleanedWords = words;
        if (words && words.length > 0) {
          cleanedWords = words
            .map(w => ({
              ...w,
              word: w.word.replace(/<end>/gi, '').replace(/<\/end>/gi, '').trim()
            }))
            .filter(w => w.word.length > 0); // Remove empty words
        }

        // For final transcripts, check if we already sent this exact text
        if (isFinal) {
          if (session.sentFinalTexts.has(cleanedText)) {
            console.log('Skipping duplicate final transcript:', cleanedText);
            return; // Skip duplicate
          }
          session.sentFinalTexts.add(cleanedText);
          session.transcript = cleanedText; // Use cleaned text directly, not append

          // Store word-level timestamps
          if (cleanedWords && cleanedWords.length > 0) {
            session.words = cleanedWords;
          }
        }

        // Send transcript to client
        ws.send(JSON.stringify({
          type: 'transcript',
          text: cleanedText,
          isFinal,
          words: isFinal ? cleanedWords : undefined, // Only send words with final transcripts
        }));
      });

      sonioxService.onEndpoint(() => {
        // Track pause
        const now = Date.now();
        const lastPause = now - session.startTime;
        session.pauseTimes.push(lastPause / 1000);
      });

      // Handle client messages (audio data)
      ws.on('message', async (data: Buffer) => {
        if (data.length === 0) {
          // End signal
          await this.endSession(sessionId);
        } else if (data.length > 1024 * 1024) {
          // Reject audio chunks larger than 1MB
          console.error('❌ Audio chunk too large:', data.length);
          ws.send(JSON.stringify({ type: 'error', message: 'Audio chunk too large' }));
        } else {
          // Forward audio to Soniox
          sonioxService.sendAudio(data);
        }
      });

      ws.on('close', () => {
        this.endSession(sessionId);
      });

    } catch (error) {
      console.error('Error setting up transcription:', error);
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Failed to connect to transcription service',
      }));
      ws.close();
    }
  }

  async endSession(sessionId: string) {
    const session = this.sessions.get(sessionId);
    if (!session) return;

    // Stop transcription
    session.sonioxService.stopTranscription();
    session.sonioxService.disconnect();

    // Calculate session duration
    const duration = (Date.now() - session.startTime) / 1000;

    try {
      // Generate AI analysis and title from the full transcript
      // Clean any remaining markers
      const transcript = session.transcript
        .replace(/<end>/gi, '')
        .replace(/<\/end>/gi, '')
        .trim();

      if (!transcript) {
        logger.warn('no_transcript_to_analyze', { sessionId });
        return;
      }

      if (transcript.length > 50000) {
        logger.error('transcript_too_long', { sessionId, length: transcript.length });
        return;
      }

      const [analysis, title] = await Promise.all([
        this.aiService.analyzeSession(transcript, duration),
        this.aiService.generateSessionTitle(transcript),
      ]);

      // Add title to analysis
      const analysisWithTitle = {
        ...analysis,
        title,
      };

      // Send analysis to client with word-level timestamps
      session.clientWs.send(JSON.stringify({
        type: 'analysis',
        data: analysisWithTitle,
        words: session.words, // Include word-level timestamps
      }));

      // Save to Supabase if user is authenticated
      if (session.userId) {
        try {
          await this.supabaseService.saveSession(session.userId, {
            id: sessionId,
            transcript,
            transcriptSegments: session.words,
            startTime: new Date(session.startTime).toISOString(),
            endTime: new Date().toISOString(),
            duration,
            analysis: analysisWithTitle,
            title: title,
          });
          logger.info('session_saved', { sessionId, userId: session.userId, duration });
        } catch (error) {
          logger.error('session_save_failed', { sessionId, userId: session.userId, error: error instanceof Error ? error.message : 'Unknown error' });
        }
      }
    } catch (error) {
      logger.error('ai_analysis_failed', { sessionId, error: error instanceof Error ? error.message : 'Unknown error' });

      // Fallback: send basic response if AI fails
      session.clientWs.send(JSON.stringify({
        type: 'analysis',
        data: {
          summary: session.transcript || 'Session completed.',
          keywords: [],
          feedback: `Session duration: ${duration.toFixed(1)}s. Analysis temporarily unavailable.`,
          report: {
            thinkingIntensity: 50,
            pauseTime: Math.round(session.pauseTimes.reduce((a, b) => a + b, 0)),
            coherenceScore: 50,
            missingPoints: [],
          },
          followUpQuestion: 'What did you learn from this session?',
          title: 'Learning Session',
        },
      }));
    }

    // Clean up
    this.sessions.delete(sessionId);
  }
}
