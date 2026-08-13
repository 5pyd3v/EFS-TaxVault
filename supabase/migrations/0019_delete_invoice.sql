-- Lets a user permanently remove an invoice — either one they explicitly
-- choose to delete from the Vault, or one they never confirmed (AI
-- extraction creates the invoices row immediately on upload, before
-- review, so backing out of Review without saving previously left a
-- needs_review row behind forever with no way to remove it).
--
-- invoice_items/tax_records/ai_warnings/fbr_submissions all reference
-- invoices with `on delete cascade`, so deleting the invoice row cleans
-- those up automatically. The documents row is a separate delete here
-- since invoices.document_id is `on delete set null`, not cascade — the
-- actual Storage objects (page_1.jpg, page_2.jpg, ...) are removed by the
-- Flutter client before calling this, since Storage objects aren't
-- reachable from plain SQL.

create or replace function public.delete_invoice(p_invoice_id uuid)
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
  from public.invoices
  where id = p_invoice_id;

  if v_org_id is null then
    raise exception 'invoice not found';
  end if;

  if not public.is_org_member(v_org_id) then
    raise exception 'not authorized';
  end if;

  delete from public.invoices where id = p_invoice_id;

  if v_document_id is not null then
    delete from public.documents where id = v_document_id;
  end if;
end;
$$;

grant execute on function public.delete_invoice(uuid) to authenticated;
