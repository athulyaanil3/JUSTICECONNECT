-- 1. Get the first lawyer and first citizen (for dummy data purposes)
DO $$
DECLARE
    v_lawyer_id UUID;
    v_citizen_id UUID;
    v_clerk_id UUID;
    v_case_id UUID;
BEGIN
    -- Get a lawyer (if one exists)
    SELECT id INTO v_lawyer_id FROM public.profiles WHERE role = 'Lawyer' LIMIT 1;
    
    -- Get an advocate clerk (if one exists)
    SELECT id INTO v_clerk_id FROM public.profiles WHERE role = 'Advocate Clerk' LIMIT 1;
    
    -- Get a citizen (if one exists)
    SELECT id INTO v_citizen_id FROM public.profiles WHERE role = 'Citizen' LIMIT 1;

    -- Insert a dummy case
    INSERT INTO public.cases (
        title, 
        category, 
        description, 
        status, 
        user_id, 
        lawyer_id, 
        advocate_clerk_id, 
        case_number, 
        petitioner, 
        respondent, 
        court_name, 
        next_hearing_date, 
        purpose
    ) VALUES (
        'Property Dispute vs ABC Corp',
        'Civil',
        'A dispute regarding the boundaries of the property located in South Block.',
        'Active',
        v_citizen_id,
        v_lawyer_id,
        v_clerk_id,
        'CIV/2026/00142',
        'John Doe (Petitioner)',
        'ABC Corporation (Respondent)',
        'District Court, Trivandrum',
        timezone('utc'::text, now() + interval '5 days'),
        'Initial Hearing'
    ) RETURNING id INTO v_case_id;

    -- Insert a dummy case update (timeline event)
    INSERT INTO public.case_updates (
        case_id,
        update_type,
        description,
        created_by
    ) VALUES (
        v_case_id,
        'Hearing Scheduled',
        'The initial hearing has been scheduled at the District Court. Please be present at 10:00 AM.',
        v_clerk_id
    );

END $$;
