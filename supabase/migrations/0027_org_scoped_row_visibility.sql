-- Narrows who can SELECT which rows: owner/admin still see everything in
-- their org (needed for the approval flow), every other role now sees only
-- rows they created/uploaded themselves. INSERT/UPDATE/DELETE policies are
-- untouched.
--
-- Provably a no-op for every org that exists today (verified via
-- `select organization_id, count(*) from organization_members group by 1
-- having count(*) > 1` — zero rows returned, i.e. every org currently has
-- exactly one member, who is always its owner) and mathematically a no-op
-- for any future individual-type org, since those only ever have the
-- single owner as a member.

drop policy "documents_select_member" on public.documents;
create policy "documents_select_scoped" on public.documents
  for select using (
    public.is_org_member(organization_id)
    and (public.has_org_role(organization_id, array['owner', 'admin']) or uploaded_by = auth.uid())
  );

drop policy "invoices_select_member" on public.invoices;
create policy "invoices_select_scoped" on public.invoices
  for select using (
    public.is_org_member(organization_id)
    and (public.has_org_role(organization_id, array['owner', 'admin']) or created_by = auth.uid())
  );

drop policy "bank_transactions_select_member" on public.bank_transactions;
create policy "bank_transactions_select_scoped" on public.bank_transactions
  for select using (
    public.is_org_member(organization_id)
    and (public.has_org_role(organization_id, array['owner', 'admin']) or created_by = auth.uid())
  );

drop policy "invoice_items_select_member" on public.invoice_items;
create policy "invoice_items_select_scoped" on public.invoice_items
  for select using (
    exists (
      select 1 from public.invoices i
      where i.id = invoice_items.invoice_id
        and public.is_org_member(i.organization_id)
        and (public.has_org_role(i.organization_id, array['owner', 'admin']) or i.created_by = auth.uid())
    )
  );

-- Storage RLS mirrors the documents-table rule — without this, a member
-- could still read another member's scanned image bytes by document_id
-- even though the corresponding `documents` row is no longer visible to
-- them. Path shape is `{organization_id}/{document_id}/{filename}`
-- (0011_storage.sql).
drop policy "documents_bucket_select_member" on storage.objects;
create policy "documents_bucket_select_scoped" on storage.objects
  for select using (
    bucket_id = 'documents'
    and exists (
      select 1 from public.documents d
      where d.id = (storage.foldername(name))[2]::uuid
        and d.organization_id = (storage.foldername(name))[1]::uuid
        and (public.has_org_role(d.organization_id, array['owner', 'admin']) or d.uploaded_by = auth.uid())
    )
  );
