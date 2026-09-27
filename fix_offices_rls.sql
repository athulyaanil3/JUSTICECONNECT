-- Allow public access to read, insert, update, and delete offices
-- We'll allow this for now so the Admin dashboard can manage offices easily

DROP POLICY IF EXISTS "Allow public access to lawyer_offices" ON public.lawyer_offices;

CREATE POLICY "Allow public access to lawyer_offices"
ON public.lawyer_offices
FOR ALL
USING (true);

-- Ensure RLS is enabled but unrestricted for testing
ALTER TABLE public.lawyer_offices ENABLE ROW LEVEL SECURITY;
