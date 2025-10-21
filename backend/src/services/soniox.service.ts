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

export class SonioxService {
  private ws: WebSocket | null = null;
  private onTranscriptCallback: ((text: string, isFinal: boolean) => void) | null = null;
  private onEndpointCallback: (() => void) | null = null;
  private lastSentPartialText: string = ''; // Track last partial to avoid duplicates
  private lastSentFinalText: string = ''; // Track last final to avoid duplicates

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
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
            let transcript = '';
            let hasAnyFinal = false;

            for (const token of message.tokens) {
              if (token.text) {
                transcript += token.text;
                if (token.is_final) {
                  hasAnyFinal = true;
                }
              }
            }

            // Only send new text that hasn't been sent before
            if (transcript && this.onTranscriptCallback) {
              if (hasAnyFinal) {
                // For final transcripts, check if different from last final
                if (transcript !== this.lastSentFinalText) {
                  this.lastSentFinalText = transcript;
                  this.lastSentPartialText = ''; // Reset partial tracking
                  this.onTranscriptCallback(transcript, true);
                }
              } else {
                // For partial transcripts, only send if different from last partial
                if (transcript !== this.lastSentPartialText) {
                  this.lastSentPartialText = transcript;
                  this.onTranscriptCallback(transcript, false);
                }
              }
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

  onTranscript(callback: (text: string, isFinal: boolean) => void): void {
    this.onTranscriptCallback = callback;
  }

  onEndpoint(callback: () => void): void {
    this.onEndpointCallback = callback;
  }
}
