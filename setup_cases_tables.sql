-- Create cases table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.cases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Submitted',
    user_id UUID,
    lawyer_id UUID,
    advocate_clerk_id UUID,
    case_number TEXT DEFAULT '',
    petitioner TEXT,
    respondent TEXT,
    court_name TEXT,
    next_hearing_date TIMESTAMP WITH TIME ZONE,
    purpose TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create case_updates table for the timeline
CREATE TABLE IF NOT EXISTS public.case_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
    update_type TEXT NOT NULL,
    description TEXT NOT NULL,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Set up Row Level Security (RLS)
ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_updates ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access (for the mini-project)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'cases' AND policyname = 'Allow public access to cases'
    ) THEN
        CREATE POLICY "Allow public access to cases" ON public.cases FOR ALL USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'case_updates' AND policyname = 'Allow public access to case_updates'
    ) THEN
        CREATE POLICY "Allow public access to case_updates" ON public.case_updates FOR ALL USING (true);
    END IF;
END $$;
