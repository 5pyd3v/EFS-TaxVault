// Edge Function: delete-platform-user
//
// Platform-admin only. Permanently deletes a user account that has NO
// organization — i.e. one of the "incomplete signups" surfaced by
// list_incomplete_signups (0036_list_incomplete_signups.sql): someone who
// created an account but never finished onboarding. Safe by construction:
// refuses to run if the target has any organization_members row at all,
// so this can never be used to delete a real customer's account out from
// under their data — that's delete-organization's job, and it
// deliberately does NOT delete the person's account, only the org.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

interface DeletePlatformUserRequest {
  user_id: string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header.' }, 401);
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  let body: DeletePlatformUserRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid request body.' }, 400);
  }
  if (!body.user_id) {
    return jsonResponse({ error: 'user_id is required.' }, 400);
  }

  const { data: isAdmin, error: adminCheckErr } = await callerClient.rpc('is_platform_admin');
  if (adminCheckErr || !isAdmin) {
    return jsonResponse({ error: 'Only a platform admin can delete a user.' }, 403);
  }

  const { count, error: membershipErr } = await serviceClient
    .from('organization_members')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', body.user_id);
  if (membershipErr) {
    console.error('delete-platform-user: membership check failed', membershipErr);
    return jsonResponse({ error: 'Could not verify this account. Please try again.' }, 500);
  }
  if (count && count > 0) {
    return jsonResponse(
      { error: 'This account belongs to an organization — delete the organization instead.' },
      422,
    );
  }

  const { error: deleteErr } = await serviceClient.auth.admin.deleteUser(body.user_id);
  if (deleteErr) {
    console.error('delete-platform-user: deleteUser failed', deleteErr);
    return jsonResponse({ error: 'Could not delete this account. Please try again.' }, 500);
  }

  return jsonResponse({ deleted: true });
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
