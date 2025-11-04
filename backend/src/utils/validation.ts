import { z } from 'zod';

// Session ID validation
export const sessionIdSchema = z.string()
  .min(1, 'Session ID is required')
  .max(255, 'Session ID too long')
  .regex(/^[a-zA-Z0-9-_]+$/, 'Session ID contains invalid characters');

// Audio data validation
export const audioDataSchema = z.instanceof(Buffer)
  .refine((data) => data.length > 0, 'Audio data cannot be empty')
  .refine((data) => data.length <= 1024 * 1024, 'Audio chunk too large (max 1MB)');

// Transcript validation
export const transcriptSchema = z.string()
  .max(50000, 'Transcript too long');

// User ID validation
export const userIdSchema = z.string()
  .uuid('Invalid user ID format');

export function validateSessionId(sessionId: unknown): string {
  return sessionIdSchema.parse(sessionId);
}

export function validateAudioData(data: unknown): Buffer {
  return audioDataSchema.parse(data);
}

export function validateTranscript(transcript: unknown): string {
  return transcriptSchema.parse(transcript);
}

export function validateUserId(userId: unknown): string {
  return userIdSchema.parse(userId);
}
