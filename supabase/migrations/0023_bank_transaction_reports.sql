-- Extends reporting to bank transactions, mirroring the invoice report RPCs
-- (0013_report_functions.sql, 0016_supplier_summaries.sql) so Reports can
-- show the same by-period / by-group flow for both domains. Also reshapes
-- get_dashboard_summary: drops the money figure the home page no longer
-- shows (Dashboard now leads with document activity, not a tax amount) and
-- adds bank-transaction counts so the home page can report combined
-- document activity across both invoices and bank transactions.

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
  group by 1
  order by 1 desc;
end;
$$;

grant execute on function public.get_bank_transaction_period_summaries(uuid, text) to authenticated;

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
  group by 1
  order by (credit_total + debit_total) desc;
end;
$$;

grant execute on function public.get_bank_transaction_counterparty_summaries(uuid) to authenticated;

-- Reshape get_dashboard_summary: drop current_month_tax_amount (the home
-- page no longer displays a money figure), add bank-transaction counts.
drop function if exists public.get_dashboard_summary(uuid);

create function public.get_dashboard_summary(p_organization_id uuid)
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
    (select count(*) from public.invoices i where i.organization_id = p_organization_id) as total_invoices,
    (select count(*) from public.invoices i
       where i.organization_id = p_organization_id
         and date_trunc('month', i.invoice_date) = date_trunc('month', current_date)
    ) as current_month_invoices,
    (select count(*) from public.invoices i
       where i.organization_id = p_organization_id and i.verification_status = 'needs_review'
    ) as pending_verification,
    (select count(*) from public.invoices i
       where i.organization_id = p_organization_id
         and (i.calculation_mismatch
              or exists (
                   select 1 from public.ai_warnings w
                   where w.invoice_id = i.id and not w.resolved and w.severity in ('warning', 'error')
                 ))
    ) as potential_issues,
    (select count(*) from public.bank_transactions t where t.organization_id = p_organization_id) as total_bank_transactions,
    (select count(*) from public.bank_transactions t
       where t.organization_id = p_organization_id
         and date_trunc('month', t.transaction_date) = date_trunc('month', current_date)
    ) as current_month_bank_transactions;
end;
$$;

grant execute on function public.get_dashboard_summary(uuid) to authenticated;
