import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { supabase } from '../services/supabase.service';

const router = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }
});

const uploadBodySchema = z.object({
  sessionId: z.string().max(255).regex(/^[a-zA-Z0-9-_]+$/).optional(),
});

router.post('/audio', upload.single('audio'), async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      return res.status(401).json({ error: 'No authorization header' });
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const allowedMimeTypes = ['audio/mp4', 'audio/m4a', 'audio/mpeg', 'audio/wav', 'audio/x-m4a'];
    if (!allowedMimeTypes.includes(req.file.mimetype)) {
      return res.status(400).json({ error: 'Invalid file type' });
    }

    const { sessionId } = uploadBodySchema.parse(req.body);
    const path = `${user.id}/${sessionId || Date.now().toString()}.m4a`;

    const { error: uploadError } = await supabase.storage
      .from('audio-recordings')
      .upload(path, req.file.buffer, {
        contentType: 'audio/mp4',
        upsert: false
      });

    if (uploadError) {
      console.error('Upload error:', uploadError);
      return res.status(500).json({ error: uploadError.message });
    }

    res.json({ path });
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid session ID format' });
    }
    console.error('Upload failed:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
