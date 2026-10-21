-- Fraud Signal platform schema.
-- Row-level security scopes every table to the signed-in user's organization.
-- Names and ancestry never feed a score; this schema stores engine output and
-- access records only.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Organizations and profiles
-- ---------------------------------------------------------------------------
create type offer_tier as enum (
  'diligenceScreen', 'complianceSelfAudit', 'screeningSubscription', 'exclusiveCasePackage', 'internal'
);
create type user_role as enum ('viewer', 'analyst', 'reviewer', 'admin');

create table organizations (
  id text primary key,
  name text not null,
  offer offer_tier not null,
  identity_verified boolean not null default false,
  seats int not null default 1,
  own_npis text[] not null default '{}',
  created_at timestamptz not null default now()
);

-- One row per auth user. Invite-only: rows are created by an admin, never by sign-up.
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null,
  role user_role not null default 'viewer',
  org_id text not null references organizations(id),
  created_at timestamptz not null default now()
);

create or replace function current_org_id() returns text
language sql stable security definer set search_path = public as $$
  select org_id from profiles where id = auth.uid()
$$;

create or replace function current_role_name() returns user_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid()
$$;

create or replace function current_offer() returns offer_tier
language sql stable security definer set search_path = public as $$
  select o.offer from profiles p join organizations o on o.id = p.org_id where p.id = auth.uid()
$$;

-- ---------------------------------------------------------------------------
-- Engine output
-- ---------------------------------------------------------------------------
create type program as enum ('medicare', 'ppp', 'childCare', 'all');
create type lead_status as enum ('watchList', 'pendingReview', 'signedOff', 'licensed', 'reserved', 'closed');

create table rules (
  id text primary key,
  name text not null,
  program program not null,
  tier smallint not null check (tier between 1 and 3),
  why_it_holds text not null,
  status text not null,
  lift numeric,
  lift_low numeric,
  lift_high numeric,
  status_note text
);

create table leads (
  id text primary key,
  program program not null,
  entity_ref text not null,
  entity_kind text not null,
  state text not null,
  specialty_or_industry text not null,
  dollars_at_issue numeric not null,
  status lead_status not null default 'pendingReview',
  hits jsonb not null,                   -- [{ruleId, tier, headline, rawValues, peerDistribution?, subjectValue?}]
  innocent_explanations jsonb not null,  -- [{explanation, whyItFails}]
  provenance jsonb not null,             -- {sourceName, sourceUrl, datasetVersion, query, rowCount, sha256, pulledAt, rulesetVersion}
  licensed_to_org_id text references organizations(id),
  signed_off_by text,
  signed_off_at timestamptz,
  investigation_notes text,
  first_viewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index leads_licensed_idx on leads (licensed_to_org_id);
create index leads_status_idx on leads (status);

create table backtest_rows (
  id serial primary key,
  rule text not null,
  tier_label text not null,
  flagged int not null,
  later_excluded int not null,
  lift numeric not null,
  lift_low numeric not null,
  lift_high numeric not null,
  ruleset_version text not null
);

create table ppp_scan_rows (
  id serial primary key,
  rule text not null,
  loans_flagged text not null,
  approved_amount numeric not null,
  note text not null
);

create table data_sources (
  id serial primary key,
  name text not null,
  publisher text not null,
  holds text not null,
  pulled text not null,
  limits text not null,
  url text not null default '',
  live boolean not null default false
);

create table bias_audit_runs (
  id text primary key,
  run_at timestamptz not null,
  ruleset_version text not null,
  census_vintage text not null,
  inputs_banned text[] not null,
  rows jsonb not null  -- [{ruleId, ruleName, flagRateHighMinorityZips, flagRateOtherZips, verdict, note}]
);

create table heatmap_cells (
  state text primary key,
  providers_scored int not null,
  flags_per_1000 numeric not null,
  dollars_at_issue numeric not null
);

-- ---------------------------------------------------------------------------
-- Screens and access log
-- ---------------------------------------------------------------------------
create table screen_requests (
  id text primary key default ('S-' || substr(gen_random_uuid()::text, 1, 8)),
  kind text not null check (kind in ('diligence', 'selfAudit')),
  npis text[] not null,
  target_label text,
  requested_by uuid not null references profiles(id),
  org_id text not null references organizations(id),
  requested_at timestamptz not null default now(),
  status text not null default 'queued',
  result jsonb
);

create table access_log (
  id bigserial primary key,
  at timestamptz not null default now(),
  user_id uuid not null references profiles(id),
  user_email text not null,
  org_id text not null references organizations(id),
  action text not null,
  lead_id text references leads(id),
  detail text
);
create index access_log_org_idx on access_log (org_id, at desc);
create index access_log_lead_idx on access_log (lead_id);

-- First view by a licensee stamps the handoff.
create or replace function stamp_first_view() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.action = 'viewedLead' and new.lead_id is not null then
    update leads set first_viewed_at = coalesce(first_viewed_at, new.at) where id = new.lead_id;
  end if;
  return new;
end $$;
create trigger access_log_first_view after insert on access_log
for each row execute function stamp_first_view();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
alter table organizations enable row level security;
alter table profiles enable row level security;
alter table rules enable row level security;
alter table leads enable row level security;
alter table backtest_rows enable row level security;
alter table ppp_scan_rows enable row level security;
alter table data_sources enable row level security;
alter table bias_audit_runs enable row level security;
alter table heatmap_cells enable row level security;
alter table screen_requests enable row level security;
alter table access_log enable row level security;

create policy "own org" on organizations for select using (id = current_org_id());
create policy "own profile or same org admin" on profiles for select
  using (id = auth.uid() or (org_id = current_org_id() and current_role_name() in ('admin', 'reviewer')));

-- Reference data is readable by every signed-in user. The heatmap is also the
-- public layer; expose it through a view or edge function without names.
create policy "signed in" on rules for select using (auth.uid() is not null);
create policy "signed in" on backtest_rows for select using (auth.uid() is not null);
create policy "signed in" on ppp_scan_rows for select using (auth.uid() is not null);
create policy "signed in" on data_sources for select using (auth.uid() is not null);
create policy "signed in" on bias_audit_runs for select using (auth.uid() is not null);
create policy "anyone" on heatmap_cells for select using (true);

-- Leads: what an organization sees depends on its offer.
create policy "leads by offer" on leads for select using (
  case current_offer()
    when 'internal' then true
    when 'exclusiveCasePackage' then licensed_to_org_id = current_org_id()
    when 'screeningSubscription' then status in ('signedOff', 'watchList')
    when 'complianceSelfAudit' then exists (
      select 1 from organizations o where o.id = current_org_id()
        and exists (select 1 from unnest(o.own_npis) n where leads.entity_ref like '%' || n || '%'))
    else false
  end
);
create policy "reviewers update" on leads for update
  using (current_offer() = 'internal' and current_role_name() = 'reviewer');

create policy "own org screens" on screen_requests for select using (org_id = current_org_id());
create policy "run screens" on screen_requests for insert
  with check (org_id = current_org_id() and requested_by = auth.uid() and current_role_name() <> 'viewer');

create policy "read log" on access_log for select using (
  current_offer() = 'internal'
  or (org_id = current_org_id() and current_role_name() in ('admin', 'reviewer'))
  or user_id = auth.uid()
);
create policy "append log" on access_log for insert
  with check (user_id = auth.uid() and org_id = current_org_id());
-- No update or delete policies on access_log: it is append-only.
