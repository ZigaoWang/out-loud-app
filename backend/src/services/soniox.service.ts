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
  private onErrorCallback: ((error: string) => void) | null = null;
  private finalTranscript: string = '';
  private allWords: TranscriptWord[] = [];
  private isConnected: boolean = false;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 3;
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private lastMessageTime: number = Date.now();

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        this.finalTranscript = '';
        this.allWords = [];
        this.isConnected = false;

        // Validate API key
        if (!config.soniox.apiKey || config.soniox.apiKey.trim() === '') {
          const error = 'Missing or invalid Soniox API key';
          console.error('❌', error);
          this.notifyError(error);
          return reject(new Error(error));
        }

        // Validate WebSocket URL
        if (!config.soniox.wsUrl || !config.soniox.wsUrl.startsWith('wss://')) {
          const error = 'Invalid Soniox WebSocket URL';
          console.error('❌', error);
          this.notifyError(error);
          return reject(new Error(error));
        }

        console.log('🔌 Connecting to Soniox WebSocket...');
        this.ws = new WebSocket(config.soniox.wsUrl, {
          handshakeTimeout: 10000, // 10 second timeout
        });

        const connectionTimeout = setTimeout(() => {
          if (!this.isConnected) {
            console.error('❌ Soniox connection timeout');
            this.ws?.terminate();
            this.notifyError('Connection timeout');
            reject(new Error('Connection timeout'));
          }
        }, 15000);

        this.ws.on('open', () => {
          clearTimeout(connectionTimeout);
          this.isConnected = true;
          console.log('✅ Connected to Soniox WebSocket');

          try {
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
            this.startHeartbeat();
            resolve();
          } catch (error) {
            console.error('❌ Failed to send config:', error);
            this.notifyError('Failed to configure Soniox');
            reject(error);
          }
        });

        this.ws.on('message', (data: WebSocket.Data) => {
          this.lastMessageTime = Date.now();

          try {
            const message = JSON.parse(data.toString());

            // Check for error from Soniox
            if (message.error_code) {
              const errorMsg = `Soniox error: ${message.error_code} - ${message.error_message}`;
              console.error('❌', errorMsg);
              this.notifyError(errorMsg);
              return;
            }

            // Parse tokens
            if (message.tokens && Array.isArray(message.tokens) && message.tokens.length > 0) {
              this.processTokens(message.tokens);
            }

            // Check for finished
            if (message.finished) {
              console.log('✅ Soniox session finished');
            }
          } catch (error) {
            console.error('❌ Error parsing Soniox message:', error);
            console.error('Raw message:', data.toString().substring(0, 200));
            this.notifyError('Failed to parse transcription response');
          }
        });

        this.ws.on('error', (error) => {
          console.error('❌ Soniox WebSocket error:', error);
          this.notifyError(`WebSocket error: ${error.message}`);

          if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            console.log(`🔄 Reconnect attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);
            setTimeout(() => this.connect().catch(console.error), 2000);
          } else {
            reject(error);
          }
        });

        this.ws.on('close', (code, reason) => {
          this.isConnected = false;
          this.stopHeartbeat();
          console.log(`🔌 Soniox WebSocket closed - Code: ${code}, Reason: ${reason || 'none'}`);

          if (code !== 1000 && code !== 1001) {
            // Abnormal closure
            console.error('⚠️ Abnormal WebSocket closure');
            this.notifyError('Connection closed unexpectedly');
          }
        });

      } catch (error) {
        console.error('❌ Failed to create WebSocket connection:', error);
        this.notifyError('Failed to establish connection');
        reject(error);
      }
    });
  }

  private processTokens(tokens: any[]): void {
    try {
      let finalTokens = '';
      let nonFinalTokens = '';
      const finalSubwords: Array<{text: string, start_ms: number, end_ms: number}> = [];

      // Separate final and non-final tokens
      for (const token of tokens) {
        if (!token.text || typeof token.text !== 'string') {
          continue;
        }

        if (token.is_final) {
          finalTokens += token.text;

          // Collect subwords with valid timestamps
          if (typeof token.start_ms === 'number' &&
              typeof token.end_ms === 'number' &&
              token.start_ms >= 0 &&
              token.end_ms >= token.start_ms) {
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

      // Merge subwords into full words
      const finalWords = this.mergeSubwordsIntoWords(finalSubwords);

      // Handle final tokens
      if (finalTokens && this.onTranscriptCallback) {
        this.finalTranscript += finalTokens;
        this.allWords.push(...finalWords);
        this.onTranscriptCallback(this.finalTranscript, true, this.allWords);
      }

      // Handle non-final tokens
      if (nonFinalTokens && this.onTranscriptCallback) {
        const previewText = this.finalTranscript + nonFinalTokens;
        this.onTranscriptCallback(previewText, false);
      }
    } catch (error) {
      console.error('❌ Error processing tokens:', error);
      this.notifyError('Failed to process transcription tokens');
    }
  }

  sendAudio(audioData: Buffer): void {
    try {
      if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
        console.error('❌ Cannot send audio: WebSocket not open');
        this.notifyError('Connection not ready');
        return;
      }

      if (!audioData || audioData.length === 0) {
        console.warn('⚠️ Attempted to send empty audio buffer');
        return;
      }

      this.ws.send(audioData);
    } catch (error) {
      console.error('❌ Failed to send audio:', error);
      this.notifyError('Failed to send audio data');
    }
  }

  stopTranscription(): void {
    try {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        // Send empty audio to signal end
        this.ws.send(Buffer.alloc(0));
        console.log('📤 Sent end-of-audio signal');
      }
    } catch (error) {
      console.error('❌ Error stopping transcription:', error);
    }
  }

  disconnect(): void {
    try {
      this.stopHeartbeat();

      if (this.ws) {
        if (this.ws.readyState === WebSocket.OPEN) {
          this.ws.close(1000, 'Normal closure');
        } else {
          this.ws.terminate();
        }
        this.ws = null;
      }

      this.isConnected = false;
      this.reconnectAttempts = 0;
      console.log('✅ Soniox disconnected');
    } catch (error) {
      console.error('❌ Error during disconnect:', error);
    }
  }

  onTranscript(callback: (text: string, isFinal: boolean, words?: TranscriptWord[]) => void): void {
    if (typeof callback !== 'function') {
      throw new Error('Invalid callback: must be a function');
    }
    this.onTranscriptCallback = callback;
  }

  onError(callback: (error: string) => void): void {
    if (typeof callback !== 'function') {
      throw new Error('Invalid callback: must be a function');
    }
    this.onErrorCallback = callback;
  }

  getWords(): TranscriptWord[] {
    return [...this.allWords]; // Return copy to prevent mutation
  }

  onEndpoint(callback: () => void): void {
    if (typeof callback !== 'function') {
      throw new Error('Invalid callback: must be a function');
    }
    this.onEndpointCallback = callback;
  }

  isConnectionAlive(): boolean {
    return this.isConnected && this.ws?.readyState === WebSocket.OPEN;
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();

    this.heartbeatInterval = setInterval(() => {
      const timeSinceLastMessage = Date.now() - this.lastMessageTime;

      if (timeSinceLastMessage > 30000) { // 30 seconds of silence
        console.warn('⚠️ No messages from Soniox for 30 seconds');

        if (!this.isConnectionAlive()) {
          console.error('❌ Connection appears dead, attempting reconnect');
          this.disconnect();
          this.connect().catch(error => {
            console.error('❌ Reconnection failed:', error);
            this.notifyError('Lost connection to transcription service');
          });
        }
      }
    }, 10000); // Check every 10 seconds
  }

  private stopHeartbeat(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  private notifyError(error: string): void {
    if (this.onErrorCallback) {
      this.onErrorCallback(error);
    }
  }

  private mergeSubwordsIntoWords(subwords: Array<{text: string, start_ms: number, end_ms: number}>): TranscriptWord[] {
    if (!Array.isArray(subwords) || subwords.length === 0) {
      return [];
    }

    const words: TranscriptWord[] = [];

    try {
      let currentWord = '';
      let currentStartMs = subwords[0].start_ms;
      let currentEndMs = subwords[0].end_ms;

      for (let i = 0; i < subwords.length; i++) {
        const subword = subwords[i];

        if (!subword || typeof subword.text !== 'string') {
          continue;
        }

        const text = subword.text;

        // Skip <end> markers
        if (text.includes('<end>')) continue;

        // Check if this subword starts a new word
        const startsNewWord = /^[\s.,!?;:]/.test(text);
        const isStandalonePunctuation = /^[.,!?;:]+$/.test(text.trim());

        if (startsNewWord && currentWord.length > 0) {
          // Save the current word
          const cleanWord = currentWord.trim();
          if (cleanWord.length > 0 && currentStartMs >= 0 && currentEndMs >= currentStartMs) {
            words.push({
              word: cleanWord,
              startTime: currentStartMs / 1000,
              endTime: currentEndMs / 1000,
            });
          }

          currentWord = text.trim();
          currentStartMs = subword.start_ms;
          currentEndMs = subword.end_ms;
        } else if (isStandalonePunctuation && currentWord.length > 0) {
          currentWord += text.trim();
          currentEndMs = subword.end_ms;
        } else {
          currentWord += text;
          currentEndMs = subword.end_ms;
        }
      }

      // Save the last word
      const cleanWord = currentWord.trim();
      if (cleanWord.length > 0 && !cleanWord.includes('<end>') &&
          currentStartMs >= 0 && currentEndMs >= currentStartMs) {
        words.push({
          word: cleanWord,
          startTime: currentStartMs / 1000,
          endTime: currentEndMs / 1000,
        });
      }

      if (words.length > 0) {
        console.log(`📝 Merged ${subwords.length} subwords into ${words.length} words:`,
          words.slice(0, 3).map(w => `"${w.word}" [${w.startTime.toFixed(2)}s-${w.endTime.toFixed(2)}s]`).join(', ')
        );
      }
    } catch (error) {
      console.error('❌ Error merging subwords into words:', error);
      this.notifyError('Failed to process word timestamps');
    }

    return words;
  }
}
