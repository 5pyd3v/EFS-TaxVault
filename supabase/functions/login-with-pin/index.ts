// Edge Function: login-with-pin
//
// Public — called with no user session (supabase_flutter's
// functions.invoke attaches the anon key as the Authorization header when
// signed out, which is all this function needs; no --no-verify-jwt flag
// required at deploy time). Authenticates purely via phone + PIN against
// attempt_pin_login (0025_team_pin_credentials.sql), which owns all
// lockout/attempt-counting logic atomically. On success, signs in
// server-side using the stored internal_email/auth_secret (never the PIN
// itself — see that migration's header comment for why) and hands the
// resulting session back to the client to install via
// supabase.auth.setSession(refreshToken).

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { normalizePhone } from '../_shared/phone.ts';

interface LoginWithPinRequest {
  phone?: string;
  pin?: string;
}

interface AttemptPinLoginRow {
  outcome: 'ok' | 'invalid' | 'locked' | 'disabled';
  out_user_id: string | null;
  out_internal_email: string | null;
  out_auth_secret: string | null;
  retry_after_seconds: number | null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

  let body: LoginWithPinRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'invalid_request', message: 'Invalid request.' }, 400);
  }

  const phone = normalizePhone(body.phone ?? '');
  const pin = (body.pin ?? '').trim();
  if (phone.length < 8 || !/^\d{4,8}$/.test(pin)) {
    return jsonResponse({ error: 'invalid_request', message: 'Enter your phone number and PIN.' }, 400);
  }

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  const { data, error } = await serviceClient
    .rpc('attempt_pin_login', { p_phone: phone, p_pin: pin })
    .single<AttemptPinLoginRow>();

  if (error || !data) {
    console.error('login-with-pin: attempt_pin_login failed', error);
    return jsonResponse({ error: 'server_error', message: 'Could not sign in right now. Please try again.' }, 500);
  }

  if (data.outcome === 'locked') {
    const seconds = data.retry_after_seconds ?? 900;
    const minutes = Math.max(1, Math.ceil(seconds / 60));
    return jsonResponse(
      {
        error: 'locked',
        message: `Too many attempts. Try again in ${minutes} minute${minutes === 1 ? '' : 's'}.`,
        retry_after_seconds: seconds,
      },
      429,
    );
  }
  if (data.outcome === 'disabled') {
    return jsonResponse({ error: 'account_disabled', message: 'This account has been disabled. Contact your admin.' }, 403);
  }
  if (data.outcome !== 'ok' || !data.out_internal_email || !data.out_auth_secret) {
    return jsonResponse({ error: 'invalid_credentials', message: 'Incorrect phone number or PIN.' }, 401);
  }

  const authClient = createClient(supabaseUrl, anonKey);
  const { data: signIn, error: signInError } = await authClient.auth.signInWithPassword({
    email: data.out_internal_email,
    password: data.out_auth_secret,
  });
  if (signInError || !signIn.session) {
    console.error('login-with-pin: internal sign-in failed', signInError);
    return jsonResponse({ error: 'server_error', message: 'Could not sign in right now. Please try again.' }, 500);
  }

  return jsonResponse({
    access_token: signIn.session.access_token,
    refresh_token: signIn.session.refresh_token,
    expires_in: signIn.session.expires_in,
  });
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
