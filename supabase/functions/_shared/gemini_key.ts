// Per-organization Gemini API key lookup + error classification, shared by
// extract-invoice and extract-bank-transaction. Every org must configure
// its own key (Profile -> AI Key Settings) — there is deliberately no
// fallback to a shared secret, so a missing/exhausted key blocks that
// org's scanning until they add or replace one, rather than silently
// borrowing another org's quota.

import { corsHeaders } from './cors.ts';

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

interface KeyRow {
  gemini_api_key: string;
  is_valid: boolean;
  last_error: string | null;
}

// deno-lint-ignore no-explicit-any
async function failJob(serviceClient: any, jobId: string, message: string) {
  await serviceClient
    .from('ai_processing_jobs')
    .update({ status: 'failed', error_message: message, completed_at: new Date().toISOString() })
    .eq('id', jobId);
}

/** Looks up the calling org's Gemini key. Returns the key string to proceed
 * with, or a fully-formed Response (job already marked failed) when there
 * is no key configured or the stored key is already known to be bad from a
 * previous run — callers should `return` that Response directly. */
export async function resolveGeminiApiKey(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  jobId: string,
  organizationId: string,
): Promise<string | Response> {
  const { data: keyRow } = await serviceClient
    .from('organization_ai_keys')
    .select('gemini_api_key, is_valid, last_error')
    .eq('organization_id', organizationId)
    .maybeSingle<KeyRow>();

  if (!keyRow?.gemini_api_key) {
    await failJob(serviceClient, jobId, 'no_api_key');
    return jsonResponse(
      { error: 'no_api_key', message: 'Add your Gemini API key in Profile to start scanning.' },
      422,
    );
  }

  if (keyRow.is_valid === false) {
    const quota = keyRow.last_error === 'quota_exceeded';
    const code = quota ? 'quota_exceeded' : 'invalid_key';
    const message = quota
      ? 'Your Gemini API key has run out of quota. Update your key or wait a while and try again.'
      : 'Your Gemini API key appears to be invalid. Please update it in Profile.';
    await failJob(serviceClient, jobId, code);
    return jsonResponse({ error: code, message }, quota ? 429 : 401);
  }

  return keyRow.gemini_api_key;
}

/** Call from the outer catch block with the HTTP status attached to a
 * thrown Gemini-request error (see callGemini). If the status indicates a
 * quota or auth problem, marks the org's key invalid so the next request
 * short-circuits via resolveGeminiApiKey instead of hitting Gemini again,
 * and returns the Response to send. Returns null for anything else, so the
 * caller falls through to its normal generic-failure handling. */
export async function handleGeminiKeyError(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  jobId: string,
  organizationId: string,
  status: number | undefined,
): Promise<Response | null> {
  if (status !== 429 && status !== 400 && status !== 403) return null;

  const code = status === 429 ? 'quota_exceeded' : 'invalid_key';
  await serviceClient
    .from('organization_ai_keys')
    .update({ is_valid: false, last_error: code })
    .eq('organization_id', organizationId);
  await failJob(serviceClient, jobId, code);

  const message = code === 'quota_exceeded'
    ? 'Your Gemini API key has run out of quota. Update your key or wait a while and try again.'
    : 'Your Gemini API key appears to be invalid. Please update it in Profile.';
  return jsonResponse({ error: code, message }, code === 'quota_exceeded' ? 429 : 401);
}
