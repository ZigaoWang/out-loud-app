import { Router } from 'express';
import { SupabaseService } from '../services/supabase.service';

const router = Router();
const supabase = new SupabaseService();

router.post('/signup', async (req, res) => {
  try {
    const { email, password } = req.body;
    const data = await supabase.signUp(email, password);
    res.json(data);
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const data = await supabase.signIn(email, password);
    res.json(data);
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

export default router;
