// Edge Function: create-sandbox-account
//
// Platform-admin only. Creates a clean, working individual-org account for
// a prospective customer to test the app before buying — a completely
// normal email/password account (no PIN, no special restrictions on
// functionality) so the prospect experiences the real product. The
// `is_sandbox` flag on its organization exists purely to keep it visually
// distinct from paying customers on the superadmin dashboard; it does not
// gate any feature.
//
// Same dual-client / credential-generation / compensating-rollback shape
// as create-team-member — see that function's header comment for the
// underlying reasoning (there, generating a PIN + internal auth_secret;
// here, generating a real email + human-typeable password directly).

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { randomPassword } from '../_shared/random.ts';

interface CreateSandboxAccountRequest {
  full_name: string;
  organization_name: string;
  email?: string;
  gemini_api_key?: string;
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

  // RLS-scoped: only used to confirm the caller is a platform admin —
  // same trust boundary as every other function in this app.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  let body: CreateSandboxAccountRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid request body.' }, 400);
  }
  if (!body.full_name?.trim() || !body.organization_name?.trim()) {
    return jsonResponse({ error: 'full_name and organization_name are required.' }, 400);
  }

  const { data: { user: caller } } = await callerClient.auth.getUser();
  if (!caller) {
    return jsonResponse({ error: 'Invalid session.' }, 401);
  }

  const { data: isAdmin, error: adminCheckErr } = await callerClient.rpc('is_platform_admin');
  if (adminCheckErr || !isAdmin) {
    return jsonResponse({ error: 'Only a platform admin can create a sandbox account.' }, 403);
  }

  const fullName = body.full_name.trim();
  const organizationName = body.organization_name.trim();
  const email = body.email?.trim() || `sandbox+${crypto.randomUUID()}@trial.efstaxvault.app`;
  const password = randomPassword(12);

  const { data: created, error: createErr } = await serviceClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (createErr || !created?.user) {
    console.error('create-sandbox-account: createUser failed', createErr);
    return jsonResponse({ error: 'Could not create sandbox account. Please try again.' }, 500);
  }

  let organizationId: string;
  try {
    const { data, error: finalizeErr } = await serviceClient.rpc('finalize_sandbox_account', {
      p_user_id: created.user.id,
      p_organization_name: organizationName,
      p_created_by: caller.id,
    });
    if (finalizeErr || !data) throw new Error(finalizeErr?.message ?? 'finalize_sandbox_account failed');
    organizationId = data as string;
  } catch (err) {
    // Compensating action: never leave an orphaned auth user with no
    // organization behind.
    console.error('create-sandbox-account: finalize failed, rolling back auth user', err);
    await serviceClient.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: 'Could not create sandbox account. Please try again.' }, 500);
  }

  // Optional: pre-configure the sandbox's own Gemini key, same table/shape
  // as the normal org-key flow (organization_ai_keys, set via
  // set_gemini_api_key when a real owner does it from Profile). The
  // platform admin isn't a member of this brand-new org, so that RPC's
  // has_org_role check would reject them — this writes the row directly
  // via the service-role client instead, which is safe here specifically
  // because the platform-admin check above already gated the whole
  // request. Best-effort: a failure here doesn't undo account creation —
  // the prospect can still add their own key from Profile like any
  // individual account.
  if (body.gemini_api_key?.trim()) {
    const { error: keyErr } = await serviceClient.from('organization_ai_keys').insert({
      organization_id: organizationId,
      gemini_api_key: body.gemini_api_key.trim(),
      updated_by: caller.id,
    });
    if (keyErr) {
      console.error('create-sandbox-account: setting gemini key failed, continuing', keyErr);
    }
  }

  return jsonResponse(
    { user_id: created.user.id, organization_id: organizationId, email, password },
    201,
  );
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
