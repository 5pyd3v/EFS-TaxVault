-- Per-user Gemini key override, additive on top of the existing per-org
-- key (0021_organization_ai_keys.sql). Resolution order (in
-- gemini_key.ts): the row's uploader's own key first, falling back to the
-- organization's key when the uploader has none. Individual accounts and
-- business admins who never set a personal key are entirely unaffected —
-- they keep using the org key exactly as before.

create table public.user_ai_keys (
  user_id uuid primary key references auth.users (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  gemini_api_key text not null,
  is_valid boolean not null default true,
  last_error text,
  last_validated_at timestamptz,
  updated_at timestamptz not null default now(),
  updated_by uuid not null references auth.users (id)
);

create index idx_user_ai_keys_org on public.user_ai_keys (organization_id);

alter table public.user_ai_keys enable row level security;
-- Intentionally no policies for `authenticated` — same pattern as
-- organization_ai_keys, access only via the RPCs below.

create trigger set_updated_at before update on public.user_ai_keys
  for each row execute function public.set_updated_at();

create or replace function public.set_my_gemini_api_key(p_organization_id uuid, p_api_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trimmed text := trim(p_api_key);
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'not authorized';
  end if;
  if length(v_trimmed) < 10 then
    raise exception 'API key looks too short to be valid';
  end if;

  insert into public.user_ai_keys (user_id, organization_id, gemini_api_key, is_valid, last_error, updated_by)
  values (auth.uid(), p_organization_id, v_trimmed, true, null, auth.uid())
  on conflict (user_id) do update
    set gemini_api_key = excluded.gemini_api_key, is_valid = true, last_error = null,
        updated_at = now(), updated_by = excluded.updated_by;
end;
$$;

grant execute on function public.set_my_gemini_api_key(uuid, text) to authenticated;

create or replace function public.admin_set_member_gemini_key(p_user_id uuid, p_organization_id uuid, p_api_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trimmed text := trim(p_api_key);
begin
  if not public.has_org_role(p_organization_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;
  if length(v_trimmed) < 10 then
    raise exception 'API key looks too short to be valid';
  end if;

  insert into public.user_ai_keys (user_id, organization_id, gemini_api_key, is_valid, last_error, updated_by)
  values (p_user_id, p_organization_id, v_trimmed, true, null, auth.uid())
  on conflict (user_id) do update
    set gemini_api_key = excluded.gemini_api_key, is_valid = true, last_error = null,
        updated_at = now(), updated_by = excluded.updated_by;
end;
$$;

grant execute on function public.admin_set_member_gemini_key(uuid, uuid, text) to authenticated;

create or replace function public.get_my_gemini_key_status(p_organization_id uuid)
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
  select (k.user_id is not null), coalesce(k.is_valid, true), k.last_error, k.last_validated_at
  from (select auth.uid() as user_id) u
  left join public.user_ai_keys k on k.user_id = u.user_id and k.organization_id = p_organization_id;
end;
$$;

grant execute on function public.get_my_gemini_key_status(uuid) to authenticated;
