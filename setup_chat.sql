-- Create consultation_requests table
CREATE TABLE IF NOT EXISTS public.consultation_requests (
    id UUID PRIMARY KEY,
    citizen_name TEXT NOT NULL,
    lawyer_name TEXT NOT NULL,
    issue_description TEXT NOT NULL,
    status TEXT NOT NULL,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES public.consultation_requests(id) ON DELETE CASCADE,
    sender TEXT NOT NULL,
    text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.consultation_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Allow public access (for development/mini-project)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'consultation_requests' AND policyname = 'Allow public access to consultation_requests') THEN
        CREATE POLICY "Allow public access to consultation_requests" ON public.consultation_requests FOR ALL USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'chat_messages' AND policyname = 'Allow public access to chat_messages') THEN
        CREATE POLICY "Allow public access to chat_messages" ON public.chat_messages FOR ALL USING (true);
    END IF;
END $$;

-- Enable Realtime for chat messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
