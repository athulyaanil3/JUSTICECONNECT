-- Add official case tracking fields to the cases table
-- These fields map to the eCourts/DCMS styled Causelist feature

ALTER TABLE public.cases 
ADD COLUMN IF NOT EXISTS petitioner TEXT,
ADD COLUMN IF NOT EXISTS respondent TEXT,
ADD COLUMN IF NOT EXISTS court_name TEXT,
ADD COLUMN IF NOT EXISTS next_hearing_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS purpose TEXT;

-- Verify the new schema works with existing rows (it will just be NULL for older cases)
