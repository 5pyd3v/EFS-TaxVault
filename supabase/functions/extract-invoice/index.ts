// Edge Function: extract-invoice
//
// This is the ONLY place Gemini is called from (spec §7, §24 — the API key
// never enters the Flutter app). Flow:
//
//   document_id -> fetch pages from Storage -> Gemini structured extraction
//   -> deterministic calculation check -> duplicate check -> create
//   invoice + items (verification_status = needs_review) -> record
//   ai_extractions / ai_warnings -> mark job completed
//
// Gemini reads the invoice; it never has the final word on arithmetic
// (spec §8) — subtotal/tax/total consistency is recomputed here, not
// trusted from the model's output.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import {
  EXTRACTION_SCHEMA_VERSION,
  invoiceExtractionResponseSchema,
  type InvoiceExtractionResult,
} from '../_shared/extraction_schema.ts';
import {
  INVOICE_EXTRACTION_PROMPT,
  INVOICE_EXTRACTION_PROMPT_VERSION,
} from '../_shared/prompts/invoice_extraction_v2.ts';
import { handleGeminiKeyError, resolveGeminiApiKey } from '../_shared/gemini_key.ts';
import { callGeminiApi, startGeminiDeadline } from '../_shared/gemini_fetch.ts';

// Chosen by benchmarking this project's actual key against every flash /
// lite model it can reach, using a real OCR-text extraction request
// (2026-08-18). Latency for identical input varied enormously, and the
// self-updating aliases were among the WORST:
//   gemini-3.1-flash-lite     1.1-1.7s   correct        <- chosen
//   gemini-3.5-flash-lite    19.3s       correct
//   gemini-flash-lite-latest 23.2s       correct
//   gemini-flash-latest      27.6s       correct
//   gemini-3.7-flash         503 overloaded
//   gemini-2.5-flash(-lite)  404 retired for this key
// The lite tier is the right fit now that extraction reads OCR text
// rather than an image: there's no vision work left to justify a heavier
// model, and it returned identical field values ~19x faster.
const GEMINI_MODEL = 'gemini-3.1-flash-lite';
// The 3.x lite models reject `thinkingConfig.thinkingBudget` outright
// (HTTP 400) and already report thoughtsTokenCount=0 without it, so
// sending it would only buy a wasted round trip. Older models DO honour
// it and benefit from it, hence the per-model flag rather than one global
// setting. callGeminiApi still strips it on any 400 as a safety net.
const GEMINI_MODEL_SENDS_THINKING_CONFIG = false;
// Slower but independent of the primary — worth one shot when the primary
// is overloaded or retired.
const GEMINI_FALLBACK_MODEL = 'gemini-flash-latest';
const GEMINI_FALLBACK_SENDS_THINKING_CONFIG = true;
const CALCULATION_TOLERANCE = 1.0; // PKR — rounding slack before flagging a mismatch
const DOCUMENT_BUCKET = 'documents';

interface ExtractInvoiceRequest {
  document_id: string;
  /** Set when the user explicitly chose "Save anyway" after being shown a
   * possible-duplicate prompt — bypasses the duplicate gate below. */
  force?: boolean;
}

/** Gemini occasionally degenerates into a repetition loop on a single
 * field (a known LLM failure mode) — cap anything that reaches a text
 * column so a runaway string can't land in the database. */
function sanitizeText(value: string | undefined | null, maxLength = 120): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.length > maxLength ? trimmed.slice(0, maxLength) : trimmed;
}

/** Same defensive parsing as extract-bank-transaction's
 * parseValidTransactionDate — Gemini occasionally runs stray text onto a
 * date field, and invoice_date is a `date` column that rejects anything
 * that isn't cleanly YYYY-MM-DD. Truncating to 10 chars already discards
 * most trailing garbage, but this also rejects a garbled leading portion
 * instead of passing it through and failing the insert. */
function parseValidInvoiceDate(value: string | null): string | null {
  if (!value) return null;
  const match = value.match(/^\d{4}-\d{2}-\d{2}/);
  return match && !Number.isNaN(Date.parse(match[0])) ? match[0] : null;
}

interface Warning {
  code: string;
  severity: 'info' | 'warning' | 'error';
  message: string;
  field_path: string | null;
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

