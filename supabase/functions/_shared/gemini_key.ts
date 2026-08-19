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

/** Gemini's own wording when the credential itself is the problem. Matched
 * against the response body rather than inferred from the status code:
 * HTTP 400 from this API overwhelmingly means "bad request" (an
 * unsupported generationConfig field, an oversized image, a malformed
 * schema) — all of which are OUR bugs, not the user's key. Blaming the key
 * for those is actively harmful: it disables a perfectly good key, and
 * since re-saving the key clears the flag only for the next request to
 * trip it again, the user gets stuck in a loop that replacing the key
 * cannot fix. Only mark a key bad on evidence, never on a bare status. */
const KEY_PROBLEM_PATTERN =
  /API_KEY_INVALID|API key not valid|API key expired|PERMISSION_DENIED|CONSUMER_INVALID|invalid authentication|unregistered callers/i;

/** Call from the outer catch block with the error thrown by callGemini
 * (which carries both the HTTP status and a snippet of the response body).
 * Marks the org's key invalid ONLY when the response actually identifies
 * the credential as the problem, so the next request can short-circuit
 * instead of hitting Gemini again. Returns null for everything else — the
 * caller then falls through to its normal generic-failure handling, which
 * preserves the underlying error message for diagnosis. */
export async function handleGeminiKeyError(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  jobId: string,
  organizationId: string,
  error: unknown,
): Promise<Response | null> {
  const status = (error as { status?: number } | null)?.status;
  const body = error instanceof Error ? error.message : String(error ?? '');

  const isQuota = status === 429;
  const isKeyProblem =
    (status === 400 || status === 403) && KEY_PROBLEM_PATTERN.test(body);

  if (!isQuota && !isKeyProblem) return null;

  const code = isQuota ? 'quota_exceeded' : 'invalid_key';
  await serviceClient
    .from('organization_ai_keys')
    .update({ is_valid: false, last_error: code })
    .eq('organization_id', organizationId);
  await failJob(serviceClient, jobId, code);

  const message = isQuota
    ? 'Your Gemini API key has run out of quota. Update your key or wait a while and try again.'
    : 'Your Gemini API key appears to be invalid. Please update it in Profile.';
  return jsonResponse({ error: code, message }, isQuota ? 429 : 401);
}
