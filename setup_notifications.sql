-- Create app_notifications table
CREATE TABLE IF NOT EXISTS public.app_notifications (
    id TEXT PRIMARY KEY,
    target_user TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    action_payload TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;

-- Allow public access (for development/mini-project)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'app_notifications' AND policyname = 'Allow public access to app_notifications') THEN
        CREATE POLICY "Allow public access to app_notifications" ON public.app_notifications FOR ALL USING (true);
    END IF;
END $$;

-- Enable Realtime for notifications so the red dots appear instantly
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_notifications;
