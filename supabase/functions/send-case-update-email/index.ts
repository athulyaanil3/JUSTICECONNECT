import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

// Requires RESEND_API_KEY environment variable configured in Supabase
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

serve(async (req) => {
  try {
    const payload = await req.json()
    
    // The webhook payload for an INSERT will have a `record` object containing the new row
    const updateRecord = payload.record

    if (!updateRecord || !updateRecord.case_id) {
      return new Response(JSON.stringify({ error: 'Invalid payload' }), { status: 400 })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Get the Case to find the user_id
    const { data: caseData, error: caseError } = await supabaseAdmin
      .from('cases')
      .select('user_id, title, case_number')
      .eq('id', updateRecord.case_id)
      .single()

    if (caseError || !caseData) {
      return new Response(JSON.stringify({ error: 'Case not found' }), { status: 404 })
    }

    // 2. Get the User's Email securely via Auth Admin
    const { data: userData, error: userError } = await supabaseAdmin.auth.admin.getUserById(caseData.user_id)
    
    if (userError || !userData?.user) {
      return new Response(JSON.stringify({ error: 'User not found' }), { status: 404 })
    }

    const userEmail = userData.user.email

    if (!userEmail) {
      return new Response(JSON.stringify({ error: 'User does not have an email' }), { status: 400 })
    }

    // 3. Send the Email via Resend
    if (!RESEND_API_KEY) {
      console.warn("RESEND_API_KEY is not set. Simulating email send:", { to: userEmail, update: updateRecord })
      return new Response(JSON.stringify({ success: true, simulated: true }), { status: 200 })
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: 'JusticeConnect Updates <onboarding@resend.dev>', // Replace with your verified domain
        to: [userEmail],
        subject: `Case Update: ${caseData.title} (${caseData.case_number || 'New'})`,
        html: `
          <h2>New Update for your case: ${caseData.title}</h2>
          <p><strong>Update Type:</strong> ${updateRecord.update_type}</p>
          <p><strong>Description:</strong> ${updateRecord.description}</p>
          <br/>
          <p>Please log in to the JusticeConnect app to view more details and encrypted evidence.</p>
        `
      })
    })

    const resData = await res.json()
    if (res.ok) {
      return new Response(JSON.stringify({ success: true, data: resData }), { status: 200 })
    } else {
      return new Response(JSON.stringify({ error: resData }), { status: 500 })
    }

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
