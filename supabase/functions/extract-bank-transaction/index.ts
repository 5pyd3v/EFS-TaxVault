// Edge Function: extract-bank-transaction
//
// Same shape as extract-invoice (the only place Gemini is called from —
// spec §7, §24), but for bank/wallet transaction confirmation receipts
// instead of purchase invoices:
//
//   document_id -> fetch pages from Storage -> Gemini structured extraction
//   -> duplicate check -> create bank_transaction (verification_status =
//   needs_review) -> record ai_extractions -> mark job completed
//
// No items/tax_records/supplier upsert here — a transaction receipt has
// none of those, just a flat set of fields (see bank_transaction_extraction_v1.ts).

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import {
  EXTRACTION_SCHEMA_VERSION,
  bankTransactionExtractionResponseSchema,
  type BankTransactionExtractionResult,
} from '../_shared/extraction_schema.ts';
import {
  BANK_TRANSACTION_EXTRACTION_PROMPT,
  BANK_TRANSACTION_EXTRACTION_PROMPT_VERSION,
} from '../_shared/prompts/bank_transaction_extraction_v5.ts';
import { handleGeminiKeyError, resolveGeminiApiKey } from '../_shared/gemini_key.ts';
import { callGeminiApi, startGeminiDeadline } from '../_shared/gemini_fetch.ts';

// See extract-invoice/index.ts for the benchmark this came from.
const GEMINI_MODEL = 'gemini-3.1-flash-lite';
const GEMINI_MODEL_SENDS_THINKING_CONFIG = false;
const GEMINI_FALLBACK_MODEL = 'gemini-flash-latest';
const GEMINI_FALLBACK_SENDS_THINKING_CONFIG = true;
const DOCUMENT_BUCKET = 'documents';

interface ExtractBankTransactionRequest {
  document_id: string;
  force?: boolean;
}

function sanitizeText(value: string | undefined | null, maxLength = 120): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.length > maxLength ? trimmed.slice(0, maxLength) : trimmed;
}

/** Gemini's transactionDate occasionally comes back with extra text run on
 * after the actual date/time — e.g. "2026-08-17T12:07:00Resulting JSO..."
 * — the same run-on-line failure mode that motivated the counterparty-name
 * fallback below, just landing in a different field. Plain truncation
 * (sanitizeText) doesn't fix this: a truncated garbage string still isn't
 * a valid timestamp and fails the Postgres insert outright, taking the
 * whole scan down with it. This keeps only a leading ISO 8601 date/time
 * and drops anything that doesn't parse — transaction_date is nullable,
 * and a missing date is a quick fix in Review; a failed insert isn't. */
