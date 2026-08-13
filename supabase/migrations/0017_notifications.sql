-- Notifies the responsible user when something needs their attention —
-- a calculation mismatch on an invoice they created, or a document they
-- uploaded that failed AI processing. Written by triggers only (no INSERT
-- policy for `authenticated` on notifications, mirroring audit_logs).

create or replace function public.notify_calculation_mismatch()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.calculation_mismatch
     and (TG_OP = 'INSERT' or old.calculation_mismatch is distinct from new.calculation_mismatch) then
    insert into public.notifications (organization_id, user_id, type, title, body, data)
    values (
      new.organization_id,
      new.created_by,
      'calculation_mismatch',
      'Potential calculation mismatch',
      'Invoice ' || coalesce(new.invoice_number, '(no number)') ||
        ' may have a tax calculation mismatch — please verify.',
      jsonb_build_object('invoice_id', new.id)
    );
  end if;
  return new;
end;
$$;

create trigger notify_invoice_calculation_mismatch
  after insert or update on public.invoices
  for each row execute function public.notify_calculation_mismatch();

create or replace function public.notify_extraction_failed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uploaded_by uuid;
begin
  if new.status = 'failed' and (old.status is distinct from 'failed') then
    select uploaded_by into v_uploaded_by from public.documents where id = new.document_id;
    if v_uploaded_by is not null then
      insert into public.notifications (organization_id, user_id, type, title, body, data)
      values (
        new.organization_id,
        v_uploaded_by,
        'extraction_failed',
        'Could not analyze a document',
        coalesce(new.error_message, 'The document could not be processed. You can retry from the vault.'),
        jsonb_build_object('document_id', new.document_id, 'job_id', new.id)
      );
    end if;
  end if;
  return new;
end;
$$;

create trigger notify_ai_job_failed
  after update on public.ai_processing_jobs
  for each row execute function public.notify_extraction_failed();
