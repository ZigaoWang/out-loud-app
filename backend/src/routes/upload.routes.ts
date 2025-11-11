import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { supabase } from '../services/supabase.service';

const router = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }
});

const MIME_TYPE_EXTENSIONS: Record<string, string> = {
  'audio/mp4': 'm4a',
  'audio/m4a': 'm4a',
  'audio/x-m4a': 'm4a',
  'audio/mpeg': 'mp3',
  'audio/wav': 'wav',
};

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

    const allowedMimeTypes = Object.keys(MIME_TYPE_EXTENSIONS);
    if (!allowedMimeTypes.includes(req.file.mimetype)) {
      return res.status(400).json({ error: 'Invalid file type' });
    }

    const { sessionId } = uploadBodySchema.parse(req.body);
    const extension = MIME_TYPE_EXTENSIONS[req.file.mimetype];
    const path = `${user.id}/${sessionId || Date.now().toString()}.${extension}`;

    const { error: uploadError } = await supabase.storage
      .from('audio-recordings')
      .upload(path, req.file.buffer, {
        contentType: req.file.mimetype,
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
