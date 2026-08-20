-- Text-only update: the app's UI now calls a 'rejected' verification_status
-- "disputed" everywhere (workflow redesign — every scan is auto-accepted on
-- submission, an admin's "reject" is now framed as raising a dispute the
-- submitter resolves by rescanning). This just brings the notification
-- title/body sent when that happens in line with that language. Deliberately
-- leaves the `type` column values ('invoice_rejected'/'bank_transaction_
-- rejected') and the 'verified' branch untouched — the type strings are
-- read by the client's icon switch (notifications_screen.dart) and
-- historical rows already use them, and 'verified' is only ever set by
-- pre-existing rows now (no client code path sets it going forward).

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
      case when new.verification_status = 'verified' then 'Invoice approved' else 'Invoice disputed' end,
      'Invoice ' || coalesce(new.invoice_number, '(no number)') ||
        case when new.verification_status = 'verified' then ' was approved by your admin.'
             else coalesce(' was disputed: ' || new.rejection_reason, ' was disputed by your admin. You can rescan it.') end,
      jsonb_build_object('invoice_id', new.id)
    );
  end if;
  return new;
end;
$$;

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
      case when new.verification_status = 'verified' then 'Transaction approved' else 'Transaction disputed' end,
      'Transaction ' || coalesce(new.reference_number, '(no reference)') ||
        case when new.verification_status = 'verified' then ' was approved by your admin.'
             else coalesce(' was disputed: ' || new.rejection_reason, ' was disputed by your admin. You can rescan it.') end,
      jsonb_build_object('transaction_id', new.id)
    );
  end if;
  return new;
end;
$$;