  // RLS-scoped client: only used to confirm the caller can actually see
  // this document (i.e. is a member of its organization). If they can't,
  // this query returns nothing and we stop here — no separate
  // authorization logic to keep in sync with the RLS policies.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  // Privileged client for everything after that: Storage download and all
  // writes to ai_processing_jobs / ai_extractions / ai_warnings / invoices,
  // none of which the client role can write directly (see
  // supabase/migrations/0008_rls_policies.sql).
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  let body: ExtractInvoiceRequest;
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
    .select('id, organization_id, uploaded_by, storage_path, page_count, document_type, document_hash, ocr_text')
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

    // Prefer the on-device OCR text: roughly 10x cheaper in tokens than the
    // page image and served by Gemini's much faster text path. Only
    // download and send images when OCR produced nothing usable.
    const ocrText = typeof document.ocr_text === 'string' ? document.ocr_text.trim() : '';
    const useOcr = ocrText.length >= 40;
    const imageParts = useOcr
      ? []
      : await downloadPageImages(serviceClient, document.storage_path, document.page_count);
    const { data: extraction, model: modelUsed } = await callGemini(
      geminiApiKey,
      imageParts,
      useOcr ? ocrText : null,
    );

    if (!extraction.isInvoice) {
      await failJob(serviceClient, jobId, 'The scanned document does not appear to be an invoice or receipt.');
      return jsonResponse(
        { error: 'The scanned document does not appear to be an invoice or receipt.' },
        422,
      );
    }

    const warnings: Warning[] = [];
    const totals = normalizeTotals(extraction, warnings);
    const invoiceNumber = sanitizeText(extraction.document?.invoiceNumber);
    const invoiceDate = parseValidInvoiceDate(
      sanitizeText(extraction.document?.invoiceDate, 24),
    );

    // Duplicate check happens BEFORE creating anything: scanning the same
    // receipt twice must not silently produce two invoices (spec §16 —
    // "Show: Possible duplicate invoice. Allow: View Existing, Save
    // Anyway"). Unless the caller already confirmed via `force`, stop here
    // and let the client decide.
    const duplicate = await findPossibleDuplicate(
      serviceClient,
      document.organization_id,
      document.document_hash,
      invoiceNumber,
      invoiceDate,
      totals.totalAmount,
    );
    if (duplicate && !body.force) {
      await serviceClient
        .from('ai_processing_jobs')
        .update({ status: 'completed', completed_at: new Date().toISOString() })
        .eq('id', jobId);
      return jsonResponse({
        duplicate: true,
        existing_invoice_id: duplicate.id,
        existing_invoice_number: duplicate.invoice_number,
        existing_total_amount: duplicate.total_amount,
      });
    }

    const supplierId = await upsertParty(serviceClient, document.organization_id, 'suppliers', extraction.supplier);

    const { data: invoice, error: invoiceError } = await serviceClient
      .from('invoices')
      .insert({
        organization_id: document.organization_id,
        document_id: document.id,
        supplier_id: supplierId,
        schema_version: '1.0',
        document_type: document.document_type,
        invoice_number: invoiceNumber,
        invoice_date: invoiceDate,
        currency: sanitizeText(extraction.document?.currency, 8) ?? 'PKR',
        subtotal: totals.subtotal,
        discount: totals.discount,
        taxable_amount: totals.taxableAmount,
        sales_tax: totals.salesTax,
        other_taxes: totals.otherTaxes,
        total_amount: totals.totalAmount,
        calculation_mismatch: totals.calculationMismatch,
        payment_method: extraction.payment?.method ?? null,
        payment_reference: extraction.payment?.reference ?? null,
        ai_confidence: extraction.confidence ?? {},
        verification_status: 'needs_review',
        document_hash: document.document_hash,
        created_by: document.uploaded_by,
      })
      .select('id')
      .single();

    if (invoiceError || !invoice) {
      throw new Error(invoiceError?.message ?? 'Failed to create invoice.');
    }

