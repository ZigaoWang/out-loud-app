import WebSocket from 'ws';
import { config } from '../../config';
import logger from '../utils/logger';

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

        if (!config.soniox.apiKey || config.soniox.apiKey.trim() === '') {
          const error = 'Missing or invalid Soniox API key';
          logger.error('soniox_invalid_api_key');
          this.notifyError(error);
          return reject(new Error(error));
        }

        if (!config.soniox.wsUrl || !config.soniox.wsUrl.startsWith('wss://')) {
          const error = 'Invalid Soniox WebSocket URL';
          logger.error('soniox_invalid_url', { url: config.soniox.wsUrl });
          this.notifyError(error);
          return reject(new Error(error));
        }

        logger.info('soniox_connecting');
        this.ws = new WebSocket(config.soniox.wsUrl, {
          handshakeTimeout: 10000, // 10 second timeout
        });

        const connectionTimeout = setTimeout(() => {
          if (!this.isConnected) {
            logger.error('soniox_connection_timeout');
            this.ws?.terminate();
            this.notifyError('Connection timeout');
            reject(new Error('Connection timeout'));
          }
        }, 15000);

        this.ws.on('open', () => {
          clearTimeout(connectionTimeout);
          this.isConnected = true;
          logger.info('soniox_connected');

          try {
            // Send configuration
            const sonioxConfig: SonioxConfig = {
              api_key: config.soniox.apiKey,
              model: config.soniox.model,
              language_hints: ['zh', 'en'],
              enable_endpoint_detection: true,
              audio_format: 'pcm_s16le',
              sample_rate: 16000,
              num_channels: 1,
            };

            this.ws?.send(JSON.stringify(sonioxConfig));
            this.startHeartbeat();
            resolve();
          } catch (error) {
            logger.error('soniox_config_failed', { error: error instanceof Error ? error.message : 'Unknown error' });
            this.notifyError('Failed to configure Soniox');
            reject(error);
          }
        });

        this.ws.on('message', (data: WebSocket.Data) => {
          this.lastMessageTime = Date.now();

          try {
            const message = JSON.parse(data.toString());

            if (message.error_code) {
              logger.error('soniox_error', { code: message.error_code, message: message.error_message });
              this.notifyError(`Soniox error: ${message.error_code} - ${message.error_message}`);
              return;
            }

            if (message.tokens && Array.isArray(message.tokens) && message.tokens.length > 0) {
              this.processTokens(message.tokens);
            }

            if (message.finished) {
              logger.info('soniox_session_finished');
            }
          } catch (error) {
            logger.error('soniox_parse_error', { error: error instanceof Error ? error.message : 'Unknown error', rawMessage: data.toString().substring(0, 200) });
            this.notifyError('Failed to parse transcription response');
          }
        });

        this.ws.on('error', (error) => {
          logger.error('soniox_websocket_error', { error: error.message, reconnectAttempts: this.reconnectAttempts });
          this.notifyError(`WebSocket error: ${error.message}`);

          if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            logger.info('soniox_reconnecting', { attempt: this.reconnectAttempts, max: this.maxReconnectAttempts });
            setTimeout(() => this.connect().catch(err => logger.error('soniox_reconnect_failed', { error: err.message })), 2000);
          } else {
            reject(error);
          }
        });

        this.ws.on('close', (code, reason) => {
          this.isConnected = false;
          this.stopHeartbeat();
          logger.info('soniox_closed', { code, reason: reason || 'none' });

          if (code !== 1000 && code !== 1001) {
            logger.warn('soniox_abnormal_closure', { code });
            this.notifyError('Connection closed unexpectedly');
          }
        });

      } catch (error) {
        logger.error('soniox_connection_failed', { error: error instanceof Error ? error.message : 'Unknown error' });
        this.notifyError('Failed to establish connection');
        reject(error);
      }
    });
  }

  private processTokens(tokens: any[]): void {
    try {
      let finalText = '';
      let nonFinalText = '';
      const finalTokens: Array<{text: string, start_ms: number, end_ms: number}> = [];

      for (const token of tokens) {
        if (!token.text || typeof token.text !== 'string') continue;

        if (token.is_final) {
          finalText += token.text;
          if (typeof token.start_ms === 'number' && typeof token.end_ms === 'number') {
            finalTokens.push({
              text: token.text,
              start_ms: token.start_ms,
              end_ms: token.end_ms,
            });
          }
        } else {
          nonFinalText += token.text;
        }
      }

      const finalWords = this.mergeSubwordsIntoWords(finalTokens);

      if (finalText && this.onTranscriptCallback) {
        this.finalTranscript += finalText;
        this.allWords.push(...finalWords);
        this.onTranscriptCallback(this.finalTranscript, true, this.allWords);
      }

      if (nonFinalText && this.onTranscriptCallback) {
        this.onTranscriptCallback(this.finalTranscript + nonFinalText, false);
      }
    } catch (error) {
      logger.error('soniox_token_processing_error', { error: error instanceof Error ? error.message : 'Unknown error' });
      this.notifyError('Failed to process transcription tokens');
    }
  }

  sendAudio(audioData: Buffer): void {
    try {
      if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
        logger.warn('soniox_audio_send_failed', { reason: 'WebSocket not open' });
        this.notifyError('Connection not ready');
        return;
      }

      if (!audioData || audioData.length === 0) {
        logger.warn('soniox_empty_audio_buffer');
        return;
      }

      this.ws.send(audioData);
    } catch (error) {
      logger.error('soniox_audio_send_error', { error: error instanceof Error ? error.message : 'Unknown error' });
      this.notifyError('Failed to send audio data');
    }
  }

  stopTranscription(): void {
    try {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(Buffer.alloc(0));
        logger.info('soniox_end_signal_sent');
      }
    } catch (error) {
      logger.error('soniox_stop_error', { error: error instanceof Error ? error.message : 'Unknown error' });
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
      logger.info('soniox_disconnected');
    } catch (error) {
      logger.error('soniox_disconnect_error', { error: error instanceof Error ? error.message : 'Unknown error' });
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

      if (timeSinceLastMessage > 30000) {
        logger.warn('soniox_no_messages', { timeSinceLastMessage });

        if (!this.isConnectionAlive()) {
          logger.error('soniox_connection_dead');
          this.disconnect();
          this.connect().catch(error => {
            logger.error('soniox_reconnect_failed', { error: error instanceof Error ? error.message : 'Unknown error' });
            this.notifyError('Lost connection to transcription service');
          });
        }
      }
    }, 10000);
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

  private mergeSubwordsIntoWords(tokens: Array<{text: string, start_ms: number, end_ms: number}>): TranscriptWord[] {
    if (!tokens.length) return [];

    const words: TranscriptWord[] = [];
    let word = '';
    let startMs = -1;
    let endMs = -1;

    for (const token of tokens) {
      const text = token.text.replace(/<end>/gi, '').replace(/<\/end>/gi, '');
      if (!text) continue;

      if (/^\s/.test(text)) {
        // Space at start = new word boundary
        if (word) {
          words.push({ word, startTime: startMs / 1000, endTime: endMs / 1000 });
        }
        word = text.trim();
        startMs = token.start_ms;
        endMs = token.end_ms;
      } else {
        // Continue current word
        if (startMs < 0) startMs = token.start_ms;
        word += text;
        endMs = token.end_ms;
      }
    }

    if (word) {
      words.push({ word, startTime: startMs / 1000, endTime: endMs / 1000 });
    }

    logger.debug('soniox_words_merged', { subwords: tokens.length, words: words.length });
    return words;
  }
}
