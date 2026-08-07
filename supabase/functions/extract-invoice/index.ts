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
} from '../_shared/prompts/invoice_extraction_v1.ts';

const GEMINI_MODEL = 'gemini-2.5-flash';
const CALCULATION_TOLERANCE = 1.0; // PKR — rounding slack before flagging a mismatch
const DOCUMENT_BUCKET = 'documents';

interface ExtractInvoiceRequest {
  document_id: string;
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
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY');

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
    .select('id, organization_id, uploaded_by, storage_path, page_count, document_type, document_hash')
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
    if (!geminiApiKey) {
      throw new Error('AI service is not configured.');
    }

    const imageParts = await downloadPageImages(serviceClient, document.storage_path, document.page_count);
    const extraction = await callGemini(geminiApiKey, imageParts);

    if (!extraction.isInvoice) {
      await failJob(serviceClient, jobId, 'The scanned document does not appear to be an invoice or receipt.');
      return jsonResponse(
        { error: 'The scanned document does not appear to be an invoice or receipt.' },
        422,
      );
    }

    const warnings: Warning[] = [];
    const totals = normalizeTotals(extraction, warnings);

    const duplicate = await findPossibleDuplicate(
      serviceClient,
      document.organization_id,
      document.document_hash,
      extraction.document?.invoiceNumber,
      extraction.document?.invoiceDate,
      totals.totalAmount,
    );
    if (duplicate) {
      warnings.push({
        code: 'possible_duplicate',
        severity: 'warning',
        message: 'This looks similar to an existing invoice. Please verify it isn’t a duplicate.',
        field_path: null,
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
        invoice_number: extraction.document?.invoiceNumber ?? null,
        invoice_date: extraction.document?.invoiceDate ?? null,
        currency: extraction.document?.currency ?? 'PKR',
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
      const items = extraction.items.map((item, index) => ({
        invoice_id: invoice.id,
        line_no: index + 1,
        description: item.description ?? 'Item',
        product_code: item.productCode ?? null,
        quantity: item.quantity ?? 1,
        unit_of_measure: item.unitOfMeasure ?? null,
        unit_price: item.unitPrice ?? 0,
        discount: item.discount ?? 0,
        taxable_amount: (item.unitPrice ?? 0) * (item.quantity ?? 1) - (item.discount ?? 0),
        tax_rate: item.taxRate ?? 0,
        tax_amount: item.taxAmount ?? 0,
        total_amount: item.totalAmount ?? 0,
      }));
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
        model: GEMINI_MODEL,
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
): Promise<InvoiceExtractionResult> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: INVOICE_EXTRACTION_PROMPT },
              ...images.map((img) => ({ inline_data: { mime_type: img.mimeType, data: img.data } })),
            ],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: invoiceExtractionResponseSchema,
          temperature: 0.1,
        },
      }),
    },
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Gemini request failed (${response.status}): ${text.slice(0, 300)}`);
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

async function findPossibleDuplicate(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  organizationId: string,
  documentHash: string | null | undefined,
  invoiceNumber: string | null | undefined,
  invoiceDate: string | null | undefined,
  totalAmount: number,
): Promise<boolean> {
  if (documentHash) {
    const { data } = await serviceClient
      .from('invoices')
      .select('id')
      .eq('organization_id', organizationId)
      .eq('document_hash', documentHash)
      .limit(1);
    if (data && data.length > 0) return true;
  }

  if (invoiceNumber && invoiceDate) {
    const { data } = await serviceClient
      .from('invoices')
      .select('id')
      .eq('organization_id', organizationId)
      .eq('invoice_number', invoiceNumber)
      .eq('invoice_date', invoiceDate)
      .eq('total_amount', totalAmount)
      .limit(1);
    if (data && data.length > 0) return true;
  }

  return false;
}

async function upsertParty(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  organizationId: string,
  table: 'suppliers' | 'customers',
  party: InvoiceExtractionResult['supplier'],
): Promise<string | null> {
  if (!party?.name) return null;

  if (party.ntn) {
    const { data: existing } = await serviceClient
      .from(table)
      .select('id')
      .eq('organization_id', organizationId)
      .eq('ntn', party.ntn)
      .maybeSingle();
    if (existing) return existing.id;
  }

  const { data: created } = await serviceClient
    .from(table)
    .insert({
      organization_id: organizationId,
      name: party.name,
      ntn: party.ntn ?? null,
      strn: party.strn ?? null,
      registration_status: party.registrationStatus ?? null,
      province: party.province ?? null,
      city: party.city ?? null,
      address: party.addressLine ? { line1: party.addressLine } : null,
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