function parseValidTransactionDate(value: string | null): string | null {
  if (!value) return null;
  const match = value.match(/^\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2})?)?/);
  if (!match) return null;
  const candidate = match[0].replace(' ', 'T');
  return Number.isNaN(Date.parse(candidate)) ? null : candidate;
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

  let body: ExtractBankTransactionRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid request body.' }, 400);
  }
  if (!body.document_id) {
    return jsonResponse({ error: 'document_id is required.' }, 400);
  }

  const { data: document, error: documentError } = await callerClient
    .from('documents')
    .select('id, organization_id, uploaded_by, storage_path, page_count, document_hash, ocr_text')
    .eq('id', body.document_id)
    .single();

  if (documentError || !document) {
    return jsonResponse({ error: 'Document not found or access denied.' }, 404);
  }

  const { data: job } = await serviceClient
    .from('ai_processing_jobs')
    .select('id, attempts')
    .eq('document_id', document.id)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  const jobId = job?.id ?? (await createJob(serviceClient, document)).id;

  await serviceClient
    .from('ai_processing_jobs')
    .update({
      status: 'processing',
      attempts: (job?.attempts ?? 0) + 1,
      started_at: new Date().toISOString(),
    })
    .eq('id', jobId);

  // Declared outside the try block so the catch handler below knows which
  // key row (this user's override, or the org default) to flag if Gemini
  // reports the credential itself as the problem.
  let keySource: 'user' | 'org' = 'org';

  try {
    const keyResult = await resolveGeminiApiKey(
      serviceClient,
      jobId,
      document.organization_id,
      document.uploaded_by,
    );
    if (keyResult instanceof Response) {
      return keyResult;
    }
    const { apiKey: geminiApiKey } = keyResult;
    keySource = keyResult.keySource;

    // Prefer the on-device OCR text: it's roughly 10x cheaper in tokens
    // than the page image and uses Gemini's much faster text path. Only
    // download and send images when OCR produced nothing usable.
    const ocrText = typeof document.ocr_text === 'string' ? document.ocr_text.trim() : '';
    const promptParts = ocrText.length >= 40
      ? []
      : await downloadPageImages(serviceClient, document.storage_path, document.page_count);
    const { data: extraction, model: modelUsed } = await callGemini(
      geminiApiKey,
      promptParts,
      ocrText.length >= 40 ? ocrText : null,
    );

    if (!extraction.isBankTransaction) {
      await failJob(serviceClient, jobId, 'The scanned image does not appear to be a transaction receipt.');
      return jsonResponse(
        { error: 'The scanned image does not appear to be a transaction receipt.' },
        422,
      );
    }

    const referenceNumber = sanitizeText(extraction.referenceNumber, 80);
    const transactionDate = parseValidTransactionDate(
      sanitizeText(extraction.transactionDate, 64),
    );
    const amount = round2(extraction.amount ?? 0);
    const counterpartyName =
      sanitizeText(extraction.counterpartyName, 200) ??
      sanitizeText(extractCounterpartyNameFallback(extraction.fullText), 200);

    // Duplicate check before creating anything, same pattern/reasoning as
    // extract-invoice (spec §16) — unless the caller already confirmed via
    // `force`.
    const duplicate = await findPossibleDuplicate(
      serviceClient,
      document.organization_id,
      document.document_hash,
      referenceNumber,
      amount,
    );
    if (duplicate && !body.force) {
      await serviceClient
        .from('ai_processing_jobs')
        .update({ status: 'completed', completed_at: new Date().toISOString() })
        .eq('id', jobId);
      return jsonResponse({
        duplicate: true,
        existing_transaction_id: duplicate.id,
        existing_reference_number: duplicate.reference_number,
        existing_amount: duplicate.amount,
      });
    }

    const { data: transaction, error: transactionError } = await serviceClient
      .from('bank_transactions')
      .insert({
        organization_id: document.organization_id,
        document_id: document.id,
        direction: extraction.direction === 'credit' ? 'credit' : 'debit',
        amount,
        currency: sanitizeText(extraction.currency, 8) ?? 'PKR',
        transaction_date: transactionDate,
        counterparty_name: counterpartyName,
        counterparty_account: sanitizeText(extraction.counterpartyAccount, 60),
        bank_name: sanitizeText(extraction.bankName, 100),
        reference_number: referenceNumber,
        status: sanitizeText(extraction.status, 60),
        ai_confidence: extraction.confidence ?? {},
        verification_status: 'needs_review',
        document_hash: document.document_hash,
        created_by: document.uploaded_by,
      })
      .select('id')
      .single();

    if (transactionError || !transaction) {
      throw new Error(transactionError?.message ?? 'Failed to create transaction.');
    }

    // Independent writes — the extraction audit row and the job status
    // don't depend on each other, so they go out together rather than
    // costing two sequential round trips on every successful scan.
    await Promise.all([
      serviceClient.from('ai_extractions').insert({
        organization_id: document.organization_id,
        job_id: jobId,
        invoice_id: null,
        model: modelUsed,
        prompt_version: BANK_TRANSACTION_EXTRACTION_PROMPT_VERSION,
        schema_version: EXTRACTION_SCHEMA_VERSION,
        raw_response: extraction,
        normalized_json: { amount, transactionDate, referenceNumber },
        confidence: extraction.confidence ?? {},
        processing_status: 'completed',
      }),
      serviceClient
        .from('ai_processing_jobs')
        .update({ status: 'completed', completed_at: new Date().toISOString() })
        .eq('id', jobId),
    ]);

    return jsonResponse({ transaction_id: transaction.id });
  } catch (error) {
    console.error('extract-bank-transaction failed', error);
    const keyErrorResponse = await handleGeminiKeyError(
      serviceClient,
      jobId,
      document.organization_id,
      document.uploaded_by,
      keySource,
      error,
    );
    if (keyErrorResponse) return keyErrorResponse;
    await failJob(serviceClient, jobId, error instanceof Error ? error.message : 'Unknown error');
    return jsonResponse({ error: 'Could not process this document. Please try again.' }, 500);
  }
});

// deno-lint-ignore no-explicit-any
async function createJob(serviceClient: any, document: { id: string; organization_id: string }) {
  const { data } = await serviceClient
    .from('ai_processing_jobs')
    .insert({ organization_id: document.organization_id, document_id: document.id, status: 'queued' })
    .select('id')
    .single();
  return data;
}

// deno-lint-ignore no-explicit-any
async function failJob(serviceClient: any, jobId: string, message: string) {
  await serviceClient
    .from('ai_processing_jobs')
    .update({ status: 'failed', error_message: message, completed_at: new Date().toISOString() })
    .eq('id', jobId);
}

async function downloadPageImages(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  storagePathPrefix: string,
  pageCount: number,
): Promise<{ mimeType: string; data: string }[]> {
  const parts: { mimeType: string; data: string }[] = [];
  for (let i = 1; i <= pageCount; i++) {
    const { data, error } = await serviceClient.storage
      .from(DOCUMENT_BUCKET)
      .download(`${storagePathPrefix}/page_${i}.jpg`);
    if (error || !data) {
      throw new Error(`Could not read page ${i} of the document.`);
    }
    const buffer = await data.arrayBuffer();
    parts.push({ mimeType: 'image/jpeg', data: base64Encode(buffer) });
  }
  return parts;
}

