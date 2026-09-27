-- Create lawyer_offices table
CREATE TABLE IF NOT EXISTS public.lawyer_offices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    location TEXT NOT NULL,
    address TEXT NOT NULL,
    image_url TEXT NOT NULL,
    contact_number TEXT NOT NULL,
    rating NUMERIC(3, 1) DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create office_lawyers table
CREATE TABLE IF NOT EXISTS public.office_lawyers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    office_id UUID REFERENCES public.lawyer_offices(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    image_url TEXT NOT NULL,
    rating NUMERIC(3, 1) DEFAULT 0.0,
    reviews_count INTEGER DEFAULT 0,
    focusing_cases TEXT[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Set up Row Level Security (RLS)
ALTER TABLE public.lawyer_offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.office_lawyers ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Allow public read access to lawyer_offices" 
    ON public.lawyer_offices FOR SELECT 
    USING (true);

CREATE POLICY "Allow public read access to office_lawyers" 
    ON public.office_lawyers FOR SELECT 
    USING (true);

-- Insert Mock Data

-- Insert Kerala Justice Associates
WITH office1 AS (
    INSERT INTO public.lawyer_offices (name, location, address, image_url, contact_number, rating)
    VALUES (
        'Kerala Justice Associates',
        'Ernakulam, Kerala',
        'High Court Road, Marine Drive, Ernakulam 682031',
        'https://images.unsplash.com/photo-1577983637206-8d1e2e92c6cc?auto=format&fit=crop&w=400&q=80',
        '+91 98765 43210',
        4.8
    ) RETURNING id
)
INSERT INTO public.office_lawyers (office_id, name, image_url, rating, reviews_count, focusing_cases)
SELECT id, 'Adv. Suresh Kumar', 'https://i.pravatar.cc/150?u=suresh', 4.9, 142, ARRAY['Corporate Law', 'Property Disputes'] FROM office1
UNION ALL
SELECT id, 'Adv. Anjali Menon', 'https://i.pravatar.cc/150?u=anjali', 4.7, 89, ARRAY['Family Law', 'Divorce'] FROM office1;


-- Insert Trivandrum Legal Partners
WITH office2 AS (
    INSERT INTO public.lawyer_offices (name, location, address, image_url, contact_number, rating)
    VALUES (
        'Trivandrum Legal Partners',
        'Thiruvananthapuram, Kerala',
        'Vanchiyoor Court Complex, Thiruvananthapuram 695035',
        'https://images.unsplash.com/photo-1593115057322-e94bfa3fa696?auto=format&fit=crop&w=400&q=80',
        '+91 91234 56789',
        4.9
    ) RETURNING id
)
INSERT INTO public.office_lawyers (office_id, name, image_url, rating, reviews_count, focusing_cases)
SELECT id, 'Adv. Ramesh Nair', 'https://i.pravatar.cc/150?u=ramesh', 4.8, 210, ARRAY['Criminal Defense', 'Bail Matters'] FROM office2
UNION ALL
SELECT id, 'Adv. Priya Varghese', 'https://i.pravatar.cc/150?u=priya', 4.9, 175, ARRAY['Civil Rights', 'Employment Law'] FROM office2
UNION ALL
SELECT id, 'Adv. Thomas George', 'https://i.pravatar.cc/150?u=thomas', 4.6, 54, ARRAY['Personal Injury', 'Motor Accidents'] FROM office2;

-- Insert Malabar Law Chambers
WITH office3 AS (
    INSERT INTO public.lawyer_offices (name, location, address, image_url, contact_number, rating)
    VALUES (
        'Malabar Law Chambers',
        'Kozhikode, Kerala',
        'Mavoor Road, Near District Court, Kozhikode 673004',
        'https://images.unsplash.com/photo-1507679799987-c73779587ccf?auto=format&fit=crop&w=400&q=80',
        '+91 99887 76655',
        4.7
    ) RETURNING id
)
INSERT INTO public.office_lawyers (office_id, name, image_url, rating, reviews_count, focusing_cases)
SELECT id, 'Adv. Mohammed Ali', 'https://i.pravatar.cc/150?u=mohammed', 4.7, 112, ARRAY['Cyber Law', 'Commercial Disputes'] FROM office3;
