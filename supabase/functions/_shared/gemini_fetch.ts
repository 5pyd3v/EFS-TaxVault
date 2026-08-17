// Gemini's flash-latest alias intermittently returns 503 ("This model is
// currently experiencing high demand") and occasionally a transient 429
// under load — both usually clear within a couple of seconds. Without a
// retry, a single blip fails the whole scan and makes the user tap Retry
// manually for something that would have succeeded moments later.

const RETRYABLE_STATUSES = new Set([429, 503]);
const MAX_RETRIES = 2;
const BASE_DELAY_MS = 1000;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function fetchGeminiWithRetry(url: string, init: RequestInit): Promise<Response> {
  let response: Response;
  for (let attempt = 0; ; attempt++) {
    response = await fetch(url, init);
    if (response.ok || !RETRYABLE_STATUSES.has(response.status) || attempt >= MAX_RETRIES) {
      return response;
    }
    await sleep(BASE_DELAY_MS * 2 ** attempt);
  }
}