    if (extraction.items?.length) {
      const items = extraction.items.map((item, index) => {
        // Line arithmetic is DERIVED here, never taken on faith from the
        // model (same rule the invoice-level totals already follow: Gemini
        // reads the document, it doesn't get the final word on maths).
        // Previously these fell back to a bare `?? 0`, so whenever the
        // model omitted a per-line total — which it often does when the
        // printed invoice only shows a line price and a single tax figure
        // at the bottom — the row silently stored 0.00 and the UI showed
        // "Rs 0" next to a correctly-priced item.
        const quantity = item.quantity ?? 1;
        const unitPrice = item.unitPrice ?? 0;
        const discount = item.discount ?? 0;
        const taxRate = item.taxRate ?? 0;
        const taxableAmount = round2(unitPrice * quantity - discount);
        // Prefer a printed per-line tax figure; otherwise derive it from
        // the rate when one was given. Percentages are plain numbers here
        // (17 means 17%), matching the extraction schema.
        const taxAmount = round2(item.taxAmount ?? (taxableAmount * taxRate) / 100);
        // A model-supplied total is only trusted when it's actually
        // present and non-zero; anything else is computed.
        const reportedTotal = round2(item.totalAmount ?? 0);
        const totalAmount = reportedTotal > 0
          ? reportedTotal
          : round2(taxableAmount + taxAmount);

        return {
          invoice_id: invoice.id,
          line_no: index + 1,
          description: item.description ?? 'Item',
          product_code: item.productCode ?? null,
          quantity,
          unit_of_measure: item.unitOfMeasure ?? null,
          unit_price: unitPrice,
          discount,
          taxable_amount: taxableAmount,
          tax_rate: taxRate,
          tax_amount: taxAmount,
          total_amount: totalAmount,
        };
      });
      await serviceClient.from('invoice_items').insert(items);
    }

    if (totals.salesTax > 0) {
      await serviceClient.from('tax_records').insert({
        organization_id: document.organization_id,
        invoice_id: invoice.id,
        tax_type: 'sales_tax',
        taxable_amount: totals.taxableAmount,
        tax_rate: extraction.items?.[0]?.taxRate ?? 0,
        tax_amount: totals.salesTax,
      });
    }

    const { data: extractionRow } = await serviceClient
      .from('ai_extractions')
      .insert({
        organization_id: document.organization_id,
        job_id: jobId,
        invoice_id: invoice.id,
        model: modelUsed,
        prompt_version: INVOICE_EXTRACTION_PROMPT_VERSION,
        schema_version: EXTRACTION_SCHEMA_VERSION,
        raw_response: extraction,
        normalized_json: totals,
        confidence: extraction.confidence ?? {},
        processing_status: 'completed',
      })
      .select('id')
      .single();

    if (totals.calculationMismatch) {
      warnings.push({
        code: 'calculation_mismatch',
        severity: 'warning',
        message: 'Potential calculation mismatch. Please verify.',
        field_path: 'totals.totalAmount',
      });
    }

    if (warnings.length > 0) {
      await serviceClient.from('ai_warnings').insert(
        warnings.map((w) => ({
          organization_id: document.organization_id,
          invoice_id: invoice.id,
          extraction_id: extractionRow?.id ?? null,
          code: w.code,
          severity: w.severity,
          message: w.message,
          field_path: w.field_path,
        })),
      );
    }

    await serviceClient
      .from('ai_processing_jobs')
      .update({ status: 'completed', completed_at: new Date().toISOString() })
      .eq('id', jobId);

