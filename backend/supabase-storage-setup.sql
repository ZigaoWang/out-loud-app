-- Create storage bucket for audio files
INSERT INTO storage.buckets (id, name, public)
VALUES ('audio-recordings', 'audio-recordings', false);

-- Enable RLS on storage
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy: Users can upload their own audio files
CREATE POLICY "Users can upload own audio"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'audio-recordings' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can read their own audio files
CREATE POLICY "Users can read own audio"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'audio-recordings' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can delete their own audio files
CREATE POLICY "Users can delete own audio"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'audio-recordings' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
