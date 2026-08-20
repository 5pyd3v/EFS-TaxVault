-- Client-callable, owner/admin-gated team management RPCs. Same shape as
-- the existing set_gemini_api_key/get_gemini_key_status RPCs (0021):
-- member_pin_credentials/organization_members have zero client RLS
-- policies, so every read/write goes through a SECURITY DEFINER function
-- that checks has_org_role itself.

create or replace function public.list_team_members(p_organization_id uuid)
returns table (
  user_id uuid,
  full_name text,
  phone text,
  role text,
  is_pin_managed boolean,
  last_login_at timestamptz,
  member_since timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.has_org_role(p_organization_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;

  return query
  select m.user_id, p.full_name, p.phone, m.role,
         (c.user_id is not null), c.last_login_at, m.created_at
  from public.organization_members m
  join public.profiles p on p.id = m.user_id
  left join public.member_pin_credentials c on c.user_id = m.user_id
  where m.organization_id = p_organization_id
  order by m.created_at;
end;
$$;

grant execute on function public.list_team_members(uuid) to authenticated;

-- Server-generates a fresh 6-digit PIN (never accepts one from the
-- caller) and returns it once, plaintext, to the authorized admin.
create or replace function public.regenerate_member_pin(p_user_id uuid, p_organization_id uuid)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_pin text;
begin
  if not public.has_org_role(p_organization_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;
  if not exists (
    select 1 from public.member_pin_credentials
    where user_id = p_user_id and organization_id = p_organization_id
  ) then
    raise exception 'team member not found';
  end if;

  v_pin := lpad(floor(random() * 1000000)::text, 6, '0');
  update public.member_pin_credentials
    set pin_hash = crypt(v_pin, gen_salt('bf')), failed_attempts = 0, locked_until = null, updated_at = now()
    where user_id = p_user_id and organization_id = p_organization_id;
  return v_pin;
end;
$$;

grant execute on function public.regenerate_member_pin(uuid, uuid) to authenticated;

-- Revokes org access AND hard-locks the PIN credential (defense in depth —
-- even a lingering session on the removed device can never PIN-login
-- again).
create or replace function public.remove_team_member(p_user_id uuid, p_organization_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_org_role(p_organization_id, array['owner', 'admin']) then
    raise exception 'not authorized';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'cannot remove yourself';
  end if;

  delete from public.organization_members
    where organization_id = p_organization_id and user_id = p_user_id;

  update public.member_pin_credentials
    set locked_until = 'infinity'::timestamptz
    where user_id = p_user_id and organization_id = p_organization_id;
end;
$$;

grant execute on function public.remove_team_member(uuid, uuid) to authenticated;
