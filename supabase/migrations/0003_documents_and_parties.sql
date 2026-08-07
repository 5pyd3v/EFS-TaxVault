-- Uploaded source files, and supplier/customer master data extracted from
-- (and reused across) invoices.

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  uploaded_by uuid not null references auth.users (id),
  storage_path text not null,
  mime_type text not null,
  file_size_bytes bigint,
  page_count integer not null default 1,
  document_type text not null default 'invoice'
    check (document_type in ('invoice', 'receipt', 'tax_document', 'other')),
  capture_source text check (capture_source in ('camera', 'gallery', 'import')),
  document_hash text,
  created_at timestamptz not null default now()
);

create index idx_documents_org on public.documents (organization_id);
create index idx_documents_hash on public.documents (organization_id, document_hash);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  ntn text,
  strn text,
  registration_status text,
  address jsonb,
  province text,
  city text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_suppliers_org on public.suppliers (organization_id);
create unique index idx_suppliers_org_ntn on public.suppliers (organization_id, ntn) where ntn is not null;

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  ntn text,
  strn text,
  registration_status text,
  address jsonb,
  province text,
  city text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_customers_org on public.customers (organization_id);
create unique index idx_customers_org_ntn on public.customers (organization_id, ntn) where ntn is not null;
