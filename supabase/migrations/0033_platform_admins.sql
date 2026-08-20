-- Platform-level operator role, sitting above every organization. Unlike
-- every other role in this app (owner/admin/accountant/member/viewer, all
-- scoped to one org), a platform admin manages the whole customer base:
-- seeing every org's basic account info and blocking/unblocking accounts.
--
-- Deliberately a dedicated table, not a JWT/user_metadata flag (the
-- pattern member_pin_credentials/is_pin_managed uses): a JWT-embedded flag
-- only updates when the token refreshes, so revoking this — the single
-- most sensitive permission in the app — wouldn't take effect until the
-- affected session naturally refreshes or expires. A table-backed check
-- queries live state every time and revokes instantly by deleting the row.
--
-- No insert/update/delete policy for `authenticated` at all, on purpose:
-- the ONLY way a row is ever created is a manual SQL insert run directly
-- by the developer. No signup flow, RPC, or Edge Function can ever grant
-- this from the client side.
create table public.platform_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  granted_by uuid references auth.users (id),
  granted_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;

-- Self-check only — a user can see whether THEY are a platform admin,
-- never the full roster (that visibility belongs to list_all_organizations
-- and similar RPCs, not a raw table read).
create policy "platform_admins_select_own" on public.platform_admins
  for select using (user_id = auth.uid());

-- Reusable helper, same shape/spirit as is_org_member/has_org_role
-- (0001_extensions_and_helpers.sql) — every superadmin-only RPC checks
-- this instead of has_org_role, since this permission isn't org-scoped.
create or replace function public.is_platform_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid());
$$;
