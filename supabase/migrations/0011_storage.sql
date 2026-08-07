-- Private storage for scanned documents (spec §24: private storage, signed
-- URLs — never a public bucket). Objects are stored at
-- `{organization_id}/{document_id}/{filename}`, so RLS on storage.objects
-- can reuse the same is_org_member/has_org_role helpers by reading the
-- first path segment via storage.foldername(name).

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

create policy "documents_bucket_select_member" on storage.objects
  for select using (
    bucket_id = 'documents'
    and public.is_org_member((storage.foldername(name))[1]::uuid)
  );

create policy "documents_bucket_insert_non_viewer" on storage.objects
  for insert with check (
    bucket_id = 'documents'
    and public.has_org_role(
      (storage.foldername(name))[1]::uuid,
      array['owner', 'admin', 'accountant', 'member']
    )
  );

create policy "documents_bucket_delete_non_viewer" on storage.objects
  for delete using (
    bucket_id = 'documents'
    and public.has_org_role(
      (storage.foldername(name))[1]::uuid,
      array['owner', 'admin', 'accountant', 'member']
    )
  );
