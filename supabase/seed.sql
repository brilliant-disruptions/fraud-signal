-- Reference data from the product plan (measured results, not demo leads).
insert into heatmap_cells (state, providers_scored, flags_per_1000, dollars_at_issue) values
  ('FL', 9120, 21.4, 61200000), ('TX', 8410, 18.9, 54000000), ('CA', 11230, 15.2, 58700000)
on conflict do nothing;

insert into backtest_rows (rule, tier_label, flagged, later_excluded, lift, lift_low, lift_high, ruleset_version) values
  ('Impossible hours, over 2,500 h', '1', 79, 2, 37, 10, 129, '2026.10.0'),
  ('Impossible hours, over 3,000 h', '1', 37, 1, 40, 7, 204, '2026.10.0'),
  ('Lead gate (Tier 1 or two Tier 2)', 'Combined', 178, 1, 8, 1.5, 46, '2026.10.0'),
  ('Visits per patient, 90837', '2', 185, 1, 7, 1.2, 37, '2026.10.0'),
  ('Visits per patient, 90834', '2', 195, 1, 6, 1.1, 35, '2026.10.0'),
  ('Visits per patient, 97110', '2', 665, 1, 3, 0.5, 16, '2026.10.0'),
  ('Any single Tier 2 signal', '2', 1907, 3, 2, 0.8, 6.8, '2026.10.0');
