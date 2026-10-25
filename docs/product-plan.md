# Fraud Signal Engine: Build & Product Plan

Oct 20, 2026 · Jimmy Neyhart

## Summary

Build it as an invite-only, sign-in B2B platform. Start revenue with diligence screens and compliance self-audits, and keep the strongest leads for your own whistleblower filings. The engine works and is tested, but public data alone cannot prove fraud: trust comes from hard rules, measured lift and human review, not from statistics.

- **Engine:** tiered rules (hard rules, peer outliers, links), a lead gate, and an evidence card on every flag. Owner names and ancestry never feed a score, and every run is bias-audited. 13 automated tests pass, and a browser version of the rules matches the engine on every test case.
- **Data:** about 1.4 million records pulled from CMS, the HHS Inspector General and SBA on Oct 20, every count matching the publisher's.
- **Back-test:** the impossible-hours rule beat chance about 40 times (p = 0.02 at its preset 3,000-hour cut; p = 0.001 at 2,500 hours). Peer outliers alone ran 2 to 7 times chance and were not significant. Two rules were dropped, and the exclusion cross-match found one identity-verified case: an excluded provider paid about $392K in 2019.
- **Next:** a five-year back-test with DOJ case outcomes as labels, to tighten precision before the first sale.

## Data sources and access

The first four sources are free, official federal data; the last four are next, for the child care vertical, the network rule and the bias audit. On Oct 20 I pulled about 1.4 million records straight from their official endpoints, every count matching what the publisher reports. Production will run on a server that reaches these hosts directly.

