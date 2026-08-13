-- Monthly/quarterly/annual tax-period summaries (spec §18). Grouped
-- directly off invoices.invoice_date via date_trunc rather than the
-- tax_periods table — nothing populates tax_periods yet (that's a Phase 11
-- FBR-period-alignment concern), and invoice_date is always known once an
-- invoice exists, so this is the simpler correct source today.

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
  group by 1
  order by 1 desc;
end;
$$;

grant execute on function public.get_period_summaries(uuid, text) to authenticated;
