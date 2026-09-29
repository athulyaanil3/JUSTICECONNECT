import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

// The Edge Function "get-case-evidence-access"
// Verifies authorization and returns the wrapped key and nonce for the specific case document.

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401, headers: corsHeaders })
    }

    const { case_id, document_id } = await req.json()
    if (!case_id || !document_id) {
      return new Response(JSON.stringify({ error: 'Missing case_id or document_id' }), { status: 400, headers: corsHeaders })
    }

    // Create a Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    // Get the user from the JWT explicitly
    const token = authHeader.replace('Bearer ', '').trim()
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token)
    
    if (userError || !user) {
      console.error('Auth Error:', userError?.message)
      return new Response(JSON.stringify({ error: 'Unauthorized', details: userError?.message }), { status: 401, headers: corsHeaders })
    }
    const userId = user.id

    // Use Service Role to query the database, but ONLY AFTER we verify authorization manually
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Verify User Role
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', userId)
      .single()
      
    const role = profile?.role ?? 'Citizen'

    // 2. Verify Case or Consultation Assignment
    const { data: caseData, error: caseError } = await supabaseAdmin
      .from('cases')
      .select('user_id, lawyer_id, advocate_clerk_id')
      .eq('id', case_id)
      .maybeSingle()

    let isAuthorized = false;

    if (caseData) {
      isAuthorized = 
        caseData.lawyer_id === userId ||
        caseData.advocate_clerk_id === userId ||
        caseData.user_id === userId ||
        role === 'Admin';
    } else {
      // Fallback: check consultation_requests which uses citizen_name and lawyer_name
      // 1. Get the username of the requester
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle()
        
      if (profile && profile.username) {
        const { data: requestData } = await supabaseAdmin
          .from('consultation_requests')
          .select('citizen_name, lawyer_name')
          .eq('id', case_id)
          .maybeSingle()

        if (requestData) {
          isAuthorized = 
            requestData.citizen_name === profile.username ||
            requestData.lawyer_name === profile.username ||
            role === 'Admin';
        }
      }
    }

    if (!isAuthorized) {
      // Log failed access attempt
      await supabaseAdmin.from('audit_logs').insert({
        user_id: userId,
        case_id: case_id,
        document_id: document_id,
        action: 'ACCESS_DENIED'
      })
      return new Response(JSON.stringify({ error: 'Access Denied: You are not authorized for this case or consultation.' }), { status: 403, headers: corsHeaders })
    }

    // 3. Retrieve Key Material
    const { data: document, error: docError } = await supabaseAdmin
      .from('case_documents')
      .select('encrypted_key, nonce')
      .eq('id', document_id)
      .eq('case_id', case_id)
      .single()

    if (docError || !document) {
      return new Response(JSON.stringify({ error: 'Document metadata not found' }), { status: 404, headers: corsHeaders })
    }

    // Log successful access
    await supabaseAdmin.from('audit_logs').insert({
      user_id: userId,
      case_id: case_id,
      document_id: document_id,
      action: 'VIEW_AUTHORIZED'
    })

    // Note: In a true production system, `encrypted_key` should be wrapped by a Master Key (KMS). 
    // The Edge Function would decrypt the wrapped key using the Master Key, and return the plaintext AES key to the client over TLS.
    // Here we return the key directly since the database column `encrypted_key` holds the AES key exclusively.

    return new Response(
      JSON.stringify({
        key: document.encrypted_key,
        nonce: document.nonce
      }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders })
  }
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
