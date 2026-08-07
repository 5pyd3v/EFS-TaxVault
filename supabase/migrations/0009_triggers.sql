-- Auth bridge, updated_at maintenance, and organization creation.

-- Creates the public.profiles row the moment a user signs up. Deliberately
-- does NOT create an organization — onboarding is a user-driven step
-- (individual vs business), not something to guess at signup time.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create trigger set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.organizations
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.subscriptions
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.suppliers
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.customers
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.invoices
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.fbr_submissions
  for each row execute function public.set_updated_at();

-- Atomically creates an organization, makes the caller its owner, and
-- starts it on the free plan. This is the ONLY way an organization can be
-- created (see the missing INSERT policy on organizations/
-- organization_members in 0008_rls_policies.sql) — it exists specifically
-- so an organization can never end up without an owner membership row.
create or replace function public.create_organization_with_owner(org_name text, org_type text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_org_id uuid;
begin
  if org_type not in ('individual', 'business') then
    raise exception 'invalid organization type: %', org_type;
  end if;

  if auth.uid() is null then
    raise exception 'must be authenticated to create an organization';
  end if;

  insert into public.organizations (name, type, created_by)
  values (org_name, org_type, auth.uid())
  returning id into new_org_id;

  insert into public.organization_members (organization_id, user_id, role)
  values (new_org_id, auth.uid(), 'owner');

  insert into public.subscriptions (organization_id, plan)
  values (new_org_id, 'free');

  return new_org_id;
end;
$$;

grant execute on function public.create_organization_with_owner(text, text) to authenticated;
