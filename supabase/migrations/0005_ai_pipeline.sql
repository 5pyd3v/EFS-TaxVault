-- AI processing pipeline bookkeeping (spec §11, §36-37). Every extraction
-- records the model, prompt version, and schema version it ran under, so
-- results stay interpretable even as prompts/models change over time.

create table public.ai_processing_jobs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  document_id uuid not null references public.documents (id) on delete cascade,
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'completed', 'failed')),
  attempts integer not null default 0,
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_ai_jobs_org on public.ai_processing_jobs (organization_id);
create index idx_ai_jobs_document on public.ai_processing_jobs (document_id);
create index idx_ai_jobs_status on public.ai_processing_jobs (organization_id, status);

create table public.ai_extractions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  job_id uuid not null references public.ai_processing_jobs (id) on delete cascade,
  invoice_id uuid references public.invoices (id) on delete set null,
  model text not null,
  prompt_version text not null,
  schema_version text not null,
  raw_response jsonb,
  normalized_json jsonb,
  confidence jsonb not null default '{}'::jsonb,
  processing_status text not null default 'completed'
    check (processing_status in ('completed', 'failed', 'low_confidence')),
  created_at timestamptz not null default now()
);

create index idx_ai_extractions_org on public.ai_extractions (organization_id);
create index idx_ai_extractions_job on public.ai_extractions (job_id);
create index idx_ai_extractions_invoice on public.ai_extractions (invoice_id);

-- Tax-intelligence warnings surfaced to the user (spec §17) — deliberately
-- hedged language ("appears", "please verify"), never framed as legal
-- advice or a guaranteed finding.
create table public.ai_warnings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  extraction_id uuid references public.ai_extractions (id) on delete set null,
  code text not null,
  severity text not null default 'warning' check (severity in ('info', 'warning', 'error')),
  message text not null,
  field_path text,
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_ai_warnings_org on public.ai_warnings (organization_id);
create index idx_ai_warnings_invoice on public.ai_warnings (invoice_id);