async function callGemini(
  apiKey: string,
  images: { mimeType: string; data: string }[],
  ocrText: string | null,
): Promise<{ data: BankTransactionExtractionResult; model: string }> {
  // One shared deadline across primary + fallback, so retrying can never
  // stack into a multi-minute wait before the user is told it failed.
  const deadline = startGeminiDeadline();
  try {
    return {
      data: await callGeminiModel(
        GEMINI_MODEL, apiKey, images, ocrText, 1, deadline,
        GEMINI_MODEL_SENDS_THINKING_CONFIG,
      ),
      model: GEMINI_MODEL,
    };
  } catch (error) {
    console.error(`Primary model ${GEMINI_MODEL} failed, trying fallback`, error);
    return {
      data: await callGeminiModel(
        GEMINI_FALLBACK_MODEL, apiKey, images, ocrText, 0, deadline,
        GEMINI_FALLBACK_SENDS_THINKING_CONFIG,
      ),
      model: GEMINI_FALLBACK_MODEL,
    };
  }
}

async function callGeminiModel(
  model: string,
  apiKey: string,
  images: { mimeType: string; data: string }[],
  ocrText: string | null,
  maxRetries: number,
  deadline: number,
  sendThinkingConfig: boolean,
): Promise<BankTransactionExtractionResult> {
  // Text path when OCR succeeded, image path otherwise. The prompt is
  // identical either way — only the evidence it reasons over changes.
  const parts = ocrText
    ? [
        {
          text:
            `${BANK_TRANSACTION_EXTRACTION_PROMPT}\n\n` +
            `The receipt text below was recognized on-device, top to bottom. ` +
            `Occasional OCR artifacts (misread characters, split lines) are ` +
            `expected — interpret them sensibly rather than treating them as ` +
            `literal.\n\nRECEIPT TEXT:\n${ocrText}`,
        },
      ]
    : [
        { text: BANK_TRANSACTION_EXTRACTION_PROMPT },
        ...images.map((img) => ({ inline_data: { mime_type: img.mimeType, data: img.data } })),
      ];

  const response = await callGeminiApi(
    model,
    apiKey,
    {
      contents: [{ parts }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: bankTransactionExtractionResponseSchema,
        temperature: 0.2,
        // A transaction receipt is a flat handful of fields plus a 2-4
        // line fullText — 4096 was far more headroom than this shape can
        // ever need, and an over-generous cap lets a degenerate response
        // run long before being cut off.
        maxOutputTokens: 1024,
      },
    },
    maxRetries,
    deadline,
    sendThinkingConfig,
  );

  if (!response.ok) {
    const text = await response.text();
    const error = new Error(`Gemini request failed (${response.status}): ${text.slice(0, 300)}`);
    (error as Error & { status?: number }).status = response.status;
    throw error;
  }

  const payload = await response.json();
  const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error('Gemini returned an empty response.');
  }

  try {
    return JSON.parse(text) as BankTransactionExtractionResult;
  } catch {
    throw new Error('Gemini response failed JSON schema validation.');
  }
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/// Deterministic safety net for when Gemini leaves counterpartyName blank
/// despite the prompt's guidance — real-world testing showed this happens
/// often enough on dense Raast P2P run-on lines to be worth a second pass.
/// Anchored on the Pakistani IBAN prefix (PK + 2 digits + 4-letter bank
/// code), which reliably immediately follows a name on these receipts and
/// essentially never appears anywhere else in the text — a narrow,
/// low-false-positive pattern rather than a general name parser.
///
/// Since v4, counterpartyName is always the sender: this tries a "from X"
/// match first (the sender, explicitly labeled) and only falls back to
/// "to X" (implying the account holder is the sender, with no explicit
/// label) if no "from" pattern is present on the receipt at all.
function extractCounterpartyNameFallback(fullText: string | undefined | null): string | null {
  if (!fullText) return null;
  const namePattern = '([A-Z][A-Za-z.&/-]*(?:\\s+[A-Z][A-Za-z.&/-]*){0,5})\\s+PK\\d{2}[A-Z]{4}';
  const match =
    fullText.match(new RegExp(`from\\s+${namePattern}`, 'i')) ??
    fullText.match(new RegExp(`to\\s+${namePattern}`, 'i'));
  if (!match) return null;
  const name = match[1].trim();
  return name.length >= 2 && name.length <= 100 ? name : null;
}

interface DuplicateMatch {
  id: string;
  reference_number: string | null;
  amount: number;
}

async function findPossibleDuplicate(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  organizationId: string,
  documentHash: string | null | undefined,
  referenceNumber: string | null | undefined,
  amount: number,
): Promise<DuplicateMatch | null> {
  if (documentHash) {
    const { data } = await serviceClient
      .from('bank_transactions')
      .select('id, reference_number, amount')
      .eq('organization_id', organizationId)
      .eq('document_hash', documentHash)
      .limit(1);
    if (data && data.length > 0) return data[0];
  }

  if (referenceNumber) {
    const { data } = await serviceClient
      .from('bank_transactions')
      .select('id, reference_number, amount')
      .eq('organization_id', organizationId)
      .eq('reference_number', referenceNumber)
      .eq('amount', amount)
      .limit(1);
    if (data && data.length > 0) return data[0];
  }

  return null;
}

function base64Encode(buffer: ArrayBuffer): string {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
