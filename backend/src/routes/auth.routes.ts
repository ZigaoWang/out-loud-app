import { Router } from 'express';
import { z } from 'zod';
import rateLimit from 'express-rate-limit';
import { SupabaseService } from '../services/supabase.service';

const router = Router();
const supabase = new SupabaseService();

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { error: 'Too many attempts, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

const authSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(8).max(128),
});

router.post('/signup', authLimiter, async (req, res) => {
  try {
    const { email, password } = authSchema.parse(req.body);
    const data = await supabase.signUp(email, password);
    res.json(data);
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid input' });
    }
    res.status(400).json({ error: 'Signup failed' });
  }
});

router.post('/login', authLimiter, async (req, res) => {
  try {
    const { email, password } = authSchema.parse(req.body);
    const data = await supabase.signIn(email, password);
    res.json(data);
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid input' });
    }
    res.status(401).json({ error: 'Authentication failed' });
  }
});

export default router;
