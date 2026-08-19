// Shared Gemini caller: bounded timeouts, selective retry, and "thinking"
// disabled. Every design choice here is driven by observed job-history
// data on this project (49 jobs: 35% failed with 503 overloaded, 16% with
// 429 quota exceeded, only 24% succeeded).
//
// Why retries are NOT applied to 429:
//   429 means the key is out of quota. Retrying 800ms later cannot succeed
//   — the quota window hasn't reset — and each attempt counts against the
//   very limit that's already exhausted. Retrying 429 actively makes the
//   next scan more likely to fail too. Only 503 (transient server
//   overload, genuinely worth a second try) is retried.
//
// Why "thinking" is disabled:
//   Gemini 2.5+/3.x flash models run an internal reasoning pass by default.
//   Those thinking tokens are billed and counted against per-minute token
//   limits, and they dominate the request cost for a task like this — which
//   is pure structured extraction, not reasoning. Disabling it cuts token
//   usage and latency substantially, and it also removes the failure mode
//   where reasoning text leaked into a JSON field value (observed on
//   gemini-3.6-flash: a date field returned as
//   "2026-08-17T13:00:00Format ISO 8601 string, but let's follow...").
//   Because the parameter name differs across model generations
//   (thinkingBudget on 2.5, thinkingLevel on 3.x) and `-latest` aliases
//   move between them, an unsupported-parameter 400 is detected and
//   retried once without the field rather than assumed away.

const BASE_DELAY_MS = 1200;
// Per-attempt cap. Generous relative to reality — measured successful
// extractions average 6-8s and have never exceeded ~20s — so this only
// catches genuinely stuck calls, not slow-but-working ones.
const REQUEST_TIMEOUT_MS = 60_000;
// Wall-clock budget for the ENTIRE call chain (primary attempts +
// fallback model), not per attempt. Without this, per-attempt timeouts
// stack: 2 primary attempts + 1 fallback at 60s each is ~3 minutes of the
// user staring at "Analyzing" before being told it failed. Since failures
// vastly outnumber slow-successes here, bounding total time matters more
// than squeezing out a last retry — a fast, honest failure beats a slow
// one that was never going to succeed. Retries/fallback still run in
// full when they're quick, which is the common case.
const TOTAL_BUDGET_MS = 90_000;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function postJson(
  model: string,
  apiKey: string,
  body: unknown,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
        body: JSON.stringify(body),
        signal: controller.signal,
      },
    );
  } catch (error) {
    // Our own timeout, or a raw network failure — both mean "no usable
    // response", which the caller should treat like a 503: retryable, not
    // a hard failure.
    const wrapped = new Error(
      error instanceof Error && error.name === 'AbortError'
        ? `Gemini request timed out after ${timeoutMs}ms`
        : `Gemini request failed: ${error instanceof Error ? error.message : String(error)}`,
    );
    (wrapped as Error & { status?: number }).status = 503;
    throw wrapped;
  } finally {
    clearTimeout(timeout);
  }
}

function withThinkingDisabled(body: Record<string, unknown>): Record<string, unknown> {
  const generationConfig = {
    ...(body.generationConfig as Record<string, unknown>),
    thinkingConfig: { thinkingBudget: 0 },
  };
  return { ...body, generationConfig };
}

/** Starts a shared wall-clock budget for one scan's entire Gemini usage.
 * Pass the returned deadline to every callGeminiApi call in that scan
 * (primary and fallback) so their time costs are pooled rather than
 * additive. */
export function startGeminiDeadline(): number {
  return Date.now() + TOTAL_BUDGET_MS;
}

/** Calls Gemini once per attempt, retrying only transient 503s.
 * [maxRetries] counts retries on top of the first attempt (0 = single
 * shot). Each attempt is capped at REQUEST_TIMEOUT_MS or whatever remains
 * of [deadline], whichever is smaller — so the caller's total wait stays
 * bounded no matter how the attempts play out. */
export async function callGeminiApi(
  model: string,
  apiKey: string,
  body: Record<string, unknown>,
  maxRetries: number,
  deadline: number,
  sendThinkingConfig = true,
): Promise<Response> {
  let useThinkingConfig = sendThinkingConfig;

  for (let attempt = 0; ; attempt++) {
    const remaining = deadline - Date.now();
    if (remaining <= 0) {
      const expired = new Error('Gemini time budget exhausted');
      (expired as Error & { status?: number }).status = 503;
      throw expired;
    }

    const response = await postJson(
      model,
      apiKey,
      useThinkingConfig ? withThinkingDisabled(body) : body,
      Math.min(REQUEST_TIMEOUT_MS, remaining),
    );

    // Some model generations reject `thinkingBudget` outright. Retry once
    // without it on ANY 400 while it's enabled — deliberately not
    // pattern-matching the error text: thinkingConfig is only an
    // optimization, so dropping it and retrying is always cheaper than
    // guessing wrong about why the request was rejected and failing the
    // scan outright.
    if (response.status === 400 && useThinkingConfig) {
      console.warn(`${model} returned 400 with thinkingConfig; retrying without it`);
      useThinkingConfig = false;
      continue;
    }

    if (response.ok || response.status !== 503 || attempt >= maxRetries) {
      return response;
    }
    await sleep(BASE_DELAY_MS * 2 ** attempt);
  }
}
