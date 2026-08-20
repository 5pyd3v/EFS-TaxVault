-- Two changes:
--
-- 1. delete_invoice/delete_bank_transaction (0019/0020, security-fixed in
--    0031) currently let any member delete their own `needs_review` row,
--    but require owner/admin for anything already decided (`verified` or
--    `rejected`). Under the new dispute/rescan workflow, `rejected` means
--    "admin flagged this as wrong" — and the whole point of that flag is
--    for the ORIGINAL SUBMITTER to rescan and fix it, which starts with
--    deleting the disputed record. Relaxed so the creator can delete their
--    own disputed row too. `verified` stays owner/admin-only — that's the
--    legacy one-shot-locked status from before this workflow existed, and
--    stays maximally protected.
--
-- 2. New delete_organization RPC for the platform-admin dashboard — full
--    account removal, not just blocking. Every organization-scoped table
--    already cascades from `organizations` (confirmed directly against
--    pg_constraint before writing this), so a plain delete would work —
--    except log_membership_audit_event() fires an AFTER DELETE trigger on
--    organization_members that INSERTs into audit_logs referencing
--    organization_id, and if that cascade-delete of organization_members
--    happens as part of the SAME statement that's also removing the
--    parent organizations row, the insert can lose the race and violate
--    audit_logs' own FK. Deleting organization_members in its own
--    statement first (same fix already applied by hand once this session
--    for a stray test org) avoids it. User accounts are deliberately left
--    alone — a deleted org's former members just become org-less
--    ("incomplete signup"-style) accounts, not deleted people; that's a
--    separate, explicit action (delete-platform-user Edge Function).

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
  v_created_by uuid;
begin
  select organization_id, document_id, verification_status, created_by
    into v_org_id, v_document_id, v_status, v_created_by
  from public.invoices
  where id = p_invoice_id;

  if v_org_id is null then
    raise exception 'invoice not found';
  end if;

  if not public.is_org_member(v_org_id) then
    raise exception 'not authorized';
  end if;

  if v_status = 'verified' and not public.has_org_role(v_org_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;
  if v_status = 'rejected'
     and v_created_by is distinct from auth.uid()
     and not public.has_org_role(v_org_id, array['owner', 'admin']) then
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
  v_created_by uuid;
begin
  select organization_id, document_id, verification_status, created_by
    into v_org_id, v_document_id, v_status, v_created_by
  from public.bank_transactions
  where id = p_transaction_id;

  if v_org_id is null then
    raise exception 'transaction not found';
  end if;

  if not public.is_org_member(v_org_id) then
    raise exception 'not authorized';
  end if;

  if v_status = 'verified' and not public.has_org_role(v_org_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;
  if v_status = 'rejected'
     and v_created_by is distinct from auth.uid()
     and not public.has_org_role(v_org_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;

  delete from public.bank_transactions where id = p_transaction_id;

  if v_document_id is not null then
    delete from public.documents where id = v_document_id;
  end if;
end;
$$;

create or replace function public.delete_organization(p_organization_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'not authorized';
  end if;

  delete from public.organization_members where organization_id = p_organization_id;
  delete from public.organizations where id = p_organization_id;
end;
$$;

revoke all on function public.delete_organization(uuid) from public;
grant execute on function public.delete_organization(uuid) to authenticated;
