# Actual Budget: GitHub issue tracker — top feature requests and bugs (upstream actualbudget/actual)

Research date: 2026-11-16. Counts are snapshots from the public GitHub search API / issue pages on that date. "Local checkout" means the fork at /home/user/actual (origin 1-TB/actual, HEAD dated 2026-11-15, tracking upstream master; its `packages/docs/docs/releases.md` matches the live https://actualbudget.org/docs/releases page through 26.11.0, which I confirmed). Items taken from the checkout's `upcoming-release-notes/` are merged-but-unreleased work and are flagged as such.

Short source keys used below:
- [FR-API] = https://api.github.com/search/issues?q=repo:actualbudget/actual+label:%22needs+votes%22&sort=reactions-%2B1&order=desc&per_page=40 (human view: https://github.com/actualbudget/actual/issues?q=label%3A%22needs+votes%22+sort%3Areactions-%2B1-desc)
- [BUG-API] = https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open+type:Bug&sort=reactions-%2B1&order=desc&per_page=30
- [OPEN-API] = https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open&sort=comments&order=desc&per_page=30
- [REL] = https://actualbudget.org/docs/releases
- [ROADMAP] = https://actualbudget.org/blog/roadmap-for-2026 (published 2025-12-20, author youngcw)
- [FLAGS] = https://github.com/actualbudget/actual/blob/master/packages/desktop-client/src/hooks/useFeatureFlag.ts (read in the local checkout)

## What are the top ~30 feature requests by reaction count under "needs votes", and what themes do they cluster into?

### Takeaway
There are 860 issues labelled "needs votes", all closed by policy but still votable; the top five are a budget-goals UI (504 thumbs-up), bank-sync transfer recognition (391), multi-currency (350), subcategories (347) and Plaid (328). Demand clusters around budgeting-model flexibility (goals, subcategories, group budgets, custom periods), bank sync, currency, table/UI ergonomics, reports/forecasting, attachments and authentication; investment tracking and "multi-user" are much lower in votes than commonly assumed.

### Cited Findings

Process facts:
- The "needs votes" search returns 860 issues; every one of the top 40 is `closed` with state_reason `completed` (this is the bot's policy closure, not implementation). — [FR-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+label:%22needs+votes%22&sort=reactions-%2B1&order=desc&per_page=40)
- Feature requests are auto-closed by github-actions with the text "This repository is now using lodash style issue management for enhancements ... enhancement issues will now be closed instead of leaving them open", and the project will "consider implementing ones that receive many upvotes". Most top requests show a created and closed timestamp seconds apart; older ones were bulk-closed on 2023-05-01. — [#1320](https://github.com/actualbudget/actual/issues/1320), [#530](https://github.com/actualbudget/actual/issues/530)
- The contributing docs tell contributors that "Working on the highest rated feature requests would also be appreciated" and "We do not assign issues to specific people". — [Contributing docs](https://actualbudget.org/docs/contributing/)
- The 2026 roadmap post ends by asking users to "vote on the features you would like to see get added to Actual" by reacting with thumbs-up on the needs-votes list. — [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026)

Top 40 by thumbs-up (rank | issue | title | opened | thumbs-up | comments). All from [FR-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+label:%22needs+votes%22&sort=reactions-%2B1&order=desc&per_page=40); issue URL pattern is https://github.com/actualbudget/actual/issues/N.

| # | Issue | Title | Opened | Thumbs-up | Comments |
|---|---|---|---|---|---|
| 1 | [#496](https://github.com/actualbudget/actual/issues/496) | Budget goals - UI implementation | 2023-01-22 | 504 | 11 |
| 2 | [#1628](https://github.com/actualbudget/actual/issues/1628) | Bank Sync - Recognise transfers between accounts | 2023-09-01 | 391 | 11 |
| 3 | [#1132](https://github.com/actualbudget/actual/issues/1132) | Budget Currency and Category Currencies | 2023-06-14 | 350 | 81 |
| 4 | [#1320](https://github.com/actualbudget/actual/issues/1320) | Add subcategory | 2023-07-09 | 347 | 35 |
| 5 | [#898](https://github.com/actualbudget/actual/issues/898) | Plaid Integration | 2023-04-14 | 328 | 50 |
| 6 | [#536](https://github.com/actualbudget/actual/issues/536) | Resizable columns | 2023-01-22 | 252 | 16 |
| 7 | [#530](https://github.com/actualbudget/actual/issues/530) | Upload Attachment support for transactions | 2023-01-22 | 216 | 19 |
| 8 | [#2965](https://github.com/actualbudget/actual/issues/2965) | Progress bar for targets/templates | 2024-07-02 | 210 | 13 |
| 9 | [#2042](https://github.com/actualbudget/actual/issues/2042) | 2FA (OTP) and Passkeys authentication | 2023-12-06 | 186 | 7 |
| 10 | [#1683](https://github.com/actualbudget/actual/issues/1683) | Groups for accounts | 2023-09-11 | 150 | 20 |
| 11 | [#517](https://github.com/actualbudget/actual/issues/517) | Projected Balances Report | 2023-01-22 | 140 | 8 |
| 12 | [#975](https://github.com/actualbudget/actual/issues/975) | Change first day of month | 2023-04-30 | 121 | 19 |
| 13 | [#672](https://github.com/actualbudget/actual/issues/672) | Allow changing the base URL | 2023-02-21 | 101 | 17 |
| 14 | [#500](https://github.com/actualbudget/actual/issues/500) | Regex Rules | 2023-01-22 | 101 | 6 |
| 15 | [#826](https://github.com/actualbudget/actual/issues/826) | Backup / Restore API | 2023-03-28 | 97 | 14 |
| 16 | [#2021](https://github.com/actualbudget/actual/issues/2021) | Bring Back Account Types | 2023-12-03 | 92 | 5 |
| 17 | [#1534](https://github.com/actualbudget/actual/issues/1534) | Budget view: show upcoming transaction | 2023-08-17 | 90 | 8 |
| 18 | [#1346](https://github.com/actualbudget/actual/issues/1346) | Spend by category | 2023-07-15 | 83 | 1 |
| 19 | [#3678](https://github.com/actualbudget/actual/issues/3678) | Add stock/crypto balance | 2024-10-16 | 83 | 7 |
| 20 | [#2106](https://github.com/actualbudget/actual/issues/2106) | Allow disable the "Try Demo" link (selfhosted) | 2023-12-20 | 70 | 1 |
| 21 | [#2477](https://github.com/actualbudget/actual/issues/2477) | Possibility to export reports | 2024-03-17 | 69 | 7 |
| 22 | [#1928](https://github.com/actualbudget/actual/issues/1928) | Calendar view for scheduled items | 2023-11-18 | 65 | 4 |
| 23 | [#1589](https://github.com/actualbudget/actual/issues/1589) | Show currency symbol | 2023-08-25 | 64 | 2 |
| 24 | [#5284](https://github.com/actualbudget/actual/issues/5284) | Add support for PostGreSQL | 2025-07-04 | 64 | 1 |
| 25 | [#3248](https://github.com/actualbudget/actual/issues/3248) | report on category balance | 2024-08-12 | 61 | 7 |
| 26 | [#1995](https://github.com/actualbudget/actual/issues/1995) | Handle credit cards like nYNAB | 2023-11-30 | 59 | 18 |
| 27 | [#557](https://github.com/actualbudget/actual/issues/557) | Implement feature to import "Category" | 2023-01-22 | 53 | 16 |
| 28 | [#3320](https://github.com/actualbudget/actual/issues/3320) | sub-categories (or category tags) | 2024-08-27 | 50 | 7 |
| 29 | [#4201](https://github.com/actualbudget/actual/issues/4201) | Amortization Schedule | 2025-01-20 | 50 | 4 |
| 30 | [#3136](https://github.com/actualbudget/actual/issues/3136) | Provide UI for managing Transaction tagging | 2024-07-25 | 48 | 2 |
| 31 | [#2787](https://github.com/actualbudget/actual/issues/2787) | Option to create a new category when adding a transaction | 2024-05-21 | 46 | 4 |
| 32 | [#2006](https://github.com/actualbudget/actual/issues/2006) | Allow Category for Off Budget Accounts | 2023-12-02 | 44 | 8 |
| 33 | [#3438](https://github.com/actualbudget/actual/issues/3438) | Allow budgeting groups | 2024-09-14 | 43 | 5 |
| 34 | [#2963](https://github.com/actualbudget/actual/issues/2963) | Overspent Categories Banner in Budget Page | 2024-07-02 | 43 | 6 |
| 35 | [#3043](https://github.com/actualbudget/actual/issues/3043) | Ability to see Recent Moves in the Budget | 2024-07-12 | 39 | 4 |
| 36 | [#5004](https://github.com/actualbudget/actual/issues/5004) | Improve visibility of overspending | 2025-05-16 | 38 | 3 |
| 37 | [#1570](https://github.com/actualbudget/actual/issues/1570) | Add category to schedules | 2023-08-23 | 38 | 7 |
| 38 | [#679](https://github.com/actualbudget/actual/issues/679) | Allow "payee/category/account contains" in rules | 2023-02-22 | 38 | 4 |
| 39 | [#1201](https://github.com/actualbudget/actual/issues/1201) | Custom budget periods (e.g., yearly) | 2023-06-26 | 38 | 4 |
| 40 | [#507](https://github.com/actualbudget/actual/issues/507) | Custom Report Ideas | 2023-01-22 | 37 | 1 |

Theme clustering (thumbs-up summed from the table above; arithmetic is mine):
- Budgeting model / goals: #496 (504), #1320 (347), #2965 (210), #975 (121), #1534 (90), #1995 (59), #3320 (50), #3438 (43), #2963 (43), #3043 (39), #5004 (38), #1201 (38).
- Bank sync: #1628 (391), #898 (328).
- Currency: #1132 (350), #1589 (64).
- UI ergonomics / accounts sidebar: #536 (252), #1683 (150), #2021 (92), #2787 (46).
- Reports and forecasting: #517 (140), #1346 (83), #2477 (69), #1928 (65), #3248 (61), #507 (37).
- Attachments: #530 (216).
- Auth / self-hosting / server: #2042 (186), #672 (101), #826 (97), #2106 (70), #5284 (64).
- Rules / import / tags: #500 (101), #557 (53), #3136 (48), #679 (38), #1570 (38).
- Investments / loans: #3678 (83), #4201 (50), #2006 (44).

### Inferences
- The request list is dominated by 2023-era issues (26 of the top 40 were opened in 2023); few requests opened in 2025-2026 have accumulated enough votes to rank, so the list reflects long-standing demand more than recent demand.
- Investment tracking (83 votes) ranks far below budgeting-model and bank-sync requests; multi-user does not appear in the top 40 at all, consistent with it having shipped in 2025.
- Vote totals are split across duplicates (subcategories: #1320 + #3320 + #3438; overspending visibility: #2963 + #5004), so the true demand for those themes is higher than any single row shows.
- Comment counts are low relative to votes (e.g. 504 votes / 11 comments), because issues are closed immediately and act mainly as vote counters.

### Gaps
- I retrieved only the top 40 of 860; the long tail was not enumerated.
- Thumbs-up counts are for the opening post only; I did not separately sum total reactions for rows 26-40 beyond what the API returned.
- GitHub Discussions were not checked (several issues reference old discussion links that commenters say are dead, e.g. in #530).

## Which heavily requested features are implemented or experimental as of 2026, and which remain unaddressed for years?

### Takeaway
Of the top ten, none is fully shipped as a stable feature: goals UI, account groups, projected balances and currency display exist only behind experimental flags; resizable columns is partial; transfer recognition, true multi-currency, subcategories, Plaid, attachments and native 2FA remain unimplemented 2.5-3.5 years after being filed. Shipped wins lower in the list are tags management, and features outside the list such as OpenID/multi-user.

### Cited Findings

Experimental flags that exist in the current code (all default off): `newSidebarUI`, `goalTemplatesEnabled`, `goalTemplatesUIEnabled`, `actionTemplating`, `formulaMode`, `currency`, `balanceForecastReport`, `customThemes`, `budgetAnalysisReport`, `enableBanking`, `sankeyReport`, `mobileCalculator`, `monteCarloReport`. — [FLAGS](https://github.com/actualbudget/actual/blob/master/packages/desktop-client/src/hooks/useFeatureFlag.ts)
- Docs list experimental pages for balance forecast report, budget analysis report, budget automation, formulas, goal templates, Monte Carlo analysis, monthly cleanup, redesigned sidebar, rule templating, Sankey report; docs warn these are "still in active development" and recommend regular backups. — [Experimental features docs](https://actualbudget.org/docs/experimental/)

Status per top request:
- #496 Budget goals UI (504): EXPERIMENTAL. Goal templates remain an experimental flag; a "Budget automation UI" experimental feature has an open feedback issue #7692 opened 2026-05-03 with 165 comments. The Dec 2025 roadmap still listed "Goals UI" as a 2026 wish: "We plan on getting a proper GUI put together for these". — [FLAGS](https://github.com/actualbudget/actual/blob/master/packages/desktop-client/src/hooks/useFeatureFlag.ts); [OPEN-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open&sort=comments&order=desc&per_page=30); [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026)
- #1628 Bank-sync transfer recognition (391): NOT IMPLEMENTED. No linked PRs; earlier PR #766 never merged. Users rely on a rules workaround (mark as transfer on one side, delete duplicate on the other) that commenters warn can silently delete valid transactions. Latest activity 2026-09-30 proposes an `api.makeTransfer` method with no maintainer response. — [#1628](https://github.com/actualbudget/actual/issues/1628)
- #1132 Multi-currency (350): PARTIAL / EXPERIMENTAL DISPLAY ONLY. An experimental feature "to display currency symbols in the app" shipped in 25.8.0 (PR #5167) and was extended to reports (25.9.0), rules/schedules (25.11.0), templates (25.12.0) and the budget (26.1.0); dozens of currencies have been added to the picker through 26.11.0. The 2026 roadmap describes "Budget Currencies (still experimental)". True multi-currency with exchange rates exists only in unmerged contributor PRs (#9319, #9356, #9424) and deploy previews as of 2026-11-15. — [REL](https://actualbudget.org/docs/releases); [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026); [#1132](https://github.com/actualbudget/actual/issues/1132)
- #1320 Subcategories (347): NOT IMPLEMENTED. No linked PRs or maintainer plan; a contributor reported building arbitrary-depth nested groups in a personal fork (2026-08-21); a user asking on 2026-08-19 whether contributions would be accepted got no visible reply. Tags are offered as the workaround. — [#1320](https://github.com/actualbudget/actual/issues/1320)
- #898 Plaid (328): NOT IMPLEMENTED. No linked PRs. Other providers were added instead: Enable Banking (experimental, 26.6.0, PR #7345) and Akahu for New Zealand (experimental, 26.7.0, PR #6041). — [#898](https://github.com/actualbudget/actual/issues/898); [REL](https://actualbudget.org/docs/releases)
- #536 Resizable columns (252): PARTIAL. Budget-table category-name resizing shipped in 25.5.0 (PR #4807); a transaction-table column manager (show/hide/reorder) shipped in 26.9.0 (PR #8580). Free column resizing is not shipped; contributor StephenBrown2 (2026-09-01): "that will probably come with the table rewrite that's been impending for a while". — [REL](https://actualbudget.org/docs/releases); [#536](https://github.com/actualbudget/actual/issues/536)
- #530 Attachments (216): NOT IMPLEMENTED. No linked PRs; only fork commits by matt-fidd (Oct-Nov 2025) reference it. — [#530](https://github.com/actualbudget/actual/issues/530)
- #2965 Goal progress bar (210): NOT IN A RELEASE; a merged-but-unreleased note says "Show a small ring beside the balance of categories whose goal is not yet funded, which fills as the goal is funded". — local checkout `upcoming-release-notes/` (unreleased as of 26.11.0; see [REL](https://actualbudget.org/docs/releases) for the released baseline)
- #2042 2FA/passkeys (186): NOT IMPLEMENTED natively. OpenID was promoted to a default (non-experimental) feature in 25.6.0 (PR #4903) and commenters treat IdP-side MFA as the workaround; a contributor posted a TOTP design on 2026-08-24 with no reply. — [REL](https://actualbudget.org/docs/releases); [#2042](https://github.com/actualbudget/actual/issues/2042)
- #1683 Account groups (150): EXPERIMENTAL. 26.10.0 introduced "an experimental redesigned sidebar with account groups" (PRs #8832, #8892; backend #8764 in 26.9.0); feedback issue #9007 opened 2026-09-24 has 60 comments. — [REL](https://actualbudget.org/docs/releases); [OPEN-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open&sort=comments&order=desc&per_page=30)
- #517 Projected balances (140): EXPERIMENTAL. `balanceForecastReport` flag; feedback issue #7669 "Balance Forecast report" opened 2026-04-30, 37 comments. — [FLAGS](https://github.com/actualbudget/actual/blob/master/packages/desktop-client/src/hooks/useFeatureFlag.ts); [OPEN-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open&sort=comments&order=desc&per_page=30)
- #2021 Account types (92): NOT IMPLEMENTED; account types were removed in 2023 (PR #948: "they didn't do anything in the budget"). The 2026 roadmap wish list includes "Debt account type ... We would like to bring back account types ... starting with loan accounts". — [REL](https://actualbudget.org/docs/releases); [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026)
- #1534 Upcoming transactions in budget view (90): PARTIAL. 25.6.0 added an "upcoming/missed/due schedules indicator on budget table (based on category schedule templates)" (PR #4815). — [REL](https://actualbudget.org/docs/releases)
- #1589 Show currency symbol (64): EXPERIMENTAL via the `currency` flag; feedback issue #5191 "Currency symbol support" (opened 2025-06-18, 71 comments) is still open. — [OPEN-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open&sort=comments&order=desc&per_page=30)
- #4201 Amortization (50): PARTIAL / EXPERIMENTAL. Experimental formulas gained loan and investment functions (IPMT, PPMT, NPER, XNPV) with autocomplete in 26.9.0 (PR #8705). — [REL](https://actualbudget.org/docs/releases)
- #3136 Tag management UI (48) and #3320 "category tags" (50): IMPLEMENTED for tags. Dedicated tags page in 25.8.0; tags API in 26.3.0; tag autocomplete 26.6.0; show/hide and "has any/all tags" filters 26.7.0; rename tag 26.9.0; reports grouped by tags 26.11.0. — [REL](https://actualbudget.org/docs/releases)

Other heavily requested items that shipped (not in the current top 40):
- 2025 shipped list per maintainer youngcw: "OIDC and multi-user support", adjustable upcoming time frame for schedules, new report types, NPM package for sync server, translations, bank sync management page, embedded server in desktop app, auto-hold income, merge transactions, transaction tags, mobile pages for Rules/Payees/Schedules/Bank Sync, "Budget Currencies (still experimental)". — [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026)
- 26.11.0 (2026-11-01): automatic bank syncing at a chosen interval, reports grouped by tags, customisable sidebar pages, per-budget SimpleFIN credentials, "Optimizations for performance and memory usage on large budget". 26.10.0 (2026-10-02): "Speeds up transaction editing, especially in larger budgets". — [REL](https://actualbudget.org/docs/releases)

2026 roadmap wish list vs. outcome:
- The roadmap named Plugins ("Our hope is to have plugins ready for you to build on in the first few months of 2026"), Goals UI, mobile feature parity, transaction-table rewrite, debt account type, and faster tests. — [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026)
- Plugins were the one 2025 roadmap goal missed ("we were able to accomplish all but one of our goals, plugins"). — [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026)
- The live release page's three most recent releases (26.9.0-26.11.0) contain no mention of plugins. — [REL](https://actualbudget.org/docs/releases)

### Inferences
- Pattern: the project's response to large requests is typically a long-lived experimental flag (goal templates have been experimental for years; currency since Aug 2025) rather than a stable release, so "implemented" claims need the qualifier "experimental, opt-in".
- Plugins appear to have slipped again in 2026: a keyword search of the release notes and 2026 blog posts in the checkout found no user-facing plugin release, and new bank providers (Enable Banking, Akahu) were added in core rather than as plugins as the roadmap intended.
- The transaction-table rewrite is a declared blocker for resizable columns and was still described as "impending" in Sept 2026, so #536 (filed Jan 2023, idea from June 2022) is unlikely to be resolved quickly.
- Requests requiring data-model changes (subcategories, multi-currency, attachments, transfer matching) are the ones that remain unaddressed; requests solvable in the UI/report layer (tags, reports, account groups) have progressed.

### Gaps
- Not verified (no evidence found in my keyword pass over the release notes, and issue pages not opened): #975 first day of month, #672 base URL, #500 regex rules, #826 backup/restore API, #1346 spend by category, #3678 stock/crypto balance, #2106 disable demo link, #2477 export reports, #1928 calendar view, #5284 PostgreSQL, #3248, #1995, #557, #2787, #2006, #3438, #2963, #3043, #5004, #1570, #679, #1201. Some of these may have shipped (e.g. regex rule matching and a calendar report are things I believe exist but did not confirm against a source).
- Akahu becoming non-experimental and per-budget API keys appear only in the checkout's unreleased notes; I did not confirm they will ship in 26.12.0.
- Mobile parity: I did not measure which desktop features are still missing on mobile.

## What are the most commented or most reacted-to open bug reports, and what recurring bug categories appear?

### Takeaway
The open tracker is small (118 open issues, 83 of them typed Bug) and bugs attract almost no votes: the most-reacted open bug has 4 thumbs-up. The busiest open threads are feedback issues for experimental features, not bugs; recurring bug areas are bank sync (GoCardless, Enable Banking), schedules date logic, mobile/responsive input, API behaviour, OpenID/server auth, reports and goal templates.

### Cited Findings
- The repository has 118 open issues in total; 83 are open with issue type "Bug". The classic `label:bug` filter returns 0 results, i.e. the project uses GitHub issue types rather than a bug label. — [OPEN-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open&sort=comments&order=desc&per_page=30); [BUG-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open+type:Bug&sort=reactions-%2B1&order=desc&per_page=30); [label:bug search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+is%3Aopen+label%3Abug+sort%3Acomments-desc)

Most-reacted open bugs (issue | title | opened | thumbs-up | comments | labels), from [BUG-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open+type:Bug&sort=reactions-%2B1&order=desc&per_page=30):
- [#3204](https://github.com/actualbudget/actual/issues/3204) uncategorized transactions not included in "split: category" reports when "show uncategorized" is checked | 2024-08-05 | 4 | 3 | reports
- [#1957](https://github.com/actualbudget/actual/issues/1957) Posting a scheduled transaction early does not remove the schedule | 2023-11-22 | 3 | 4 | schedules
- [#4460](https://github.com/actualbudget/actual/issues/4460) Account linking process with GoCardless times out before completion | 2025-02-26 | 3 | 21 | bank sync
- [#7241](https://github.com/actualbudget/actual/issues/7241) Node.js API authentication fails with "Invalid redirect URL" when OpenID is configured alongside password auth | 2026-03-20 | 3 | 6 | openid
- [#4488](https://github.com/actualbudget/actual/issues/4488) header auth prompting for a password | 2025-03-01 | 3 | 7 | server
- [#1827](https://github.com/actualbudget/actual/issues/1827) API import transactions overrides some fields, not others | 2023-10-26 | 2 | 4 | API
- [#3051](https://github.com/actualbudget/actual/issues/3051) Can't click off to close filter menu with select open | 2024-07-13 | 2 | 6
- [#6401](https://github.com/actualbudget/actual/issues/6401) Android tablet category select broken | 2025-12-14 | 2 | 2 | responsive, regression
- [#1062](https://github.com/actualbudget/actual/issues/1062) Scheduled transactions don't handle 29th/30th/31st dates appropriately | 2023-05-25 | 2 | 15 | schedules
- Remaining visible bugs have 0-1 thumbs-up, e.g. [#6524](https://github.com/actualbudget/actual/issues/6524) Actual only supports RS256 (2026-01-02, openid); [#4280](https://github.com/actualbudget/actual/issues/4280) importTransactions API won't check for duplicates in same import (2025-02-02); [#1331](https://github.com/actualbudget/actual/issues/1331) Transactions not merged when applying rules to existing transactions (2023-07-12); [#9104](https://github.com/actualbudget/actual/issues/9104) API updateTransaction/deleteTransaction resolve before the change is applied (2026-10-05, regression); [#7828](https://github.com/actualbudget/actual/issues/7828) Intermittent failure to sync when using HTTP Basic Auth (2026-05-13); [#8899](https://github.com/actualbudget/actual/issues/8899) Apple PWA status bar on iOS 27 (2026-09-07); [#9453](https://github.com/actualbudget/actual/issues/9453) iOS requesting location does not work (2026-11-05); [#6278](https://github.com/actualbudget/actual/issues/6278) keyboard shortcuts on non-QWERTY layouts (2025-12-01); [#4285](https://github.com/actualbudget/actual/issues/4285) unable to type in report fields on mobile browsers (2025-02-03); [#5413](https://github.com/actualbudget/actual/issues/5413) All Accounts totals do not match when a closed account has a balance (2025-07-28); [#4381](https://github.com/actualbudget/actual/issues/4381) filtered balance on split notes miscalculated (2025-02-14); [#6316](https://github.com/actualbudget/actual/issues/6316) Mac icon too large on Sequoia (2025-12-06).

Most-commented open issues of any type, from [OPEN-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open&sort=comments&order=desc&per_page=30):
- Feedback threads for experimental features dominate: [#7799](https://github.com/actualbudget/actual/issues/7799) Enable Banking bank sync provider (opened 2026-05-11, 191 comments); [#7692](https://github.com/actualbudget/actual/issues/7692) Budget automation UI (2026-05-03, 165); [#5949](https://github.com/actualbudget/actual/issues/5949) Formula Card and Formula rules (2025-10-17, 112); [#1919](https://github.com/actualbudget/actual/issues/1919) Sankey Chart (2023-11-16, 97 — experimental for three years); [#5191](https://github.com/actualbudget/actual/issues/5191) Currency symbol support (2025-06-18, 71); [#3606](https://github.com/actualbudget/actual/issues/3606) Rule action templating (2024-10-08, 67); [#9007](https://github.com/actualbudget/actual/issues/9007) Redesigned sidebar (2026-09-24, 60); [#8571](https://github.com/actualbudget/actual/issues/8571) Monte Carlo report (2026-07-26, 43); [#7669](https://github.com/actualbudget/actual/issues/7669) Balance Forecast report (2026-04-30, 37); [#6742](https://github.com/actualbudget/actual/issues/6742) Budget Analysis report (2026-01-21, 26); [#8255](https://github.com/actualbudget/actual/issues/8255) Mobile calculator (2026-06-17, 16).
- Most-commented open bugs: #4460 GoCardless linking timeout (21); #1062 schedules 29th/30th/31st (15); [#4282](https://github.com/actualbudget/actual/issues/4282) mobile: must tap twice to edit any transaction field (2025-02-02, 12); [#6030](https://github.com/actualbudget/actual/issues/6030) multiple "#template by x repeat every y" lines calculate incorrect total (2025-10-30, 11); [#6948](https://github.com/actualbudget/actual/issues/6948) renaming "Main" dashboard creates extra dashboard on mobile (2026-02-12, 10); [#9526](https://github.com/actualbudget/actual/issues/9526) Quicken QIF import fails "Unknown Detail Code: U" (2026-11-12, 10); [#3191](https://github.com/actualbudget/actual/issues/3191) privacy filter shortcut Ctrl+Shift+P collides with browsers (2024-08-04, 9); [#9063](https://github.com/actualbudget/actual/issues/9063) Enable Banking booked transaction silently skipped on import (2026-10-01, 9).
- Longest-standing open bugs in these lists: #1062 (May 2023), #1331 (Jul 2023), #1827 (Oct 2023), #1957 (Nov 2023). — [BUG-API](https://api.github.com/search/issues?q=repo:actualbudget/actual+is:issue+is:open+type:Bug&sort=reactions-%2B1&order=desc&per_page=30)

Recurring categories evidenced in release notes:
- Bank sync provider fixes recur in nearly every 2026 release: Enable Banking duplicates on pagination (PR #9046), wrong payee selection (#9204), bank-specific auth routing (#8355), 91-vs-90-day off-by-one (#7930), skip unimportable transactions instead of failing the whole sync (#8086). — [REL](https://actualbudget.org/docs/releases)
- Import parsing: 26.10.0 "Improves bank file imports, fixing accented letters ... showing up garbled and supporting more CSV formats"; 26.11.0 fixed amounts read without a decimal point when a currency symbol follows (#9100). — [REL](https://actualbudget.org/docs/releases)
- Performance with large budgets is acknowledged in two consecutive releases (26.10.0 transaction editing speed "especially in larger budgets"; 26.11.0 "performance and memory usage on large budget"). — [REL](https://actualbudget.org/docs/releases)
- Sync robustness: 26.10.0 "Makes Actual more resilient to version mismatches, improving syncing between devices running different versions". — [REL](https://actualbudget.org/docs/releases)
- Security: 26.2.1 contained "two critical security fixes for users of SimpleFin, Pluggy or the multi-user feature", including "unauthorized file access in multi-user setups" (PR #7040); 26.11.0 added an SSRF-prevention allowlist for custom SimpleFIN bridges. — [REL](https://actualbudget.org/docs/releases)

### Inferences
- Bugs are triaged and closed quickly enough that few accumulate votes; the open-bug list is therefore a poor proxy for "most painful bugs". Pain shows up instead as fix entries in monthly release notes and as experimental-feature feedback threads.
- Open-bug themes by label frequency in the visible sample: API (3: #1827, #4280, #9104), OpenID/server auth (4: #7241, #4488, #6524, #7828), mobile/responsive (5: #6401, #4282, #4285, #8899, #9453), schedules (2), reports (3), bank sync (2), goal templates (1), import (1).
- No open bug in the visible sample concerns core CRDT sync data loss or reconciliation; sync complaints are auth/proxy-related (#7828) or version mismatch (fixed 26.10.0).
- Several oldest open bugs carry "help wanted" (#1062, #1957, #1331), suggesting they persist for lack of a volunteer rather than disagreement.

### Gaps
- Only the first ~22 of 83 open bugs were visible (API response truncated); closed bugs with high reaction counts (historically painful, now fixed) were not retrieved.
- I did not search for closed-as-not-planned bug reports, pinned issues, or Discord/Reddit complaint volume (out of scope here).
- No specific open issues on reconciliation were found in the sample; I cannot say none exist among the unseen 61.

## What do maintainers say about why certain requests are not being done?

### Takeaway
Stated reasons are mostly complexity against the existing architecture (single-currency numeric model, legacy transaction table, local-first/no-server storage), volunteer capacity with no task pipeline, third-party cost/approval for Plaid, and a preference to push optional functionality to plugins or external systems (OIDC providers, exchange-rate services) rather than the core app.

### Cited Findings
- Policy: enhancement issues are closed on creation and "consider[ed]" when they get many upvotes; nothing is assigned ("We do not assign issues to specific people"; "All issues are open to be worked on by anyone"). — [#1320](https://github.com/actualbudget/actual/issues/1320); [Contributing docs](https://actualbudget.org/docs/contributing/)
- Capacity: contributor db-src (2026-01-22, on 2FA) said there is no task pipeline; maintainers weigh votes when they have time and anyone can open a PR. — [#2042](https://github.com/actualbudget/actual/issues/2042)
- Capacity/funding: the core team receives only "small stipends" funded by donations and PikaPods hosting fees ("over 8000 Pikapods users"). — [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026)
- Multi-currency: j-f1 (2023-06-14): "This would be a very complex feature to add" because the app treats budget values as plain numbers in one currency and the UI and historical budgets would need rethinking; Crazypkr1099 (2023-11-16): "This would be an astronomical amount of work to complete unfortunately." On 2026-11-10 the contributor driving the PRs reported that "one of the maintainers has said he'd rather not have exchange rates in the core app, and the others haven't weighed in yet." — [#1132](https://github.com/actualbudget/actual/issues/1132)
- Attachments: MatissJanis (member, 2023-02-10) called it "an interesting idea" that "will be very complicated to implement", citing dockerized deployments and local-only use without a sync server, and suggested third-party storage integrations instead; j-f1 said for such features "it makes sense to require a server". — [#530](https://github.com/actualbudget/actual/issues/530)
- Plaid: youngcw (member, 2023-11-05): "It does take at least a few days to get plaid syncing setup since you need to get approved by plaid"; (2024-06-23) Plaid's free tier ended 2024-06-20 though an integration "might still be worth building". Commenters note per-transaction costs and privacy objections. A user claim (2026-04-24) that a free Plaid option returned is unconfirmed by maintainers. — [#898](https://github.com/actualbudget/actual/issues/898)
- Resizable columns: blocked on the transaction-table rewrite. Roadmap: "The code for the transaction table is complicated, and not conducive to new features. We plan to rewrite this code to be ... more extendable for new features such as resizing columns." StephenBrown2 (2026-09-01) said the rewrite "hasn't seen much movement" due to other priorities. — [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026); [#536](https://github.com/actualbudget/actual/issues/536)
- Plugins as the escape valve: plugins are meant "to allow users to more easily add functionality to the app without the need to add said feature to the base app", but "plugins have a tendency to break existing features, which slows down development a great deal"; new bank providers "are patiently waiting for plugins". — [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026)
- 2FA: community position (2026-02-16, 5 hearts) that OIDC support makes native 2FA "somewhat irrelevant"; no maintainer decision recorded. — [#2042](https://github.com/actualbudget/actual/issues/2042)
- Subcategories: maintainers/contributors redirect to tags (jfdoming, 2024-10-16: "We do already support tags inside the 'notes' field of a transaction!") rather than state a refusal. — [#1320](https://github.com/actualbudget/actual/issues/1320)
- Account types were deliberately removed in 2023 because "they didn't do anything in the budget" (PR #948), and are now planned to return for loans. — [REL](https://actualbudget.org/docs/releases); [ROADMAP](https://actualbudget.org/blog/roadmap-for-2026)
- Signals of contribution friction: the project published an AI usage policy and a "Fighting AI slop" post (2025-11-15); a maintainer answered a detailed 2026-09-16 user comment on transfer matching with a reminder of the AI usage policy. On 2026-07-21 a maintainer removed the "feature" label from the top requests without explanation (the "needs votes" label and Feature issue type remain). — [#1628](https://github.com/actualbudget/actual/issues/1628); [#530](https://github.com/actualbudget/actual/issues/530); [Fighting AI slop blog](https://actualbudget.org/blog)

### Inferences
- Maintainers rarely say "no"; requests stall through silence. For subcategories, 2FA and transfer matching, would-be contributors asking for design approval in 2026 received no visible maintainer reply, which is itself a barrier given the docs ask contributors to seek approval before large changes.
- The vote system signals demand but creates no obligation: the #1 request (504 votes, Jan 2023) is still experimental after nearly four years, and the roadmap is chosen by maintainers' interests (plugins, table rewrite, CI tooling) only partly overlapping the vote ranking.
- The plugin strategy has become a bottleneck: several requests (extra bank providers, account types, possibly exchange rates) were deferred to plugins, which missed the 2025 goal and show no release in 2026 notes.

### Gaps
- I could not identify which maintainer objected to exchange rates in core; the statement is second-hand from a contributor.
- No explicit maintainer statement was found for investment tracking (#3678), PostgreSQL (#5284) or first-day-of-month (#975); those issue pages were not opened.
- The exact URL slug of the "Fighting AI slop" post and the AI usage policy page were not fetched; they exist in the checkout as `packages/docs/blog/2025-11-15-fighting-ai-slop.md` and `packages/docs/docs/contributing/ai-usage-policy.md`.
