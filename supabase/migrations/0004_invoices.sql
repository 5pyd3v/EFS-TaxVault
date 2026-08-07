-- Invoices are the relational source of truth. The canonical JSON
-- (CanonicalTaxInvoice, spec §4) is always regenerated from these columns —
-- `canonical_snapshot` below is a cache of the last-generated JSON for fast
-- reads, never the record of truth itself (spec §19).

create table public.tax_periods (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  period_type text not null check (period_type in ('monthly', 'quarterly', 'annual')),
  period_start date not null,
  period_end date not null,
  label text not null,
  created_at timestamptz not null default now(),
  unique (organization_id, period_type, period_start)
);

create index idx_tax_periods_org on public.tax_periods (organization_id);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  document_id uuid references public.documents (id) on delete set null,
  supplier_id uuid references public.suppliers (id) on delete set null,
  customer_id uuid references public.customers (id) on delete set null,
  category_id uuid references public.categories (id) on delete set null,
  tax_period_id uuid references public.tax_periods (id) on delete set null,

  -- Canonical schema versioning (spec §3) — never assume the current shape
  -- is final; older rows keep the version they were created under.
  schema_version text not null default '1.0',

  -- Identification
  document_type text not null default 'invoice',
  invoice_number text,
  invoice_date date,
  currency text not null default 'PKR',

  -- Totals — deterministic, never AI-authored (spec §8)
  subtotal numeric(14, 2) not null default 0,
  discount numeric(14, 2) not null default 0,
  taxable_amount numeric(14, 2) not null default 0,
  sales_tax numeric(14, 2) not null default 0,
  other_taxes numeric(14, 2) not null default 0,
  total_amount numeric(14, 2) not null default 0,
  calculation_mismatch boolean not null default false,

  -- Payment / references
  payment_method text,
  payment_reference text,

  -- AI + verification (spec §9-10)
  ai_confidence jsonb not null default '{}'::jsonb,
  verification_status text not null default 'needs_review'
    check (verification_status in ('needs_review', 'verified', 'rejected')),
  verified_by uuid references auth.users (id),
  verified_at timestamptz,

  -- Duplicate detection signal (spec §16)
  document_hash text,

  canonical_snapshot jsonb,

  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_invoices_org on public.invoices (organization_id);
create index idx_invoices_org_date on public.invoices (organization_id, invoice_date);
create index idx_invoices_org_supplier on public.invoices (organization_id, supplier_id);
create index idx_invoices_org_verification on public.invoices (organization_id, verification_status);
create index idx_invoices_duplicate_signal
  on public.invoices (organization_id, supplier_id, invoice_number, invoice_date, total_amount);

create table public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  line_no integer not null default 1,
  description text not null,
  product_code text,
  quantity numeric(14, 4) not null default 1,
  unit_of_measure text,
  unit_price numeric(14, 4) not null default 0,
  discount numeric(14, 2) not null default 0,
  taxable_amount numeric(14, 2) not null default 0,
  tax_rate numeric(6, 3) not null default 0,
  tax_amount numeric(14, 2) not null default 0,
  total_amount numeric(14, 2) not null default 0,
  created_at timestamptz not null default now()
);

create index idx_invoice_items_invoice on public.invoice_items (invoice_id);

-- Per-tax-type breakdown (sales tax, further/withholding tax, etc.) — kept
-- separate from invoices.sales_tax/other_taxes so reporting can break down
-- by tax_type without parsing JSON.
create table public.tax_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  tax_period_id uuid references public.tax_periods (id) on delete set null,
  tax_type text not null,
  taxable_amount numeric(14, 2) not null default 0,
  tax_rate numeric(6, 3) not null default 0,
  tax_amount numeric(14, 2) not null default 0,
  created_at timestamptz not null default now()
);

create index idx_tax_records_org on public.tax_records (organization_id);
create index idx_tax_records_invoice on public.tax_records (invoice_id);
create index idx_tax_records_period on public.tax_records (tax_period_id);
