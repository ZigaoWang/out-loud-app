import { Router } from 'express';
import multer from 'multer';
import { supabase } from '../services/supabase.service';

const router = Router();

// File size limit: 50MB
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }
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

    // Validate file type
    const allowedMimeTypes = ['audio/mp4', 'audio/m4a', 'audio/mpeg', 'audio/wav', 'audio/x-m4a'];
    if (!allowedMimeTypes.includes(req.file.mimetype)) {
      return res.status(400).json({ error: 'Invalid file type' });
    }

    const sessionId = req.body.sessionId || Date.now().toString();
    const path = `${user.id}/${sessionId}.m4a`;

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
    console.error('Upload failed:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
