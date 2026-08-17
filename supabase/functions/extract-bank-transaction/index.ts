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
} from '../_shared/prompts/bank_transaction_extraction_v3.ts';
import { handleGeminiKeyError, resolveGeminiApiKey } from '../_shared/gemini_key.ts';

const GEMINI_MODEL = 'gemini-flash-latest';
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
    .select('id, organization_id, uploaded_by, storage_path, page_count, document_hash')
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

  try {
    const geminiApiKey = await resolveGeminiApiKey(serviceClient, jobId, document.organization_id);
    if (geminiApiKey instanceof Response) {
      return geminiApiKey;
    }

    const imageParts = await downloadPageImages(serviceClient, document.storage_path, document.page_count);
    const extraction = await callGemini(geminiApiKey, imageParts);

    if (!extraction.isBankTransaction) {
      await failJob(serviceClient, jobId, 'The scanned image does not appear to be a transaction receipt.');
      return jsonResponse(
        { error: 'The scanned image does not appear to be a transaction receipt.' },
        422,
      );
    }

    const referenceNumber = sanitizeText(extraction.referenceNumber, 80);
    const transactionDate = sanitizeText(extraction.transactionDate, 32);
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

    await serviceClient.from('ai_extractions').insert({
      organization_id: document.organization_id,
      job_id: jobId,
      invoice_id: null,
      model: GEMINI_MODEL,
      prompt_version: BANK_TRANSACTION_EXTRACTION_PROMPT_VERSION,
      schema_version: EXTRACTION_SCHEMA_VERSION,
      raw_response: extraction,
      normalized_json: { amount, transactionDate, referenceNumber },
      confidence: extraction.confidence ?? {},
      processing_status: 'completed',
    });

    await serviceClient
      .from('ai_processing_jobs')
      .update({ status: 'completed', completed_at: new Date().toISOString() })
      .eq('id', jobId);

    return jsonResponse({ transaction_id: transaction.id });
  } catch (error) {
    console.error('extract-bank-transaction failed', error);
    const status = (error as { status?: number } | null)?.status;
    const keyErrorResponse = await handleGeminiKeyError(serviceClient, jobId, document.organization_id, status);
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
): Promise<BankTransactionExtractionResult> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: BANK_TRANSACTION_EXTRACTION_PROMPT },
              ...images.map((img) => ({ inline_data: { mime_type: img.mimeType, data: img.data } })),
            ],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: bankTransactionExtractionResponseSchema,
          temperature: 0.2,
          maxOutputTokens: 4096,
        },
      }),
    },
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
/// code), which reliably immediately follows the counterparty's name on
/// these receipts and essentially never appears anywhere else in the
/// text — a narrow, low-false-positive pattern rather than a general
/// name parser.
function extractCounterpartyNameFallback(fullText: string | undefined | null): string | null {
  if (!fullText) return null;
  const match = fullText.match(
    /(?:to|from)\s+([A-Z][A-Za-z.&/-]*(?:\s+[A-Z][A-Za-z.&/-]*){0,5})\s+PK\d{2}[A-Z]{4}/,
  );
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
