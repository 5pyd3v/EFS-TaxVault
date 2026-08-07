-- Dashboard aggregates, computed in Postgres so the numbers the app shows
-- always agree with reports/tax calculations (spec §18, §27: "all
-- calculations must come from PostgreSQL/backend logic").

create or replace function public.get_dashboard_summary(p_organization_id uuid)
returns table (
  total_invoices bigint,
  current_month_invoices bigint,
  current_month_tax_amount numeric,
  pending_verification bigint,
  potential_issues bigint
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
    count(*) as total_invoices,
    count(*) filter (
      where date_trunc('month', i.invoice_date) = date_trunc('month', current_date)
    ) as current_month_invoices,
    coalesce(sum(i.sales_tax + i.other_taxes) filter (
      where date_trunc('month', i.invoice_date) = date_trunc('month', current_date)
    ), 0) as current_month_tax_amount,
    count(*) filter (where i.verification_status = 'needs_review') as pending_verification,
    count(*) filter (
      where i.calculation_mismatch
         or exists (
              select 1 from public.ai_warnings w
              where w.invoice_id = i.id and not w.resolved and w.severity in ('warning', 'error')
            )
    ) as potential_issues
  from public.invoices i
  where i.organization_id = p_organization_id;
end;
$$;

grant execute on function public.get_dashboard_summary(uuid) to authenticated;
