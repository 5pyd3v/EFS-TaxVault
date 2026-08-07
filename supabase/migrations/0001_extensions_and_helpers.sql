-- Extensions and shared helper functions used throughout the schema and by
-- the RLS policies in 0008_rls_policies.sql.

create extension if not exists "pgcrypto";

-- Generic updated_at maintenance, attached per-table in 0009_triggers.sql.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- True if the current auth user is a member of the given organization.
-- SECURITY DEFINER + a fixed search_path so it can be called from RLS
-- policies on any table without those tables needing to grant access to
-- organization_members directly.
create or replace function public.is_org_member(p_organization_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.organization_id = p_organization_id
      and m.user_id = auth.uid()
  );
$$;

-- True if the current auth user belongs to the organization with one of the
-- given roles. Used to restrict mutating policies (e.g. viewers cannot
-- insert/update invoices).
create or replace function public.has_org_role(p_organization_id uuid, p_roles text[])
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.organization_id = p_organization_id
      and m.user_id = auth.uid()
      and m.role = any(p_roles)
  );
$$;
