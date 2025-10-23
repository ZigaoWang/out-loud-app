import WebSocket from 'ws';
import { config } from '../../config';

interface SonioxConfig {
  api_key: string;
  model: string;
  language_hints?: string[];
  enable_endpoint_detection?: boolean;
  audio_format: string;
  sample_rate: number;
  num_channels: number;
}

interface TranscriptWord {
  word: string;
  startTime: number; // in seconds
  endTime: number;
}

interface TranscriptSegment {
  text: string;
  words: TranscriptWord[];
  startTime: number;
  endTime: number;
}

export class SonioxService {
  private ws: WebSocket | null = null;
  private onTranscriptCallback: ((text: string, isFinal: boolean, words?: TranscriptWord[]) => void) | null = null;
  private onEndpointCallback: (() => void) | null = null;
  private finalTranscript: string = ''; // Accumulated final tokens
  private allWords: TranscriptWord[] = []; // Accumulated word-level timestamps

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.finalTranscript = ''; // Reset on new connection
      this.allWords = []; // Reset word timestamps
      this.ws = new WebSocket(config.soniox.wsUrl);

      this.ws.on('open', () => {
        console.log('Connected to Soniox WebSocket');

        // Send configuration
        const sonioxConfig: SonioxConfig = {
          api_key: config.soniox.apiKey,
          model: config.soniox.model,
          language_hints: ['zh', 'en'],
          enable_endpoint_detection: true,
          audio_format: 'pcm_f32le',
          sample_rate: 16000,
          num_channels: 1,
        };

        this.ws?.send(JSON.stringify(sonioxConfig));
        resolve();
      });

      this.ws.on('message', (data: WebSocket.Data) => {
        try {
          const message = JSON.parse(data.toString());

          console.log('Soniox message:', JSON.stringify(message)); // Debug log

          // Check for error from Soniox
          if (message.error_code) {
            console.error(`Soniox error: ${message.error_code} - ${message.error_message}`);
            return;
          }

          // Parse tokens according to Soniox API docs
          if (message.tokens && message.tokens.length > 0) {
            let finalTokens = '';
            let nonFinalTokens = '';
            const finalSubwords: Array<{text: string, start_ms: number, end_ms: number}> = [];

            // Separate final and non-final tokens
            for (const token of message.tokens) {
              if (token.text) {
                if (token.is_final) {
                  finalTokens += token.text;

                  // Collect subwords with timestamps - NO offset needed!
                  // Soniox timestamps are ALREADY relative to the audio stream
                  if (token.start_ms !== undefined && token.end_ms !== undefined) {
                    finalSubwords.push({
                      text: token.text,
                      start_ms: token.start_ms,
                      end_ms: token.end_ms,
                    });
                  }
                } else {
                  nonFinalTokens += token.text;
                }
              }
            }

            // Merge subwords into full words
            const finalWords = this.mergeSubwordsIntoWords(finalSubwords);

            // Handle final tokens - append to accumulated transcript
            if (finalTokens && this.onTranscriptCallback) {
              this.finalTranscript += finalTokens;
              this.allWords.push(...finalWords);
              this.onTranscriptCallback(this.finalTranscript, true, this.allWords);
            }

            // Handle non-final tokens - send as preview (will be replaced)
            if (nonFinalTokens && this.onTranscriptCallback) {
              const previewText = this.finalTranscript + nonFinalTokens;
              this.onTranscriptCallback(previewText, false);
            }
          }

          // Check for finished
          if (message.finished) {
            console.log('Soniox session finished');
          }
        } catch (error) {
          console.error('Error parsing Soniox message:', error);
          console.error('Raw message:', data.toString());
        }
      });

      this.ws.on('error', (error) => {
        console.error('Soniox WebSocket error:', error);
        reject(error);
      });

      this.ws.on('close', () => {
        console.log('Soniox WebSocket closed');
      });
    });
  }

  sendAudio(audioData: Buffer): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(audioData);
    }
  }

  stopTranscription(): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      // Send empty audio to signal end
      this.ws.send(Buffer.alloc(0));
    }
  }

  disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  onTranscript(callback: (text: string, isFinal: boolean, words?: TranscriptWord[]) => void): void {
    this.onTranscriptCallback = callback;
  }

  getWords(): TranscriptWord[] {
    return this.allWords;
  }

  onEndpoint(callback: () => void): void {
    this.onEndpointCallback = callback;
  }

  private mergeSubwordsIntoWords(subwords: Array<{text: string, start_ms: number, end_ms: number}>): TranscriptWord[] {
    if (subwords.length === 0) return [];

    const words: TranscriptWord[] = [];

    let currentWord = '';
    let currentStartMs = subwords[0].start_ms;
    let currentEndMs = subwords[0].end_ms;

    for (let i = 0; i < subwords.length; i++) {
      const subword = subwords[i];
      const text = subword.text;

      // Skip <end> markers
      if (text.includes('<end>')) continue;

      // Check if this subword starts a new word
      // New word if: starts with space, is punctuation, or previous word ends with punctuation
      const startsNewWord = /^[\s.,!?;:]/.test(text);
      const isStandalonePunctuation = /^[.,!?;:]+$/.test(text.trim());

      if (startsNewWord && currentWord.length > 0) {
        // Save the current word (cleaned)
        const cleanWord = currentWord.trim();
        if (cleanWord.length > 0) {
          words.push({
            word: cleanWord,
            startTime: currentStartMs / 1000, // Convert to seconds - NO offset!
            endTime: currentEndMs / 1000,
          });
        }

        // Start new word
        currentWord = text.trim();
        currentStartMs = subword.start_ms;
        currentEndMs = subword.end_ms;
      } else if (isStandalonePunctuation && currentWord.length > 0) {
        // Attach punctuation to previous word
        currentWord += text.trim();
        currentEndMs = subword.end_ms;
      } else {
        // Continue building current word
        currentWord += text;
        currentEndMs = subword.end_ms;
      }
    }

    // Save the last word
    const cleanWord = currentWord.trim();
    if (cleanWord.length > 0 && !cleanWord.includes('<end>')) {
      words.push({
        word: cleanWord,
        startTime: currentStartMs / 1000,
        endTime: currentEndMs / 1000,
      });
    }

    // Log sample timestamps
    if (words.length > 0) {
      console.log(`📝 Word timestamps (no offset applied):`,
        words.slice(0, 3).map(w => `"${w.word}" [${w.startTime.toFixed(2)}s - ${w.endTime.toFixed(2)}s]`).join(', ')
      );
    }

    return words;
  }
}
