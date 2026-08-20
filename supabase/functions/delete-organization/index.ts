// Edge Function: delete-organization
//
// Platform-admin only. Permanently removes an organization and everything
// scoped to it (documents, invoices, bank_transactions, members, keys,
// audit history — every table with an organization_id FK cascades). User
// accounts are deliberately left alone: a deleted org's former members
// just become org-less accounts, not deleted people — see
// delete_organization in 0037_delete_org_and_relax_dispute_delete.sql for
// why, and delete-platform-user for the separate, explicit action that
// actually removes a person's account.
//
// Storage cleanup (scanned document images) can't be done in SQL — this
// function does it first, best-effort, before calling the DB-level
// delete, mirroring how a single-invoice delete already tolerates a
// storage failure without blocking the DB removal.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

interface DeleteOrganizationRequest {
  organization_id: string;
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

  let body: DeleteOrganizationRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid request body.' }, 400);
  }
  if (!body.organization_id) {
    return jsonResponse({ error: 'organization_id is required.' }, 400);
  }

  const { data: isAdmin, error: adminCheckErr } = await callerClient.rpc('is_platform_admin');
  if (adminCheckErr || !isAdmin) {
    return jsonResponse({ error: 'Only a platform admin can delete an organization.' }, 403);
  }

  // Best-effort storage cleanup: list every document under this org's
  // prefix and remove its page images. A failure here doesn't block the
  // actual account deletion below — an orphaned storage object is
  // recoverable later, a half-deleted account is a worse state to be in.
  try {
    const { data: documents } = await serviceClient
      .from('documents')
      .select('storage_path, page_count')
      .eq('organization_id', body.organization_id);

    const paths = (documents ?? []).flatMap((d) => {
      if (!d.storage_path || !d.page_count) return [];
      return Array.from(
        { length: d.page_count },
        (_, i) => `${d.storage_path}/page_${i + 1}.jpg`,
      );
    });
    if (paths.length > 0) {
      await serviceClient.storage.from('documents').remove(paths);
    }
  } catch (err) {
    console.error('delete-organization: storage cleanup failed, continuing', err);
  }

  const { error: deleteErr } = await serviceClient.rpc('delete_organization', {
    p_organization_id: body.organization_id,
  });
  if (deleteErr) {
    console.error('delete-organization: delete_organization RPC failed', deleteErr);
    return jsonResponse({ error: 'Could not delete this organization. Please try again.' }, 500);
  }

  return jsonResponse({ deleted: true });
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