| Source | Publisher | What it holds | Pulled | Limits |
| --- | --- | --- | --- | --- |
| [Physician & Other Practitioners, by Provider and Service, 2019](https://data.cms.gov/) | CMS | 10,140,228 rows: provider by billing code, with patients, services and average payment | 318,492 rows for the 14 test codes | Cells under 11 patients are suppressed |
| [Physician & Other Practitioners, by Provider, 2019](https://data.cms.gov/) | CMS | One row per provider: totals, plus average patient risk score | Queried for 4,161 excluded providers | Risk score is useful for fairer peer groups |
| [List of Excluded Individuals/Entities, 09-2026](https://oig.hhs.gov/exclusions/leie-database-supplement-downloads/) | HHS Office of Inspector General | 84,093 current exclusions, with legal basis and date | Full file | Only 8,924 records (10.6%) carry an NPI, so labels undercount |
| [PPP loan-level data, loans of $150K and up, Sept 2024 release](https://data.sba.gov/dataset/ppp-foia) | SBA | 968,524 loans totaling $515.5B: amount, jobs, industry, lender, draw, EIDL refinance | Full file (452 MB), streamed | Jobs are self-reported; race, ethnicity, gender and veteran columns are never read |
| Child care licensing and payment records | State human services agencies | Licensed capacity and inspections per site; payments per provider where released | Not yet | Licensing lookups are usually public; payments often need a public-records request, so file early |
| Child nutrition program sites and claims | State agencies that run USDA meal programs | Sponsors, sites, and meals claimed by site and month | Not yet | Usually by public-records request; detail varies by state |
| Business registries | Secretaries of state | Formation date, officers, registered agent and address for the network rule | Not yet | Format differs by state; some sell bulk files |
| American Community Survey | U.S. Census Bureau | Area demographics by ZIP code | Not yet | Used only for the bias audit, never as a score input |

The CMS API filters and selects columns on the server, so the engine pulls only what each rule needs. Every pull is saved with its source URL, query, row count and a SHA-256 hash, so any lead can be re-derived later.

## Detection method

The engine flags only what a reviewer can re-check from the record: hard rule violations first, peer-adjusted outliers second, and never one statistic on its own.

**Tier 1, hard rules.** A program rule or arithmetic makes the record impossible as reported. Innocent explanations are rare, so these carry the most weight.

**Tier 2, peer outliers.** Behavior far outside a matched peer group (same specialty and state, or same industry and size band). Strong signal, but never enough alone.

**Tier 3, links.** Shared addresses, ownership, or lender patterns that tie a flagged record to others.

| Signal | Program | Tier | Why it holds up |
| --- | --- | --- | --- |
| Excluded provider still paid: NPI on the OIG exclusion list before the service year, still in CMS payment data | Medicare | 1 | Payment to an excluded provider breaks program rules on its face |
| Once-per-lifetime visits billed more than once per patient (Welcome to Medicare, initial annual wellness visit) | Medicare | 1 | Dropped after back-test: Medicare's claim edits already block repeats (no hits in 41,995 rows) |
| Impossible hours: time-based codes adding up to more than 12 hours a day, 250 days a year | Medicare | 1 | Uses each code's minimum time; best rule in the back-test (about 40x chance). Open explanation: assistants billing under the supervisor |
| Loan per reported job above the statutory ceiling ($20,833 first draw; $29,167 for restaurants and hotels on second draw) | PPP | 1 | The loan formula caps it: 2.5 months of payroll, pay capped at $100K a year; EIDL refinance netted out. Not yet validated |
| Second-draw loan reporting more than 300 jobs | PPP | 1 | Second draws required 300 or fewer employees |
| Two first-draw loans to the same business | PPP | 1 | Each business could take only one first-draw loan |
| Level 5 visit share, payment per patient, or services per patient above the 99th percentile of peers | Medicare | 2 | Peer-matched by specialty and state to absorb patient mix |
| High-risk code concentration: skin substitutes, genetic tests, urine drug panels, braces, non-emergency ambulance | Medicare | 2 | These are the code families behind recent DOJ takedowns |
| Year-over-year billing spike of 5x or more from a new or dormant provider | Medicare | 2 | Fits the bust-out pattern seen in recent schemes |
| Borrower affiliated with a large or public parent company | PPP | 2 | Affiliation drove most PPP False Claims Act settlements to date |
| Many loans at one residential address, or lender fraud rates far above peers | PPP | 3 | Ring and lender patterns; corroborates, never decides |
| Children or meals billed above licensed capacity | Child care and meal programs | 1 | Licensed capacity is a legal cap; billing above it cannot all be real |
| Claims on days or at sites that were closed | Child care and meal programs | 1 | A closed site serves no one; the meal claims at a closed park are the textbook case |
| Large payments within months of the entity forming | All programs | 2 | Fits the bust-out pattern; legitimate new businesses also grow fast, so never alone |
| Network: entities sharing officers, registered agents or addresses, with payments flowing between them | All programs | 3 | Exposes rings through relationships, never names; raises priority of an already-flagged entity |

**Lead gate.** A record becomes a lead only with at least one Tier 1 hit, or at least two independent Tier 2 signals, plus dollars at issue above a materiality floor ($500K for Medicare, $1M for PPP). Everything below the gate stays internal as a watch list.

## False-positive controls and defensibility

Every lead must survive the same test a defense lawyer would run: is there an obvious innocent explanation for this number? Courts dismissed stats-only cases for exactly that reason, so the controls below are built in, not bolted on.

1. **Rules before statistics.** Tier 1 rules come from program rules and code definitions, so they can be cited, not argued. A statistical outlier never becomes a lead on its own.
2. **Peer matching.** Outliers are measured against providers with the same specialty, state and place of service, or borrowers with the same industry and size band. This absorbs most patient-mix and regional explanations.
3. **Conservative thresholds.** Impossible-hours checks use each code's minimum time, not its typical time. PPP ceilings use the statutory maximums. When in doubt, the threshold moves in the provider's favor.
4. **Suppression and data-quality screens.** CMS hides counts under 11 patients, so small cells are skipped. Rows with missing or zero job counts, or obvious entry errors, are excluded rather than flagged.
5. **Innocent-explanation checklist.** Each lead ships with the explanations considered and why they fail: group billing under one NPI, new CMS guidance, facility versus office billing, data-entry error, legitimate affiliate exemptions.
6. **Evidence card and audit trail.** Every lead carries the source file, dataset version, query, raw values, peer distribution and rule version. Anyone can re-run it and get the same answer.
7. **Measured precision, not claimed precision.** Each rule is back-tested against later enforcement before it ships. Rules that fail to beat the base rate by a wide margin are dropped.
8. **Human review before release.** No lead leaves the system without an analyst sign-off, and none is ever published.
9. **No names or ancestry, and a bias audit every run.** Owner names never feed a score, and inferring origin from a name is banned, just as race, ethnicity and gender columns are dropped on load. Each run compares flag rates across ZIP codes against Census demographics for those areas; a rule that skews without a behavioral reason is fixed or dropped. The audit report ships with the data, which is what lets a government buyer sign.

## Back-test results

The impossible-hours rule beat chance by about 40 times: providers it flagged in 2019 were later excluded for fraud at 2.5% to 2.7%, against a 0.07% base rate. The preset 3,000-hour cut caught 1 of 37 (p = 0.02); a looser 2,500-hour cut, run as a sensitivity check, caught 2 of 79 (p = 0.001). Peer outliers on their own ran 2 to 7 times chance and none were statistically significant.

| Rule | Tier | Flagged | Later excluded | Lift over base rate | 95% interval |
| --- | --- | --- | --- | --- | --- |
| Impossible hours, over 2,500 h | 1 | 79 | 2 | 37x | 10x to 129x |
| Impossible hours, over 3,000 h | 1 | 37 | 1 | 40x | 7x to 204x |
| Lead gate (Tier 1 or two Tier 2) | Combined | 178 | 1 | 8x | 1.5x to 46x |
| Visits per patient, 90837 | 2 | 185 | 1 | 7x | 1.2x to 37x |
| Visits per patient, 90834 | 2 | 195 | 1 | 6x | 1.1x to 35x |
| Visits per patient, 97110 | 2 | 665 | 1 | 3x | 0.5x to 16x |
| Any single Tier 2 signal | 2 | 1,907 | 3 | 2x | 0.8x to 6.8x |

*Source: CMS 2019 Part B, 14 codes, 107,506 providers · OIG LEIE 09-2026 · fse ruleset 2026.10.0. An interval reaching below 1x means the rule may be no better than chance.*

**Test design.** Score 2019 Medicare data, then check which flagged providers the OIG excluded for fraud between Jan 2020 and Sept 2026. Providers already excluded before 2020 are removed from both sides. Labels miss civil settlements and the 89% of exclusions with no NPI on file, so every precision figure here is a floor.

**Rules dropped.** The lifetime-visit rule found nothing: Medicare's claim edits already block repeat visits, and 41,994 of 41,995 provider rows show exactly one visit per patient. The long-session share rule flagged 958 providers and none were later excluded.

**Verified violation.** The exclusion cross-match is a present-tense finding, not a prediction. Of 4,161 providers excluded before 2019, one was still paid in 2019: an oncology provider excluded in 2016 for a program-related crime, paid about $392K. Name, state and specialty match on both records; claims review is the next check.

**PPP scan (not yet validated).** No public label set exists for PPP, so these are counts, not precision.

| Rule | Loans flagged | Approved amount | Note |
| --- | --- | --- | --- |
| Loan per job above 2x the formula ceiling, EIDL refinance netted out | 6,213 (1,367 over $1M) | $5.38B | Median $61,667 per reported job |
| Two first-draw loans to one business | 423 loans in 208 groups | $300.6M | 69 groups over $1M |
| Second draw reporting more than 300 jobs | 3 | $5.1M | All report exactly 500 jobs, possibly a placeholder |

**What this means for trust.** Public data finds real signal, but statistics alone are not proof, which matches the court rulings. Sell Tier 1 violations as verified findings. Sell statistical scores only as a ranked risk list with the measured lift printed beside it. Never label either one fraud.

## Product: how to serve the data

Serve it as an invite-only, sign-in B2B platform, not open self-serve. Names of flagged providers never appear anywhere public; the only free, public layer is an aggregate heatmap with no names, used to pull in buyers.

Three reasons self-serve is the wrong default:

- **Exclusivity is the value.** Only the first whistleblower to file gets paid, so a lead seen by many buyers is worth nothing to any of them.
- **Misuse risk.** Open sign-up with a credit card invites people who would use a lead to pressure a provider for money, and it makes the defamation exposure ours.
- **The buyers are few and high-value.** Qui tam firms, payer fraud units, state program integrity teams and healthcare deal teams buy through contracts, not checkout pages.

| Offer | Buyer | What they get | Access | Starting price to test | Time to first revenue |
| --- | --- | --- | --- | --- | --- |
| Diligence screen | Private equity and lenders buying healthcare practices | Exposure report on a target's NPIs, all rules plus evidence cards | Per-report, under NDA | $5K per target | Weeks |
| Compliance self-audit | Provider groups and their compliance consultants | Same screen on their own NPIs, verified ownership | Sign-in, org-verified | $2.5K per year per group | Weeks |
| Screening subscription | Medicare Advantage and Medicaid plan fraud units, state integrity units | All-provider risk scores, monthly refresh, API | Sign-in with SSO, seat-based | $50K per year | 6 to 12 months |
| Exclusive case package | Qui tam law firms | One lead, exclusively licensed, with evidence card and investigation notes | Sign-in, one firm per lead, logged handoff | $15K flat per package | 1 to 3 months |
| Own filings | Brilliant Disruptions as whistleblower, with partner counsel on contingency | The relator share on the strongest leads (15 to 30%) | Internal only | Not priced | Years |

**Fastest revenue:** diligence screens and self-audits. Same engine, transactional buyers, and the subject is the buyer's own target or own practice, so the legal exposure is low.

**Biggest upside:** keep the top Tier 1, high-dollar leads for your own filings, and license the rest. Selling a lead and filing on it are mutually exclusive, so decide the cut line before the first sale.

**Access controls in the app:** organization accounts with verified identity, role-based access, every lead view logged with a timestamp (which also documents first handoff), watermarked exports, and no bulk export on the case-package tier.

## Legal guardrails

The product sells risk indicators with evidence, never accusations, and it never publishes a name. Have False Claims Act counsel review the terms before the first sale; this section is a checklist, not legal advice.

| Risk | What goes wrong | Guardrail |
| --- | --- | --- |
| Defamation | A provider is called a fraudster on the strength of a statistic | Label output "risk indicators," show the evidence, ban buyers from publishing or contacting targets |
| First-to-file bar | Only the first whistleblower to file gets paid; a lead sold twice is worth zero to the second buyer | Each lead is licensed to one buyer, exclusively, with a timestamped handoff |
| Public disclosure bar | Cases built only on public data get dismissed or capped at 10% | Leads are starting points; the buyer's investigation supplies the non-public facts |
| Fee splitting | Lawyers may not share fees with non-lawyers, and fact witnesses may not be paid on outcome | Charge flat license and subscription fees, or file as the whistleblower yourself with counsel on contingency |
| Seal violations | Qui tam complaints are filed under seal; leaks can sink the case | Buyers sign confidentiality terms; nothing about a filed case is discussed publicly |
| Misuse | A buyer uses a lead to pressure a provider for money | Vet buyers (licensed firms, payers, agencies), log every access, revoke on misuse |
| Privacy | Re-identifying patients from aggregate data | Use only CMS-published aggregates; never join to patient-level data |
| Profiling | A rule tracks national origin instead of behavior, inviting discrimination claims and discrediting every lead in the file | No name or ancestry inputs; bias audit on every run; audit report delivered with the data |

## Build roadmap

Spend the first 30 days making the precision numbers solid, then sell diligence screens in month two while the platform is built in month three.

| Phase | Days | Work | Gate to move on |
| --- | --- | --- | --- |
| Prove precision | 1 to 30 | Back-test 5 years of data; add DOJ cases as labels; validate PPP rules; run pipeline on Supabase | A rule ships only if its lift stays above 3x at 95% confidence |
| First revenue | 31 to 60 | Diligence screen report; pilots with PE deal teams; compliance self-audits; counsel reviews terms | 3 paid pilots signed |
| Platform | 61 to 90 | Sign-in app with org accounts; logged views and watermarks; one qui tam firm partner; public aggregate heatmap | $25K booked or first subscription signed |

Each phase starts only when the previous gate is met. Nashville's healthcare deal and compliance community is the natural first market for the pilots.

Child care and meal programs are the next vertical. File public-records requests for one pilot state's licensing, payment and meal-claim data during Phase 1, so the data arrives in time to build and back-test that vertical in Phase 3.

## Sources

- [CMS data catalog and API](https://data.cms.gov/)
- [OIG exclusion list downloads](https://oig.hhs.gov/exclusions/leie-database-supplement-downloads/)
- [SBA PPP loan-level data](https://data.sba.gov/dataset/ppp-foia)
- [U.S. Chamber: Fifth and Ninth Circuits reject stats-only qui tam suits](https://uschamber.com/lawsuits/stats-without-facts-another-court-rejects-data-mining-qui-tam-strategy)
- [Polsinelli: PPP public-data cases and the public disclosure bar](https://www.polsinelli.com/publications/doj-ppp-enforcement-turns-civil)
- [DOJ: data-miner relator paid 10% in a PPP settlement](https://www.justice.gov/usao-wdwa/pr/seattle-data-analytics-company-pay-more-1-million-resolve-claims-it-improperly)
- [Goodwin: DOJ invites data miners to share their tools](https://www.goodwinlaw.com/en/insights/publications/2026/08/alerts-practices-gie-sba-analytics-initiative-accelerate-relief-fraud-enforcement)
- [Fox 9: Video catches Minneapolis daycare billing fraud](https://www.fox9.com/news/charges-video-catches-minneapolis-daycare-financial-fraud)
- [KSTP: 436 open daycare investigations as new attendance system begins](https://kstp.com/5-investigates/state-confirms-436-open-investigations-into-publicly-funded-daycares-as-new-attendance-system-begins/)
- [Minnesota Reformer: Park where thousands of meals were purportedly served was closed](https://minnesotareformer.com/2024/05/01/park-where-thousands-of-meals-were-purportedly-given-away-during-the-pandemic-was-closed/)
