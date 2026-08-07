-- Row Level Security. Every table is organization-scoped through
-- `is_org_member`/`has_org_role` (0001_extensions_and_helpers.sql) so one
-- organization can never read or write another's data (spec §23, §41).
--
-- Tables the client should never write directly — ai_processing_jobs,
-- ai_extractions, ai_warnings, fbr_submissions, fbr_submission_attempts,
-- subscriptions, audit_logs, notifications — get a SELECT policy only.
-- Only the service-role key (used from Edge Functions, which bypasses RLS)
-- can write them. This is what makes "AI requests must be handled
-- server-side" and "FBR submission is not client-initiated" enforceable
-- facts rather than conventions.

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.categories enable row level security;
alter table public.subscriptions enable row level security;
alter table public.documents enable row level security;
alter table public.suppliers enable row level security;
alter table public.customers enable row level security;
alter table public.tax_periods enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.tax_records enable row level security;
alter table public.ai_processing_jobs enable row level security;
alter table public.ai_extractions enable row level security;
alter table public.ai_warnings enable row level security;
alter table public.fbr_submissions enable row level security;
alter table public.fbr_submission_attempts enable row level security;
alter table public.audit_logs enable row level security;
alter table public.notifications enable row level security;

-- profiles -------------------------------------------------------------
create policy "profiles_select_own" on public.profiles
  for select using (id = auth.uid());
create policy "profiles_update_own" on public.profiles
  for update using (id = auth.uid());

-- organizations ----------------------------------------------------------
-- No client-side INSERT policy: creation only happens through
-- create_organization_with_owner (SECURITY DEFINER, 0009_triggers.sql) so
-- an organization can never exist without an owner membership row.
create policy "organizations_select_member" on public.organizations
  for select using (public.is_org_member(id));
create policy "organizations_update_owner_admin" on public.organizations
  for update using (public.has_org_role(id, array['owner', 'admin']));

-- organization_members -----------------------------------------------
create policy "org_members_select_member" on public.organization_members
  for select using (public.is_org_member(organization_id));
create policy "org_members_insert_owner_admin" on public.organization_members
  for insert with check (public.has_org_role(organization_id, array['owner', 'admin']));
create policy "org_members_update_owner_admin" on public.organization_members
  for update using (public.has_org_role(organization_id, array['owner', 'admin']));
create policy "org_members_delete_owner_admin" on public.organization_members
  for delete using (public.has_org_role(organization_id, array['owner', 'admin']));

-- categories -------------------------------------------------------------
create policy "categories_select_member" on public.categories
  for select using (public.is_org_member(organization_id));
create policy "categories_write_non_viewer" on public.categories
  for all using (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']))
  with check (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));

-- subscriptions (read-only to the client; billing writes via service role)
create policy "subscriptions_select_member" on public.subscriptions
  for select using (public.is_org_member(organization_id));

-- documents ----------------------------------------------------------------
create policy "documents_select_member" on public.documents
  for select using (public.is_org_member(organization_id));
create policy "documents_insert_non_viewer" on public.documents
  for insert with check (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));
create policy "documents_delete_non_viewer" on public.documents
  for delete using (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));

-- suppliers / customers ------------------------------------------------
create policy "suppliers_select_member" on public.suppliers
  for select using (public.is_org_member(organization_id));
create policy "suppliers_write_non_viewer" on public.suppliers
  for all using (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']))
  with check (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));

create policy "customers_select_member" on public.customers
  for select using (public.is_org_member(organization_id));
create policy "customers_write_non_viewer" on public.customers
  for all using (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']))
  with check (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));

-- tax_periods --------------------------------------------------------
create policy "tax_periods_select_member" on public.tax_periods
  for select using (public.is_org_member(organization_id));
create policy "tax_periods_write_non_viewer" on public.tax_periods
  for all using (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']))
  with check (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));

-- invoices --------------------------------------------------------------
-- Viewer role is explicitly read-only (spec §41 security test).
create policy "invoices_select_member" on public.invoices
  for select using (public.is_org_member(organization_id));
create policy "invoices_insert_non_viewer" on public.invoices
  for insert with check (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));
create policy "invoices_update_non_viewer" on public.invoices
  for update using (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));
create policy "invoices_delete_owner_admin" on public.invoices
  for delete using (public.has_org_role(organization_id, array['owner', 'admin']));

-- invoice_items (no organization_id column — scoped via parent invoice) --
create policy "invoice_items_select_member" on public.invoice_items
  for select using (
    exists (
      select 1 from public.invoices i
      where i.id = invoice_items.invoice_id and public.is_org_member(i.organization_id)
    )
  );
create policy "invoice_items_write_non_viewer" on public.invoice_items
  for all using (
    exists (
      select 1 from public.invoices i
      where i.id = invoice_items.invoice_id
        and public.has_org_role(i.organization_id, array['owner', 'admin', 'accountant', 'member'])
    )
  )
  with check (
    exists (
      select 1 from public.invoices i
      where i.id = invoice_items.invoice_id
        and public.has_org_role(i.organization_id, array['owner', 'admin', 'accountant', 'member'])
    )
  );

-- tax_records -------------------------------------------------------------
create policy "tax_records_select_member" on public.tax_records
  for select using (public.is_org_member(organization_id));

-- ai_processing_jobs / ai_extractions / ai_warnings (read-only to client) -
create policy "ai_jobs_select_member" on public.ai_processing_jobs
  for select using (public.is_org_member(organization_id));
create policy "ai_extractions_select_member" on public.ai_extractions
  for select using (public.is_org_member(organization_id));
create policy "ai_warnings_select_member" on public.ai_warnings
  for select using (public.is_org_member(organization_id));

-- fbr_submissions / fbr_submission_attempts (read-only to client) --------
create policy "fbr_submissions_select_member" on public.fbr_submissions
  for select using (public.is_org_member(organization_id));
create policy "fbr_submission_attempts_select_member" on public.fbr_submission_attempts
  for select using (
    exists (
      select 1 from public.fbr_submissions s
      where s.id = fbr_submission_attempts.fbr_submission_id
        and public.is_org_member(s.organization_id)
    )
  );

-- audit_logs (read-only to client; written by triggers/service role) -----
create policy "audit_logs_select_member" on public.audit_logs
  for select using (public.is_org_member(organization_id));

-- notifications ------------------------------------------------------
create policy "notifications_select_own" on public.notifications
  for select using (user_id = auth.uid() and public.is_org_member(organization_id));
create policy "notifications_update_own" on public.notifications
  for update using (user_id = auth.uid());
