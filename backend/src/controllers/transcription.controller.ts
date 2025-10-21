import { WebSocket } from 'ws';
import { SonioxService } from '../services/soniox.service';
import { AIService } from '../services/ai.service';

interface Session {
  id: string;
  mode: 'solo' | 'interactive';
  transcript: string;
  startTime: number;
  pauseTimes: number[];
  sonioxService: SonioxService;
  clientWs: WebSocket;
  lastCaptionTime: number;
  sentFinalTexts: Set<string>; // Track all sent final transcripts
}

export class TranscriptionController {
  private sessions: Map<string, Session> = new Map();
  private aiService: AIService;

  constructor() {
    this.aiService = new AIService();
  }

  async handleConnection(ws: WebSocket, sessionId: string, mode: 'solo' | 'interactive') {
    const sonioxService = new SonioxService();

    const session: Session = {
      id: sessionId,
      mode,
      transcript: '',
      startTime: Date.now(),
      pauseTimes: [],
      sonioxService,
      clientWs: ws,
      lastCaptionTime: 0,
      sentFinalTexts: new Set(),
    };

    this.sessions.set(sessionId, session);

    try {
      await sonioxService.connect();

      // Handle transcription from Soniox
      sonioxService.onTranscript(async (text: string, isFinal: boolean) => {
        // Clean the text - remove markers and trim
        const cleanedText = text.replace(/<end>/gi, '').trim();

        if (!cleanedText) return; // Skip empty text

        // For final transcripts, check if we already sent this exact text
        if (isFinal) {
          if (session.sentFinalTexts.has(cleanedText)) {
            console.log('Skipping duplicate final transcript:', cleanedText);
            return; // Skip duplicate
          }
          session.sentFinalTexts.add(cleanedText);
          session.transcript += cleanedText + ' ';
        }

        // Send transcript to client
        ws.send(JSON.stringify({
          type: 'transcript',
          text: cleanedText,
          isFinal,
        }));

        // Generate real-time caption every 5-10 seconds (using 7 seconds as middle ground)
        const now = Date.now();
        const timeSinceLastCaption = (now - session.lastCaptionTime) / 1000;

        if (timeSinceLastCaption >= 7 && session.transcript.length > 20) {
          session.lastCaptionTime = now;

          try {
            const caption = await this.aiService.generateRealtimeCaption(session.transcript);
            if (caption) {
              ws.send(JSON.stringify({
                type: 'caption',
                text: caption,
              }));
            }
          } catch (error) {
            console.error('Caption generation failed:', error);
          }
        }

        // For interactive mode, check if we should intervene
        if (mode === 'interactive' && isFinal) {
          try {
            const suggestion = await this.aiService.shouldInteractNow(
              session.transcript,
              session.pauseTimes.slice(-5),
              ''
            );

            if (suggestion.shouldInterrupt && suggestion.question) {
              ws.send(JSON.stringify({
                type: 'interaction',
                question: suggestion.question,
              }));
            }
          } catch (error) {
            console.error('Interactive question failed:', error);
          }
        }
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
      // Generate AI analysis from the full transcript
      const analysis = await this.aiService.analyzeSession(
        session.transcript.trim(),
        duration
      );

      // Send analysis to client
      session.clientWs.send(JSON.stringify({
        type: 'analysis',
        data: analysis,
      }));
    } catch (error) {
      console.error('AI analysis failed:', error);

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
        },
      }));
    }

    // Clean up
    this.sessions.delete(sessionId);
  }
}
