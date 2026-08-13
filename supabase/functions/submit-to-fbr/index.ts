// Edge Function: submit-to-fbr
//
// This IS the TaxAuthorityService the spec describes (§5-6) — but FBRAdapter
// is mock-only until the official FBR API/schema is published. Nothing here
// talks to a real government endpoint. The response is always clearly
// labeled `mock: true` and the external reference is prefixed `MOCK-FBR-`
// so it can never be confused with a real filing (spec §34: never invent or
// claim official FBR acceptance).
//
// Validation pipeline (spec §6):
//   required fields -> business rules (must be verified) ->
//   tax calculation consistency -> duplicate submission check ->
//   canonical JSON -> mock adapter payload -> simulated submission
//
// Swapping the mock step for a real FBR API call later is a contained
// change inside this function — nothing about invoices, the canonical
// JSON, or the fbr_submissions schema needs to change.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const ADAPTER_VERSION = 'mock-v1';
const SCHEMA_VERSION = '1.0';

interface SubmitRequest {
  invoice_id: string;
  force?: boolean;
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

  let body: SubmitRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid request body.' }, 400);
  }
  if (!body.invoice_id) {
    return jsonResponse({ error: 'invoice_id is required.' }, 400);
  }

  // RLS-scoped read: only proceeds if the caller is actually a member of
  // this invoice's organization.
  const { data: invoice, error: invoiceError } = await callerClient
    .from('invoices')
    .select(
      'id, organization_id, invoice_number, invoice_date, total_amount, calculation_mismatch, verification_status, supplier_id, suppliers(ntn)',
    )
    .eq('id', body.invoice_id)
    .single();

  if (invoiceError || !invoice) {
    return jsonResponse({ error: 'Invoice not found or access denied.' }, 404);
  }

  const { count: itemCount } = await serviceClient
    .from('invoice_items')
    .select('id', { count: 'exact', head: true })
    .eq('invoice_id', invoice.id);

  // --- Validation pipeline -------------------------------------------
  const errors: string[] = [];
  if (!invoice.invoice_number) errors.push('Invoice number is required.');
  if (!invoice.invoice_date) errors.push('Invoice date is required.');
  if (!invoice.supplier_id) errors.push('Supplier is required.');
  if (!(invoice.suppliers as { ntn?: string } | null)?.ntn) {
    errors.push('Supplier NTN is required for FBR submission.');
  }
  if (!invoice.total_amount || invoice.total_amount <= 0) {
    errors.push('Total amount must be greater than zero.');
  }
  if (!itemCount || itemCount === 0) {
    errors.push('At least one line item is required.');
  }
  if (invoice.verification_status !== 'verified') {
    errors.push('Invoice must be verified before it can be submitted.');
  }
  if (invoice.calculation_mismatch) {
    errors.push('Resolve the calculation mismatch before submitting.');
  }

  // One fbr_submissions row per invoice; each call appends an attempt.
  let { data: submission } = await serviceClient
    .from('fbr_submissions')
    .select('id, status')
    .eq('invoice_id', invoice.id)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!submission) {
    const { data: created } = await serviceClient
      .from('fbr_submissions')
      .insert({
        organization_id: invoice.organization_id,
        invoice_id: invoice.id,
        schema_version: SCHEMA_VERSION,
        adapter_version: ADAPTER_VERSION,
        status: 'not_ready',
      })
      .select('id, status')
      .single();
    submission = created;
  }

  if (!submission) {
    return jsonResponse({ error: 'Could not prepare submission record.' }, 500);
  }

  const { count: attemptCount } = await serviceClient
    .from('fbr_submission_attempts')
    .select('id', { count: 'exact', head: true })
    .eq('fbr_submission_id', submission.id);
  const nextAttemptNo = (attemptCount ?? 0) + 1;

  if (errors.length > 0) {
    await serviceClient
      .from('fbr_submissions')
      .update({ status: 'not_ready', response: { validation_errors: errors } })
      .eq('id', submission.id);
    await serviceClient.from('fbr_submission_attempts').insert({
      fbr_submission_id: submission.id,
      attempt_no: nextAttemptNo,
      response_payload: { validation_errors: errors },
      http_status: 422,
      error_code: 'validation_failed',
      error_message: errors.join(' '),
      adapter_version: ADAPTER_VERSION,
      schema_version: SCHEMA_VERSION,
    });
    return jsonResponse({ errors }, 422);
  }

  if (submission.status === 'accepted' && !body.force) {
    const { data: existing } = await serviceClient
      .from('fbr_submissions')
      .select('external_reference, submitted_at')
      .eq('id', submission.id)
      .single();
    return jsonResponse({
      already_submitted: true,
      external_reference: existing?.external_reference,
      submitted_at: existing?.submitted_at,
    });
  }

  // --- Canonical JSON -> mock adapter payload -------------------------
  const { data: canonicalJson, error: canonicalError } = await serviceClient.rpc(
    'get_canonical_invoice_json',
    { p_invoice_id: invoice.id },
  );
  if (canonicalError || !canonicalJson) {
    return jsonResponse({ error: 'Could not build canonical invoice JSON.' }, 500);
  }

  const mockPayload = {
    adapterVersion: ADAPTER_VERSION,
    schemaVersion: SCHEMA_VERSION,
    note: 'Mock FBR payload — official FBR schema not yet integrated.',
    canonical: canonicalJson,
  };

  // --- Simulated submission -------------------------------------------
  const externalReference = `MOCK-FBR-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
  const mockResponse = {
    mock: true,
    message: 'Simulated acceptance. FBR API integration is not yet connected — this is not a real filing.',
    externalReference,
    receivedAt: new Date().toISOString(),
  };

  await serviceClient
    .from('fbr_submissions')
    .update({
      status: 'accepted',
      payload: mockPayload,
      response: mockResponse,
      external_reference: externalReference,
      submitted_at: new Date().toISOString(),
    })
    .eq('id', submission.id);

  await serviceClient.from('fbr_submission_attempts').insert({
    fbr_submission_id: submission.id,
    attempt_no: nextAttemptNo,
    request_payload: mockPayload,
    response_payload: mockResponse,
    http_status: 200,
    adapter_version: ADAPTER_VERSION,
    schema_version: SCHEMA_VERSION,
  });

  return jsonResponse({
    status: 'accepted',
    mock: true,
    external_reference: externalReference,
  });
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
