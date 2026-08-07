-- Identity, tenancy, and plan tables.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  avatar_url text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null check (type in ('individual', 'business')),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'accountant', 'member', 'viewer')),
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create index idx_organization_members_org on public.organization_members (organization_id);
create index idx_organization_members_user on public.organization_members (user_id);

-- Invoice/document categories. `is_system` rows (Utilities, Rent, ...) ship
-- with every organization; users can add their own alongside them.
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  unique (organization_id, name)
);

-- Plan/limits are configuration, not code — the app must not hard-code
-- per-plan behavior beyond reading these columns (spec §32).
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null unique references public.organizations (id) on delete cascade,
  plan text not null default 'free'
    check (plan in ('free', 'starter', 'business', 'professional', 'enterprise')),
  status text not null default 'active' check (status in ('active', 'past_due', 'canceled')),
  limits jsonb not null default '{}'::jsonb,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
