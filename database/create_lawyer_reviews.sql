CREATE TABLE IF NOT EXISTS public.lawyer_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
    citizen_id UUID REFERENCES public.profiles(id),
    lawyer_id UUID REFERENCES public.profiles(id),
    office_id UUID REFERENCES public.lawyer_offices(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.lawyer_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public access to lawyer_reviews" ON public.lawyer_reviews;
CREATE POLICY "Allow public access to lawyer_reviews" ON public.lawyer_reviews FOR ALL USING (true);
