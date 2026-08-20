-- A rejected invoice/transaction is a dispositioned record — it shouldn't
-- keep counting toward Reports totals, Dashboard counts, or "needs
-- attention" flags, the same way it already stopped mattering for
-- approval-queue purposes once 0028_approval_permission_guard.sql added
-- the `rejected` status. Every aggregation function below previously
-- summed/counted every row regardless of status (only `needs_review_count`
-- was ever status-aware), so a rejected invoice's amount kept showing up
-- in charts and totals after rejection — this is the fix.
--
-- `needs_review` rows are deliberately still included (unchanged from
-- before this migration) — only `rejected` is newly excluded.

create or replace function public.get_period_summaries(
  p_organization_id uuid,
  p_period_type text
)
returns table (
  period_start date,
  invoice_count bigint,
  purchases_total numeric,
  tax_total numeric,
  needs_review_count bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'not a member of this organization';
  end if;

  if p_period_type not in ('month', 'quarter', 'year') then
    raise exception 'invalid period type: %', p_period_type;
  end if;

  return query
  select
    date_trunc(p_period_type, i.invoice_date)::date as period_start,
    count(*) as invoice_count,
    coalesce(sum(i.taxable_amount), 0) as purchases_total,
    coalesce(sum(i.sales_tax + i.other_taxes), 0) as tax_total,
    count(*) filter (where i.verification_status = 'needs_review') as needs_review_count
  from public.invoices i
  where i.organization_id = p_organization_id
    and i.invoice_date is not null
    and i.verification_status <> 'rejected'
  group by 1
  order by 1 desc;
end;
$$;

create or replace function public.get_supplier_summaries(p_organization_id uuid)
returns table (
  supplier_id uuid,
  supplier_name text,
  invoice_count bigint,
  purchases_total numeric,
  tax_total numeric,
  needs_review_count bigint,
  last_invoice_date date
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'not a member of this organization';
  end if;

  return query
  select
    coalesce(s.id, '00000000-0000-0000-0000-000000000000'::uuid) as supplier_id,
    coalesce(s.name, 'Unknown supplier') as supplier_name,
    count(*) as invoice_count,
    coalesce(sum(i.taxable_amount), 0) as purchases_total,
    coalesce(sum(i.sales_tax + i.other_taxes), 0) as tax_total,
    count(*) filter (where i.verification_status = 'needs_review') as needs_review_count,
    max(i.invoice_date) as last_invoice_date
  from public.invoices i
  left join public.suppliers s on s.id = i.supplier_id
  where i.organization_id = p_organization_id
    and i.verification_status <> 'rejected'
  group by 1, 2
  order by purchases_total desc;
end;
$$;

create or replace function public.get_bank_transaction_period_summaries(
  p_organization_id uuid,
  p_period_type text
)
returns table (
  period_start date,
  transaction_count bigint,
  credit_total numeric,
  debit_total numeric,
  needs_review_count bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'not a member of this organization';
  end if;

  if p_period_type not in ('month', 'quarter', 'year') then
    raise exception 'invalid period type: %', p_period_type;
  end if;

  return query
  select
    date_trunc(p_period_type, t.transaction_date)::date as period_start,
    count(*) as transaction_count,
    coalesce(sum(t.amount) filter (where t.direction = 'credit'), 0) as credit_total,
    coalesce(sum(t.amount) filter (where t.direction = 'debit'), 0) as debit_total,
    count(*) filter (where t.verification_status = 'needs_review') as needs_review_count
  from public.bank_transactions t
  where t.organization_id = p_organization_id
    and t.transaction_date is not null
    and t.verification_status <> 'rejected'
  group by 1
  order by 1 desc;
end;
$$;

create or replace function public.get_bank_transaction_counterparty_summaries(p_organization_id uuid)
returns table (
  counterparty_name text,
  transaction_count bigint,
  credit_total numeric,
  debit_total numeric,
  needs_review_count bigint,
  last_transaction_date timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'not a member of this organization';
  end if;

  return query
  select
    coalesce(nullif(t.counterparty_name, ''), 'Unknown counterparty') as counterparty_name,
    count(*) as transaction_count,
    coalesce(sum(t.amount) filter (where t.direction = 'credit'), 0) as credit_total,
    coalesce(sum(t.amount) filter (where t.direction = 'debit'), 0) as debit_total,
    count(*) filter (where t.verification_status = 'needs_review') as needs_review_count,
    max(t.transaction_date) as last_transaction_date
  from public.bank_transactions t
  where t.organization_id = p_organization_id
    and t.verification_status <> 'rejected'
  group by 1
  order by (credit_total + debit_total) desc;
end;
$$;

create or replace function public.get_dashboard_summary(p_organization_id uuid)
returns table (
  total_invoices bigint,
  current_month_invoices bigint,
  pending_verification bigint,
  potential_issues bigint,
  total_bank_transactions bigint,
  current_month_bank_transactions bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'not a member of this organization';
  end if;

  return query
  select
    (select count(*) from public.invoices i
       where i.organization_id = p_organization_id and i.verification_status <> 'rejected'
    ) as total_invoices,
    (select count(*) from public.invoices i
       where i.organization_id = p_organization_id
         and i.verification_status <> 'rejected'
         and date_trunc('month', i.invoice_date) = date_trunc('month', current_date)
    ) as current_month_invoices,
    (select count(*) from public.invoices i
       where i.organization_id = p_organization_id and i.verification_status = 'needs_review'
    ) as pending_verification,
    (select count(*) from public.invoices i
       where i.organization_id = p_organization_id
         and i.verification_status <> 'rejected'
         and (i.calculation_mismatch
              or exists (
                   select 1 from public.ai_warnings w
                   where w.invoice_id = i.id and not w.resolved and w.severity in ('warning', 'error')
                 ))
    ) as potential_issues,
    (select count(*) from public.bank_transactions t
       where t.organization_id = p_organization_id and t.verification_status <> 'rejected'
    ) as total_bank_transactions,
    (select count(*) from public.bank_transactions t
       where t.organization_id = p_organization_id
         and t.verification_status <> 'rejected'
         and date_trunc('month', t.transaction_date) = date_trunc('month', current_date)
    ) as current_month_bank_transactions;
end;
$$;

-- delete_invoice/delete_bank_transaction (0019/0020) only ever checked
-- is_org_member, bypassing the owner/admin-only invoices_delete_owner_admin
-- / bank_transactions_delete_owner_admin RLS policies entirely (these RPCs
-- are security definer, so RLS never applies to their internal delete
-- statement). That was survivable when every org had one member; now that
-- business orgs can have staff, any member — including one with no
-- approval rights — could permanently delete a colleague's already
-- verified/rejected record through this RPC. A needs_review row is still
-- freely deletable by any member (it's an unconfirmed draft, matching the
-- original intent of letting someone back out of a scan they never
-- saved) — only a DECIDED (verified/rejected) row now requires owner/admin,
-- mirroring the RLS policy these RPCs were meant to respect.
create or replace function public.delete_invoice(p_invoice_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_document_id uuid;
  v_status text;
begin
  select organization_id, document_id, verification_status
    into v_org_id, v_document_id, v_status
  from public.invoices
  where id = p_invoice_id;

  if v_org_id is null then
    raise exception 'invoice not found';
  end if;

  if not public.is_org_member(v_org_id) then
    raise exception 'not authorized';
  end if;

  if v_status <> 'needs_review' and not public.has_org_role(v_org_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;

  delete from public.invoices where id = p_invoice_id;

  if v_document_id is not null then
    delete from public.documents where id = v_document_id;
  end if;
end;
$$;

create or replace function public.delete_bank_transaction(p_transaction_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_document_id uuid;
  v_status text;
begin
  select organization_id, document_id, verification_status
    into v_org_id, v_document_id, v_status
  from public.bank_transactions
  where id = p_transaction_id;

  if v_org_id is null then
    raise exception 'transaction not found';
  end if;

  if not public.is_org_member(v_org_id) then
    raise exception 'not authorized';
  end if;

  if v_status <> 'needs_review' and not public.has_org_role(v_org_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;

  delete from public.bank_transactions where id = p_transaction_id;

  if v_document_id is not null then
    delete from public.documents where id = v_document_id;
  end if;
end;
$$;
