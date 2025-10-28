import { Router } from 'express';
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

const authMiddleware = async (req: any, res: any, next: any) => {
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

router.post('/', authMiddleware, async (req: any, res) => {
  try {
    const sessionData = sessionSchema.parse(req.body);
    const data = await supabase.saveSession(req.user.id, sessionData);
    res.json(data);
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid session data' });
    }
    res.status(400).json({ error: 'Failed to save session' });
  }
});

router.get('/', authMiddleware, async (req: any, res) => {
  try {
    const data = await supabase.getSessions(req.user.id);
    res.json(data);
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch sessions' });
  }
});

router.get('/:id', authMiddleware, async (req: any, res) => {
  try {
    const data = await supabase.getSession(req.user.id, req.params.id);
    res.json(data);
  } catch (error: any) {
    res.status(404).json({ error: 'Session not found' });
  }
});

router.delete('/:id', authMiddleware, async (req: any, res) => {
  try {
    await supabase.deleteSession(req.user.id, req.params.id);
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to delete session' });
  }
});

export default router;
