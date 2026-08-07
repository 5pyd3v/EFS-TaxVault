-- FBR submission lifecycle (spec §20-22). Created now even though no FBR
-- adapter exists yet, so integrating the real FBR API later is a contained
-- adapter swap rather than a schema migration. `payload`/`response` hold
-- whatever the active FBRAdapter produces/receives — the shape is the
-- adapter's concern, not this table's.

create table public.fbr_submissions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  schema_version text not null,
  adapter_version text not null default 'mock-v0',
  status text not null default 'not_ready'
    check (status in (
      'not_ready', 'ready', 'queued', 'submitted',
      'accepted', 'rejected', 'failed', 'retry_required'
    )),
  payload jsonb,
  response jsonb,
  external_reference text,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_fbr_submissions_org on public.fbr_submissions (organization_id);
create index idx_fbr_submissions_invoice on public.fbr_submissions (invoice_id);
create index idx_fbr_submissions_status on public.fbr_submissions (organization_id, status);

-- One row per attempt, so a retried submission preserves the full history
-- of request/response pairs rather than overwriting the previous attempt —
-- required for audit/troubleshooting (spec §22).
create table public.fbr_submission_attempts (
  id uuid primary key default gen_random_uuid(),
  fbr_submission_id uuid not null references public.fbr_submissions (id) on delete cascade,
  attempt_no integer not null,
  request_payload jsonb,
  response_payload jsonb,
  http_status integer,
  error_code text,
  error_message text,
  adapter_version text not null,
  schema_version text not null,
  attempted_at timestamptz not null default now(),
  unique (fbr_submission_id, attempt_no)
);

create index idx_fbr_attempts_submission on public.fbr_submission_attempts (fbr_submission_id);
