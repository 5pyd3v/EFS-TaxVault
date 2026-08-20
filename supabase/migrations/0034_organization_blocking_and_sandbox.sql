-- Lets a platform admin suspend an organization (blocked at login — every
-- member is signed out and refused sign-in until unblocked) and spin up a
-- clean trial account for a prospect to test the app before buying.

alter table public.organizations add column is_blocked boolean not null default false;
alter table public.organizations add column blocked_at timestamptz;
alter table public.organizations add column blocked_reason text;
-- Purely a label for the superadmin dashboard and for keeping trial
-- accounts visually distinct from paying customers — does not restrict
-- functionality. A sandbox account works exactly like a normal individual
-- account, so a prospect experiences the real product, not a crippled demo.
alter table public.organizations add column is_sandbox boolean not null default false;

-- Account-metadata only (confirmed scope with the user): name, type,
-- owner, member count, status. Never touches invoices/documents/
-- bank_transactions/ai_extractions — a platform admin manages accounts,
-- not customer financial data.
create or replace function public.list_all_organizations()
returns table (
  organization_id uuid,
  name text,
  type text,
  owner_name text,
  owner_email text,
  member_count bigint,
  is_blocked boolean,
  is_sandbox boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    o.id,
    o.name,
    o.type,
    p.full_name,
    u.email::text,
    (select count(*) from public.organization_members m2 where m2.organization_id = o.id),
    o.is_blocked,
    o.is_sandbox,
    o.created_at
  from public.organizations o
  join public.organization_members m on m.organization_id = o.id and m.role = 'owner'
  join public.profiles p on p.id = m.user_id
  join auth.users u on u.id = m.user_id
  order by o.created_at desc;
end;
$$;

grant execute on function public.list_all_organizations() to authenticated;

create or replace function public.set_organization_blocked(
  p_organization_id uuid,
  p_blocked boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'not authorized';
  end if;

  update public.organizations
    set is_blocked = p_blocked,
        blocked_at = case when p_blocked then now() else null end,
        blocked_reason = case when p_blocked then p_reason else null end
    where id = p_organization_id;
end;
$$;

grant execute on function public.set_organization_blocked(uuid, boolean, text) to authenticated;

-- Mirrors finalize_team_member's atomic pattern (0025_team_pin_credentials.sql)
-- exactly, including WHO can call it: granted to service_role only, not
-- authenticated. This function does NOT re-check is_platform_admin()
-- itself — it can't meaningfully: create-sandbox-account invokes it via
-- the service-role client (needed to bypass RLS for the insert), and
-- auth.uid() resolves to NULL for a service-role call, so an internal
-- admin check here would always fail, not just for non-admins. The real
-- authorization check already happened earlier in the Edge Function, via
-- callerClient.rpc('is_platform_admin') using the CALLER's own JWT — this
-- function trusts that gate, the same way finalize_team_member trusts
-- create-team-member's earlier owner/admin check. The `service_role`-only
-- grant is what makes that safe: no other authenticated user can reach
-- this function directly to skip the check.
create or replace function public.finalize_sandbox_account(
  p_user_id uuid,
  p_organization_name text,
  p_created_by uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
begin
  insert into public.organizations (name, type, created_by, is_sandbox)
  values (p_organization_name, 'individual', p_user_id, true)
  returning id into v_org_id;

  insert into public.organization_members (organization_id, user_id, role)
  values (v_org_id, p_user_id, 'owner');

  return v_org_id;
end;
$$;

-- Postgres grants EXECUTE to PUBLIC by default on every new function —
-- that grant applies to every role (anon and authenticated included)
-- regardless of the service_role-only grant above, unless revoked
-- explicitly. See 0035_lock_down_service_role_only_functions.sql for the
-- full story (this line alone is what that migration's fix for this
-- function looks like, kept here so a fresh replay of migrations from
-- scratch is correct without depending on the later patch).
revoke all on function public.finalize_sandbox_account(uuid, text, uuid) from public;
grant execute on function public.finalize_sandbox_account(uuid, text, uuid) to service_role;
