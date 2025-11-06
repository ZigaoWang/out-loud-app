import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { SupabaseService } from '../services/supabase.service';

const router = Router();
const supabase = new SupabaseService();

const sessionSchema = z.object({
  id: z.string().max(255),
  transcript: z.string().max(50000),
  transcriptSegments: z.array(z.object({
    word: z.string(),
    startTime: z.number(),
    endTime: z.number(),
  })).optional(),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  duration: z.number().min(0).max(86400),
  analysis: z.any().optional(),
  title: z.string().max(500).optional(),
});

interface AuthRequest extends Request {
  user?: { id: string };
}

const authMiddleware = async (req: AuthRequest, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Unauthorized' });

  try {
    const { data, error } = await supabase.verifyToken(token);
    if (error) throw error;
    req.user = data.user;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

router.post('/', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const sessionData = sessionSchema.parse(req.body);
    const data = await supabase.saveSession(req.user!.id, sessionData);
    res.json(data);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid session data' });
    }
    res.status(400).json({ error: 'Failed to save session' });
  }
});

router.get('/', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const data = await supabase.getSessions(req.user!.id);
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch sessions' });
  }
});

router.get('/:id', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const { id } = z.object({ id: z.string().max(255).regex(/^[a-zA-Z0-9-_]+$/) }).parse(req.params);
    const data = await supabase.getSession(req.user!.id, id);
    res.json(data);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid session ID' });
    }
    res.status(404).json({ error: 'Session not found' });
  }
});

router.delete('/:id', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const { id } = z.object({ id: z.string().max(255).regex(/^[a-zA-Z0-9-_]+$/) }).parse(req.params);
    await supabase.deleteSession(req.user!.id, id);
    res.json({ success: true });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid session ID' });
    }
    res.status(500).json({ error: 'Failed to delete session' });
  }
});

export default router;
