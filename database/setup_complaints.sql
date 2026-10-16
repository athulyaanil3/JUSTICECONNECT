-- SQL Script to create the complaints table in Supabase
CREATE TABLE IF NOT EXISTS public.complaints (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID,
    user_name TEXT,
    user_email TEXT,
    user_role TEXT, -- 'Citizen', 'Lawyer', 'Advocate Clerk'
    category TEXT,  -- 'App / Technical Issue', 'Account / Verification', 'Advocate Conduct', 'Harassment', 'Dispute', 'Other'
    priority TEXT DEFAULT 'Medium', -- 'Low', 'Medium', 'High', 'Urgent'
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT DEFAULT 'Pending', -- 'Pending', 'In Progress', 'Resolved'
    admin_response TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

-- Drop existing restrictive policies if any
DROP POLICY IF EXISTS "Allow public access to complaints" ON public.complaints;
DROP POLICY IF EXISTS "Allow authenticated users to insert complaints" ON public.complaints;
DROP POLICY IF EXISTS "Allow users to read complaints" ON public.complaints;
DROP POLICY IF EXISTS "Allow update on complaints" ON public.complaints;

-- Allow public access for Citizen/Lawyer submission and Admin review/updates
CREATE POLICY "Allow public access to complaints" ON public.complaints
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Enable Realtime for complaints table
ALTER PUBLICATION supabase_realtime ADD TABLE public.complaints;
