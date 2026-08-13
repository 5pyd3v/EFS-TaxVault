-- Audit trail (spec §25). Written entirely by triggers running as the
-- table owner (SECURITY DEFINER), never by client inserts — audit_logs has
-- no INSERT policy for `authenticated` (0008_rls_policies.sql), so this is
-- the only way a row can land there. auth.uid() is null for actions taken
-- by the extract-invoice Edge Function (service role, no user JWT), which
-- correctly reads as "the system did this" rather than attributing AI
-- actions to whichever user happened to trigger the job.

create or replace function public.log_invoice_audit_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
  v_metadata jsonb;
begin
  if TG_OP = 'INSERT' then
    insert into public.audit_logs (organization_id, user_id, action, entity_type, entity_id, metadata)
    values (
      new.organization_id, auth.uid(), 'invoice_created', 'invoices', new.id,
      jsonb_build_object(
        'invoice_number', new.invoice_number,
        'total_amount', new.total_amount,
        'verification_status', new.verification_status
      )
    );
    return new;
  elsif TG_OP = 'UPDATE' then
    if old.verification_status is distinct from 'verified' and new.verification_status = 'verified' then
      v_action := 'invoice_verified';
    else
      v_action := 'invoice_updated';
    end if;
    v_metadata := jsonb_build_object(
      'invoice_number', new.invoice_number,
      'total_amount', new.total_amount,
      'verification_status_before', old.verification_status,
      'verification_status_after', new.verification_status
    );
    insert into public.audit_logs (organization_id, user_id, action, entity_type, entity_id, metadata)
    values (new.organization_id, auth.uid(), v_action, 'invoices', new.id, v_metadata);
    return new;
  elsif TG_OP = 'DELETE' then
    insert into public.audit_logs (organization_id, user_id, action, entity_type, entity_id, metadata)
    values (
      old.organization_id, auth.uid(), 'invoice_deleted', 'invoices', old.id,
      jsonb_build_object('invoice_number', old.invoice_number, 'total_amount', old.total_amount)
    );
    return old;
  end if;
  return null;
end;
$$;

create trigger audit_invoices
  after insert or update or delete on public.invoices
  for each row execute function public.log_invoice_audit_event();

create or replace function public.log_document_audit_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_logs (organization_id, user_id, action, entity_type, entity_id, metadata)
  values (
    new.organization_id, auth.uid(), 'document_uploaded', 'documents', new.id,
    jsonb_build_object('document_type', new.document_type, 'capture_source', new.capture_source)
  );
  return new;
end;
$$;

create trigger audit_documents
  after insert on public.documents
  for each row execute function public.log_document_audit_event();

create or replace function public.log_extraction_audit_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_logs (organization_id, user_id, action, entity_type, entity_id, metadata)
  values (
    new.organization_id, auth.uid(), 'ai_extraction_performed', 'ai_extractions', new.id,
    jsonb_build_object(
      'model', new.model,
      'prompt_version', new.prompt_version,
      'processing_status', new.processing_status
    )
  );
  return new;
end;
$$;

create trigger audit_ai_extractions
  after insert on public.ai_extractions
  for each row execute function public.log_extraction_audit_event();

create or replace function public.log_fbr_submission_audit_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_logs (organization_id, user_id, action, entity_type, entity_id, metadata)
  values (
    new.organization_id, auth.uid(),
    case when TG_OP = 'INSERT' then 'fbr_submission_created' else 'fbr_submission_updated' end,
    'fbr_submissions', new.id,
    jsonb_build_object('status', new.status, 'external_reference', new.external_reference)
  );
  return new;
end;
$$;

create trigger audit_fbr_submissions
  after insert or update on public.fbr_submissions
  for each row execute function public.log_fbr_submission_audit_event();

create or replace function public.log_membership_audit_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'DELETE' then
    insert into public.audit_logs (organization_id, user_id, action, entity_type, entity_id, metadata)
    values (old.organization_id, auth.uid(), 'member_removed', 'organization_members', old.id,
      jsonb_build_object('member_user_id', old.user_id, 'role', old.role));
    return old;
  end if;

  insert into public.audit_logs (organization_id, user_id, action, entity_type, entity_id, metadata)
  values (
    new.organization_id, auth.uid(),
    case when TG_OP = 'INSERT' then 'member_added' else 'member_role_changed' end,
    'organization_members', new.id,
    jsonb_build_object('member_user_id', new.user_id, 'role', new.role)
  );
  return new;
end;
$$;

create trigger audit_organization_members
  after insert or update or delete on public.organization_members
  for each row execute function public.log_membership_audit_event();
