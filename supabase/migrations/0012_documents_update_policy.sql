-- 0008_rls_policies.sql defined SELECT/INSERT/DELETE for `documents` but
-- missed UPDATE — silently dropped to 0 rows affected (not an error) every
-- time the upload flow tried to set storage_path/document_hash/
-- file_size_bytes after the storage upload completed, leaving
-- storage_path empty and breaking extract-invoice's page lookup.
create policy "documents_update_non_viewer" on public.documents
  for update using (public.has_org_role(organization_id, array['owner', 'admin', 'accountant', 'member']));
