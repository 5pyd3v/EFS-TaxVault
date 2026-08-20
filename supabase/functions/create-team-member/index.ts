// Edge Function: create-team-member
//
// Lets a business org's owner/admin add a staff account by name + phone
// only — no email/password signup for team members. Generates a one-time
// PIN the admin shares with the new member; the member later logs in via
// login-with-pin.
//
// The PIN is never the literal Supabase Auth password (see
// 0025_team_pin_credentials.sql for why) — this function also generates a
// long random `auth_secret` that only ever lives server-side, and hands
// login-with-pin everything it needs to turn a correct PIN into a real
// session.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { normalizePhone } from '../_shared/phone.ts';
import { base64UrlEncode } from '../_shared/random.ts';

interface CreateTeamMemberRequest {
  organization_id: string;
  full_name: string;
  phone: string;
  role: 'accountant' | 'member';
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

  // RLS-scoped: only used to confirm the caller's own membership/role and
  // the target org's type — exactly the same trust boundary as every other
  // function in this app (see extract-invoice's callerClient comment).
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  let body: CreateTeamMemberRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid request body.' }, 400);
  }
  if (!body.organization_id || !body.full_name?.trim() || !body.phone?.trim()) {
    return jsonResponse({ error: 'organization_id, full_name and phone are required.' }, 400);
  }
  if (body.role !== 'accountant' && body.role !== 'member') {
    return jsonResponse({ error: 'role must be "accountant" or "member".' }, 422);
  }

  const { data: { user: caller } } = await callerClient.auth.getUser();
  if (!caller) {
    return jsonResponse({ error: 'Invalid session.' }, 401);
  }

  const { data: membership } = await callerClient
    .from('organization_members')
    .select('role')
    .eq('organization_id', body.organization_id)
    .eq('user_id', caller.id)
    .maybeSingle();
  if (!membership || !['owner', 'admin'].includes(membership.role)) {
    return jsonResponse({ error: 'Only an organization owner or admin can add team members.' }, 403);
  }

  const { data: org } = await callerClient
    .from('organizations')
    .select('type')
    .eq('id', body.organization_id)
    .maybeSingle();
  if (org?.type !== 'business') {
    return jsonResponse({ error: 'Team members can only be added to a business organization.' }, 422);
  }

  const phone = normalizePhone(body.phone);
  if (phone.length < 8) {
    return jsonResponse({ error: 'Enter a valid phone number.' }, 400);
  }

  const { data: existing } = await serviceClient
    .from('member_pin_credentials')
    .select('user_id')
    .eq('phone', phone)
    .maybeSingle();
  if (existing) {
    return jsonResponse({ error: 'This phone number is already registered to a team member.' }, 409);
  }

  const internalEmail = `member+${crypto.randomUUID()}@members.internal.efstaxvault.app`;
  const authSecret = base64UrlEncode(crypto.getRandomValues(new Uint8Array(32)));
  const pin = String(Math.floor(Math.random() * 1_000_000)).padStart(6, '0');
  const fullName = body.full_name.trim();

  const { data: created, error: createErr } = await serviceClient.auth.admin.createUser({
    email: internalEmail,
    password: authSecret,
    email_confirm: true,
    user_metadata: { full_name: fullName, is_pin_managed: true },
  });
  if (createErr || !created?.user) {
    console.error('create-team-member: createUser failed', createErr);
    return jsonResponse({ error: 'Could not create team member account. Please try again.' }, 500);
  }

  try {
    const { data: pinHash, error: hashErr } = await serviceClient.rpc('hash_pin', { p_pin: pin });
    if (hashErr || !pinHash) throw new Error(hashErr?.message ?? 'hash_pin failed');

    const { error: finalizeErr } = await serviceClient.rpc('finalize_team_member', {
      p_user_id: created.user.id,
      p_organization_id: body.organization_id,
      p_role: body.role,
      p_phone: phone,
      p_internal_email: internalEmail,
      p_pin_hash: pinHash,
      p_auth_secret: authSecret,
      p_created_by: caller.id,
    });
    if (finalizeErr) throw new Error(finalizeErr.message);
  } catch (err) {
    // Compensating action: never leave an orphaned auth user with no
    // organization_members/member_pin_credentials row behind.
    console.error('create-team-member: finalize failed, rolling back auth user', err);
    await serviceClient.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: 'Could not create team member account. Please try again.' }, 500);
  }

  return jsonResponse(
    { user_id: created.user.id, full_name: fullName, phone, role: body.role, pin },
    201,
  );
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