    return jsonResponse({ invoice_id: invoice.id, warnings: warnings.length, calculation_mismatch: totals.calculationMismatch });
  } catch (error) {
    console.error('extract-invoice failed', error);
    const keyErrorResponse = await handleGeminiKeyError(serviceClient, jobId, document.organization_id, error);
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
): Promise<{ data: InvoiceExtractionResult; model: string }> {
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
    // Any failure on the pinned model — overloaded, retired, region-
    // restricted, whatever — is worth one attempt on the fallback alias
    // before giving up, as long as budget remains.
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
): Promise<InvoiceExtractionResult> {
  // Text path when OCR succeeded, image path otherwise. The prompt is
  // identical either way — only the evidence it reasons over changes.
  const parts = ocrText
    ? [
        {
          text:
            `${INVOICE_EXTRACTION_PROMPT}\n\n` +
            `The invoice text below was recognized on-device, top to bottom. ` +
            `Occasional OCR artifacts (misread characters, split lines, ` +
            `column text flattened into separate lines) are expected — ` +
            `interpret them sensibly rather than treating them as literal.\n\n` +
            `INVOICE TEXT:\n${ocrText}`,
        },
      ]
    : [
        { text: INVOICE_EXTRACTION_PROMPT },
        ...images.map((img) => ({ inline_data: { mime_type: img.mimeType, data: img.data } })),
      ];

  const response = await callGeminiApi(
    model,
    apiKey,
    {
      contents: [{ parts }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: invoiceExtractionResponseSchema,
        // Low but non-zero: fully deterministic (0) sometimes makes
        // vision models more prone to confidently skipping a field it
        // isn't sure about rather than reporting a best-effort read.
        temperature: 0.2,
        // Headroom for a long multi-item invoice's JSON so it never gets
        // cut off mid-field (which would look identical to a genuinely
        // missing value), but not so generous that a degenerate repetition
        // loop can run for thousands of tokens before being stopped.
        maxOutputTokens: 3072,
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
    return JSON.parse(text) as InvoiceExtractionResult;
  } catch {
    throw new Error('Gemini response failed JSON schema validation.');
  }
}

function normalizeTotals(extraction: InvoiceExtractionResult, warnings: Warning[]) {
  const t = extraction.totals ?? {};
  const subtotal = round2(t.subtotal ?? 0);
  const discount = round2(t.discount ?? 0);
  const salesTax = round2(t.salesTax ?? 0);
  const otherTaxes = round2(t.otherTaxes ?? 0);
  const taxableAmount = round2(t.taxableAmount ?? subtotal - discount);
  const reportedTotal = round2(t.totalAmount ?? 0);

  const expectedTotal = round2(taxableAmount + salesTax + otherTaxes);
  const calculationMismatch = Math.abs(expectedTotal - reportedTotal) > CALCULATION_TOLERANCE;

  return {
    subtotal,
    discount,
    taxableAmount,
    salesTax,
    otherTaxes,
    totalAmount: reportedTotal || expectedTotal,
    calculationMismatch,
  };
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

interface DuplicateMatch {
  id: string;
  invoice_number: string | null;
  total_amount: number;
}

async function findPossibleDuplicate(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  organizationId: string,
  documentHash: string | null | undefined,
  invoiceNumber: string | null | undefined,
  invoiceDate: string | null | undefined,
  totalAmount: number,
): Promise<DuplicateMatch | null> {
  if (documentHash) {
    const { data } = await serviceClient
      .from('invoices')
      .select('id, invoice_number, total_amount')
      .eq('organization_id', organizationId)
      .eq('document_hash', documentHash)
      .limit(1);
    if (data && data.length > 0) return data[0];
  }

  if (invoiceNumber && invoiceDate) {
    const { data } = await serviceClient
      .from('invoices')
      .select('id, invoice_number, total_amount')
      .eq('organization_id', organizationId)
      .eq('invoice_number', invoiceNumber)
      .eq('invoice_date', invoiceDate)
      .eq('total_amount', totalAmount)
      .limit(1);
    if (data && data.length > 0) return data[0];
  }

  return null;
}

async function upsertParty(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  organizationId: string,
  table: 'suppliers' | 'customers',
  party: InvoiceExtractionResult['supplier'],
): Promise<string | null> {
  const name = sanitizeText(party?.name, 200);
  if (!name) return null;
  const ntn = sanitizeText(party?.ntn, 30);

  if (ntn) {
    const { data: existing } = await serviceClient
      .from(table)
      .select('id')
      .eq('organization_id', organizationId)
      .eq('ntn', ntn)
      .maybeSingle();
    if (existing) return existing.id;
  }

  const { data: created } = await serviceClient
    .from(table)
    .insert({
      organization_id: organizationId,
      name,
      ntn,
      strn: sanitizeText(party?.strn, 30),
      registration_status: sanitizeText(party?.registrationStatus, 40),
      province: sanitizeText(party?.province, 60),
      city: sanitizeText(party?.city, 60),
      address: party?.addressLine ? { line1: sanitizeText(party.addressLine, 300) } : null,
    })
    .select('id')
    .single();

  return created?.id ?? null;
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
