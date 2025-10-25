import { Router } from 'express';
import { SupabaseService } from '../services/supabase.service';

const router = Router();
const supabase = new SupabaseService();

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
    const data = await supabase.saveSession(req.user.id, req.body);
    res.json(data);
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

router.get('/', authMiddleware, async (req: any, res) => {
  try {
    const data = await supabase.getSessions(req.user.id);
    res.json(data);
  } catch (error: any) {
    res.status(400).json({ error: error.message });
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
    res.status(400).json({ error: error.message });
  }
});

export default router;
