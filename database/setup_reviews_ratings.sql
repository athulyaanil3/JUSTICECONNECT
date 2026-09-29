-- Add rating columns to profiles (for lawyers)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS rating NUMERIC(3, 2) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS rating_count INTEGER DEFAULT 0;

-- Add rating columns to lawyer_offices
ALTER TABLE public.lawyer_offices 
ADD COLUMN IF NOT EXISTS rating NUMERIC(3, 2) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS rating_count INTEGER DEFAULT 0;

-- Create reviews table
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
    citizen_id UUID REFERENCES public.profiles(id),
    lawyer_id UUID REFERENCES public.profiles(id),
    office_id UUID REFERENCES public.lawyer_offices(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'reviews' AND policyname = 'Allow public access to reviews'
    ) THEN
        CREATE POLICY "Allow public access to reviews" ON public.reviews FOR ALL USING (true);
    END IF;
END $$;
