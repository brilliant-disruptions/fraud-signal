# Fraud Signal

Invite-only mobile client for the Fraud Signal Engine: tiered rules, a lead gate, and an evidence card on every flag. The product sells **risk indicators with evidence, never accusations**, and no name ever appears publicly. The product plan this app is built from is in [`docs/product-plan.md`](docs/product-plan.md).

Flutter, mobile first (Android and iOS), with a web build for demos.

## What the app does

| Area | Screen | Notes |
| --- | --- | --- |
| Access | Sign in | Invite-only. No self-serve sign-up. Organization accounts with roles (viewer, analyst, reviewer, admin) and an offer tier (diligence screen, compliance self-audit, screening subscription, exclusive case package, internal). |
| Leads | Home, Leads, Evidence card | Leads above the gate, strongest tier first. Opening a lead logs a timestamped view; the first view by a licensee is the documented handoff. The card shows the lead gate, every signal with raw values and peer distribution, the innocent-explanation checklist, and the full audit trail (source, dataset version, query, row count, SHA-256, ruleset). Watermarked with viewer and time. Exports are logged; no bulk export on the case-package tier. |
| Review | Evidence card (reviewers) | Sign off, license exclusively to one firm, or close with the innocent explanation that held. |
| Screens | Screens, New screen | Diligence screens on a target's NPIs and compliance self-audits on an org's verified NPIs. NPI check digit validated on device. |
| Method | Rules, Back-test, Bias audit, Heatmap | 15 signals across three tiers with measured lift and 95% intervals; back-test and PPP scan tables; bias audit by ZIP demographics; the aggregate no-names state heatmap that is the only public layer. |
| Account | Account | Org, plan, role, access log (org-wide for admins and reviewers), data sources with their limits, legal guardrails. |

The Tier 1 rules and the lead gate also run on the device (`lib/domain/rules_engine.dart`) so any evidence card can be re-checked from its raw values. They are covered by `test/rules_engine_test.dart` and must agree with the server engine on every case.

## Run it

Install Flutter 3.47 or newer, then:

```sh
flutter pub get
flutter run                       # demo mode, in-memory synthetic data
```

Demo accounts (password `demo`):

| Email | Org | Plan | Role |
| --- | --- | --- | --- |
| reviewer@demo.fraudsignal | Brilliant Disruptions | Internal | Reviewer (can sign off, license, close) |
| analyst@demo.fraudsignal | Brilliant Disruptions | Internal | Analyst (runs screens) |
| counsel@demo.fraudsignal | Harbor & Vale LLP (demo) | Exclusive case package | Viewer (sees only leads licensed to the firm) |
| compliance@demo.fraudsignal | Cumberland Health Partners (demo) | Compliance self-audit | Admin (self-audits on owned NPIs) |

Every identifier in the demo data is synthetic. The rule catalog, back-test numbers and data source table are the measured results from the plan.

### Production backend (Supabase)

```sh
flutter run --dart-define=SUPABASE_URL=https://<project>.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

Apply `supabase/migrations/0001_schema.sql` to the project. Access control lives in the database as row-level security: what an organization can read depends on its offer tier, the access log is append-only, and a trigger stamps a lead's first view. Profiles are created by an admin, never by sign-up, which keeps the platform invite-only. `supabase/seed.sql` loads the reference tables.

## Checks

```sh
flutter analyze
flutter test
flutter build web --release        # optional, for a browser demo
flutter build web --release --dart-define=DEMO_AUTO_SIGNIN=reviewer@demo.fraudsignal   # pre-signed-in demo
```

## Layout

```
lib/
  core/        config, theme, formatters, Riverpod providers
  domain/      models, rules engine
  data/        repository interface, demo repository, Supabase repository, demo data
  features/    one folder per screen group
  widgets/     shared widgets, watermark, charts
supabase/      schema with RLS, seed
docs/          product plan
test/          rules engine and app smoke tests
```
