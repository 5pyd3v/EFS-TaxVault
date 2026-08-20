-- The superadmin dashboard is built around organizations, so a user who
-- signed up (has an auth.users + profiles row) but never finished
-- onboarding — never created or joined an org — was completely invisible
-- there, even though they're a real account. That's useful information
-- for account management (who tried the app and dropped off), so this
-- surfaces them explicitly rather than silently excluding them.
--
-- Same account-metadata-only scope as list_all_organizations: name, email,
-- signup date. No financial data, because there isn't any — an org-less
-- user has never been able to scan anything (every scan is org-scoped).
create or replace function public.list_incomplete_signups()
returns table (
  user_id uuid,
  full_name text,
  email text,
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
  select u.id, p.full_name, u.email::text, u.created_at
  from auth.users u
  left join public.profiles p on p.id = u.id
  where not exists (
    select 1 from public.organization_members m where m.user_id = u.id
  )
  -- A platform admin themselves is org-less by design (0033_platform_admins.sql)
  -- and isn't a "dropped off signup" — exclude them from this list.
  and not exists (
    select 1 from public.platform_admins pa where pa.user_id = u.id
  )
  order by u.created_at desc;
end;
$$;

revoke all on function public.list_incomplete_signups() from public;
grant execute on function public.list_incomplete_signups() to authenticated;
