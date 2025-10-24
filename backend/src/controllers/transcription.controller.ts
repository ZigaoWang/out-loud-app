import { WebSocket } from 'ws';
import { SonioxService } from '../services/soniox.service';
import { AIService } from '../services/ai.service';

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
}

export class TranscriptionController {
  private sessions: Map<string, Session> = new Map();
  private aiService: AIService;

  constructor() {
    this.aiService = new AIService();
  }

  async handleConnection(ws: WebSocket, sessionId: string) {
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
        console.log('No transcript to analyze');
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
          title: 'Learning Session',
        },
      }));
    }

    // Clean up
    this.sessions.delete(sessionId);
  }
}
