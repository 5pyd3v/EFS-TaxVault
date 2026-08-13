-- Groups invoices by supplier so a user can see "how many invoices from
-- this vendor" at a glance instead of scrolling the full list (spec §14-15
-- intent: smart categorization/search). Computed in Postgres like every
-- other report figure — never client-aggregated.

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
  group by 1, 2
  order by purchases_total desc;
end;
$$;

grant execute on function public.get_supplier_summaries(uuid) to authenticated;
