-- Per-organization Gemini API keys. Previously every org shared a single
-- Edge Function secret (GEMINI_API_KEY); orgs now bring their own key so
-- quota is per-org and a key never has to be revoked/rotated globally.
--
-- The raw key must never be readable by any client role — this table gets
-- RLS enabled with ZERO policies for `authenticated`, the same pattern used
-- for `organizations`/`organization_members` (0008_rls_policies.sql: "no
-- client-side INSERT policy... only happens through
-- create_organization_with_owner"). All client access goes through the two
-- SECURITY DEFINER RPCs below; Edge Functions read/write the table directly
-- via their service-role client, which bypasses RLS entirely already (same
-- as ai_processing_jobs writes).

create table public.organization_ai_keys (
  organization_id uuid primary key references public.organizations (id) on delete cascade,
  gemini_api_key text not null,
  is_valid boolean not null default true,
  last_error text,
  last_validated_at timestamptz,
  updated_at timestamptz not null default now(),
  updated_by uuid not null references auth.users (id)
);

alter table public.organization_ai_keys enable row level security;
-- Intentionally no policies for `authenticated` — see comment above.

create trigger set_updated_at before update on public.organization_ai_keys
  for each row execute function public.set_updated_at();

-- Adds/replaces the org's key. Owner/admin only, same role gate as
-- organizations_update_owner_admin.
create or replace function public.set_gemini_api_key(p_organization_id uuid, p_api_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trimmed text := trim(p_api_key);
begin
  if auth.uid() is null then
    raise exception 'must be authenticated';
  end if;
  if not public.has_org_role(p_organization_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;
  if length(v_trimmed) < 10 then
    raise exception 'API key looks too short to be valid';
  end if;

  insert into public.organization_ai_keys (organization_id, gemini_api_key, is_valid, last_error, updated_by)
  values (p_organization_id, v_trimmed, true, null, auth.uid())
  on conflict (organization_id) do update
    set gemini_api_key = excluded.gemini_api_key,
        is_valid = true,
        last_error = null,
        updated_at = now(),
        updated_by = excluded.updated_by;
end;
$$;

grant execute on function public.set_gemini_api_key(uuid, text) to authenticated;

-- Status only — never returns the key itself. Built from a single-row
-- subquery left-joined to the table so it always returns exactly one row
-- (has_key = false when no row exists yet), so callers can safely `.single()`.
create or replace function public.get_gemini_key_status(p_organization_id uuid)
returns table (has_key boolean, is_valid boolean, last_error text, last_validated_at timestamptz)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'not authorized';
  end if;

  return query
  select
    (k.organization_id is not null) as has_key,
    coalesce(k.is_valid, true) as is_valid,
    k.last_error,
    k.last_validated_at
  from (select p_organization_id as organization_id) o
  left join public.organization_ai_keys k on k.organization_id = o.organization_id;
end;
$$;

grant execute on function public.get_gemini_key_status(uuid) to authenticated;
