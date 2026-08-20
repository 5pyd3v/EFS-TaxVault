-- Restricts who may transition verification_status away from
-- 'needs_review': only owner/admin. Everyone else can still edit/save
-- their own not-yet-verified rows to fix OCR mistakes — they just can't
-- flip the status themselves anymore (previously any non-viewer role
-- could self-verify their own or anyone else's invoice).
--
-- Implemented as a BEFORE UPDATE trigger rather than an RLS `with check`,
-- since RLS can't diff OLD vs NEW in one expression.

alter table public.invoices add column rejection_reason text;
alter table public.bank_transactions add column rejection_reason text;

-- Deliberately does NOT raise an exception for an unauthorized change — it
-- silently reverts verification_status/verified_by/verified_at to their
-- previous values and lets every OTHER edited column in the same UPDATE
-- statement save normally. This app has no forced-update mechanism, so an
-- old client build (still calling the pre-rollout "Confirm & Save" path)
-- must keep working without a raw Postgres error reaching an active user
-- mid-scan: their edits still save, and the row correctly stays
-- needs_review (i.e. lands in the admin's approval queue) until they
-- update.
create or replace function public.enforce_verification_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verification_status is distinct from old.verification_status then
    if public.has_org_role(new.organization_id, array['owner', 'admin']) then
      if new.verification_status in ('verified', 'rejected') then
        new.verified_by := auth.uid();
        new.verified_at := now();
      else
        new.verified_by := null;
        new.verified_at := null;
      end if;
    else
      new.verification_status := old.verification_status;
      new.verified_by := old.verified_by;
      new.verified_at := old.verified_at;
      new.rejection_reason := old.rejection_reason;
    end if;
  end if;
  return new;
end;
$$;

create trigger enforce_invoice_verification_status
  before update on public.invoices
  for each row execute function public.enforce_verification_status_change();

create trigger enforce_bank_transaction_verification_status
  before update on public.bank_transactions
  for each row execute function public.enforce_verification_status_change();

-- Tells the submitter when their item was decided, mirroring the existing
-- notify_calculation_mismatch pattern (0017). Runs AFTER UPDATE, so it
-- always sees the final (possibly reverted-by-the-trigger-above) values —
-- same ordering already relied on by audit_invoices/
-- notify_invoice_calculation_mismatch, both also AFTER UPDATE.
create or replace function public.notify_invoice_verification_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verification_status is distinct from old.verification_status
     and new.verification_status in ('verified', 'rejected')
     and new.created_by is distinct from auth.uid() then
    insert into public.notifications (organization_id, user_id, type, title, body, data)
    values (
      new.organization_id, new.created_by,
      case when new.verification_status = 'verified' then 'invoice_verified' else 'invoice_rejected' end,
      case when new.verification_status = 'verified' then 'Invoice approved' else 'Invoice rejected' end,
      'Invoice ' || coalesce(new.invoice_number, '(no number)') ||
        case when new.verification_status = 'verified' then ' was approved by your admin.'
             else coalesce(' was rejected: ' || new.rejection_reason, ' was rejected by your admin.') end,
      jsonb_build_object('invoice_id', new.id)
    );
  end if;
  return new;
end;
$$;

create trigger notify_invoice_verification_decision
  after update on public.invoices
  for each row execute function public.notify_invoice_verification_decision();

create or replace function public.notify_bank_transaction_verification_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verification_status is distinct from old.verification_status
     and new.verification_status in ('verified', 'rejected')
     and new.created_by is distinct from auth.uid() then
    insert into public.notifications (organization_id, user_id, type, title, body, data)
    values (
      new.organization_id, new.created_by,
      case when new.verification_status = 'verified' then 'bank_transaction_verified' else 'bank_transaction_rejected' end,
      case when new.verification_status = 'verified' then 'Transaction approved' else 'Transaction rejected' end,
      'Transaction ' || coalesce(new.reference_number, '(no reference)') ||
        case when new.verification_status = 'verified' then ' was approved by your admin.'
             else coalesce(' was rejected: ' || new.rejection_reason, ' was rejected by your admin.') end,
      jsonb_build_object('transaction_id', new.id)
    );
  end if;
  return new;
end;
$$;

create trigger notify_bank_transaction_verification_decision
  after update on public.bank_transactions
  for each row execute function public.notify_bank_transaction_verification_decision();
