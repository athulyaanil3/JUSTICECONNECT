-- Setup hearings table in Supabase
CREATE TABLE IF NOT EXISTS public.hearings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
    hearing_date TIMESTAMP WITH TIME ZONE NOT NULL,
    hearing_time TEXT DEFAULT '',
    courtroom TEXT DEFAULT '',
    hearing_type TEXT DEFAULT 'Regular Hearing',
    status TEXT NOT NULL DEFAULT 'Scheduled',
    remarks TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Row Level Security
ALTER TABLE public.hearings ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'hearings' AND policyname = 'Allow public access to hearings'
    ) THEN
        CREATE POLICY "Allow public access to hearings" ON public.hearings FOR ALL USING (true);
    END IF;
END $$;
