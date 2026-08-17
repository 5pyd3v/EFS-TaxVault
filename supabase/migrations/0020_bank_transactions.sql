-- Bank transaction receipts (payment confirmations from banks/wallets —
-- Meezan, UBL, NayaPay, SadaPay, Bank Alfalah, EasyPaisa, etc.) — a
-- deliberately separate table from `invoices` since the field shape is
-- completely different (no supplier/tax/line-items; instead: direction,
-- counterparty, account, bank/wallet name, reference number). Kept as its
-- own "separate view" in the app per the user's explicit request, not
-- mixed into the Vault/invoices list.

alter table public.documents
  drop constraint documents_document_type_check,
  add constraint documents_document_type_check
    check (document_type in ('invoice', 'receipt', 'tax_document', 'other', 'bank_transaction'));

create table public.bank_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  document_id uuid references public.documents (id) on delete set null,

  direction text not null check (direction in ('debit', 'credit')),
  amount numeric(14, 2) not null default 0,
  currency text not null default 'PKR',
  transaction_date timestamptz,

  counterparty_name text,
  counterparty_account text,
  bank_name text,
  reference_number text,
  status text,

  ai_confidence jsonb not null default '{}'::jsonb,
  verification_status text not null default 'needs_review'
    check (verification_status in ('needs_review', 'verified', 'rejected')),
  verified_by uuid references auth.users (id),
  verified_at timestamptz,

  -- Duplicate detection signal (spec §16 pattern, mirrored from invoices).
  document_hash text,

  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_bank_transactions_org on public.bank_transactions (organization_id);
create index idx_bank_transactions_org_date on public.bank_transactions (organization_id, transaction_date);
create index idx_bank_transactions_org_verification on public.bank_transactions (organization_id, verification_status);
create index idx_bank_transactions_duplicate_signal on public.bank_transactions (organization_id, document_hash);

create trigger set_updated_at before update on public.bank_transactions
  for each row execute function public.set_updated_at();

alter table public.bank_transactions enable row level security;

create policy "bank_transactions_select_member" on public.bank_transactions
  for select using (public.is_org_member(organization_id));
create policy "bank_transactions_insert_non_viewer" on public.bank_transactions
  for insert with check (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));
create policy "bank_transactions_update_non_viewer" on public.bank_transactions
  for update using (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));
create policy "bank_transactions_delete_owner_admin" on public.bank_transactions
  for delete using (public.has_org_role(organization_id, array['owner', 'admin']));

-- Mirrors delete_invoice (0019_delete_invoice.sql): deletes the row and its
-- documents row; Storage objects are removed client-side first since they
-- aren't reachable from plain SQL.
create or replace function public.delete_bank_transaction(p_transaction_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_document_id uuid;
begin
  select organization_id, document_id into v_org_id, v_document_id
  from public.bank_transactions
  where id = p_transaction_id;

  if v_org_id is null then
    raise exception 'transaction not found';
  end if;

  if not public.is_org_member(v_org_id) then
    raise exception 'not authorized';
  end if;

  delete from public.bank_transactions where id = p_transaction_id;

  if v_document_id is not null then
    delete from public.documents where id = v_document_id;
  end if;
end;
$$;

grant execute on function public.delete_bank_transaction(uuid) to authenticated;
