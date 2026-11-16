# Feature gaps of Actual Budget versus competing budgeting apps (state as of November 2026)

Reading notes for the report writer:

- "Current status" was verified against the local checkout at `/home/user/actual` (docs in `packages/docs/`, blog/release posts in `packages/docs/blog/`, unreleased items in `upcoming-release-notes/`). The checkout's git remote is a fork (`1-TB/actual`), last commit 15 Nov 2026. Its release posts carry upstream PR numbers, and a web search independently surfaced the same "iOS app is in beta" FAQ text on actualbudget.org, so I treat it as representative of upstream, but items found only in `upcoming-release-notes/` are unreleased (post-26.11.0) and were not confirmed against the live site.
- Local-doc citations use the corresponding published URL (actualbudget.org/docs/... or /blog/...). I read the local file, not the live page.
- Source quality is uneven. Most 2026 "reviews" found are vendor comparison pages (Lunch Money, Carlo, Pocket Clear, Finny, Beancount.io) or thin affiliate/SEO sites (fincomparelab, valebyte, selfhosting.sh). They are labelled as such. They are useful as evidence of what competitors attack, less so as neutral assessment.
- Reddit threads could not be fetched (mirrors returned HTTP 503 or were not resolvable). Reddit content below comes only from search-result snippets and is marked "snippet only"; usernames/dates beyond what the snippet showed are not available.
- No coverage was found from large tech/finance outlets (XDA, NerdWallet, etc.) in this run; a search for XDA coverage returned none. That is a gap, not evidence that such coverage does not exist.

## Mobile: native apps, PWA, offline, widgets, notifications, quick entry, receipt capture

### Takeaway
The absence of official native apps is the single most repeated gap in 2026 reviews and competitor pages, usually paired with "no push notifications, no widgets, no photo/voice capture". It is now partly out of date: an official iOS app (a Capacitor wrapper around the PWA) is in TestFlight beta and Android scaffolding exists, but there is still no App Store/Play Store release, no official Android app, and no widgets, push notifications or receipt capture.

### Cited Findings

What reviewers and competitors say:
- fincomparelab review (Morgan Chen, published 19 Jul 2026, updated 1 Oct 2026): "The project has no official Actual Budget iOS app today"; says the mobile apps are deprecated and warns of a fake App Store impersonator; steers people wanting "a managed service with native mobile apps" to YNAB. Affiliate-style site — [fincomparelab](https://www.fincomparelab.com/?p=1279)
- Finny (competitor blog, 25 Oct 2026): "There is no official Actual app in the App Store"; the iPhone web app "works offline but still needs a server behind it"; "App Store listings with similar names are not made by the Actual project"; many users keep Actual on a laptop and "use something else on their phone for capture" — [Finny: Actual Budget alternatives 2026](https://getfinny.app/blog/actual-budget-alternatives-2026)
- Finny (21 Sep 2026): "Actual's mobile experience has improved, but it remains secondary to the desktop and web app"; people who "mostly budget from their phone" are told not to pick Actual — [Finny: Actual vs YNAB 2026](https://getfinny.app/blog/actual-budget-vs-ynab-2026)
- Carlo (competitor page, "pricing verified June 2026"): mobile app "No — deprecated, browser only"; "No push notifications. No widget. No voice entry."; "It does not parse voice input or attach photos to transactions"; "There is no App Store listing" — [Carlo vs Actual](https://carlo.money/compare/actual)
- Lunch Money (competitor page, 2026): "No dedicated iOS or Android apps" (PWA or desktop only) — [Lunch Money: Actual Budget alternative](https://lunchmoney.app/compare/actual-budget-alternative)
- Pocket Clear (competitor blog, June 2026): "the mobile experience is the web app installed as a PWA, not a native app"; lists home-screen widgets as a Pocket Clear feature — [Pocket Clear vs Actual](https://pocketclear.app/blog/pocket-clear-vs-actual-budget.html)
- valebyte (hosting-vendor blog, 10 Jul 2026): "YNAB's native mobile app is smoother and more mature than Actual's" — [valebyte](https://valebyte.com/en/blog/actual-budget-vs-ynab-self-hosted-vps/)
- Reddit r/ynab switcher (Jul 2024, snippet only): "I also really think I'll miss YNAB's mobile app"; another Reddit user found a server is needed for mobile to be usable — [r/ynab thread mirror](https://lr.in.psf.lt/r/ynab/comments/1e4ewh5/a_long_term_users_perspective_migrating_from_ynab)
- fincomparelab also notes that pull-to-refresh on a phone does not fetch new bank transactions (bank sync is out of my scope; noted only as a mobile-UX complaint) — [fincomparelab](https://www.fincomparelab.com/?p=1279)

Current status (verified in docs/checkout):
- FAQ now says: "An official iOS app is in beta testing and connects to your own server" via TestFlight with nightly builds; "There is no official Android app yet"; the web version is an installable responsive PWA; community maintains unofficial native clients — [Actual FAQ](https://actualbudget.org/docs/faq)
- The Vision doc still says "A native mobile app, often found in app stores and marketplaces, is not planned" — this contradicts the FAQ and appears stale — [Actual Vision](https://actualbudget.org/docs/vision)
- 26.8.0 (2 Aug 2026) added "basic structure for mobile app PWA wrapper" and updated "iOS and Android app icons and launch screens"; the checkout has `packages/mobile-client` with `ios/`, `android/` and `capacitor.config.ts`, i.e. the app is a wrapper of the web UI, not a separate native UI — [Release 26.8.0](https://actualbudget.org/blog/release-26-8-0)
- Unreleased notes (post-26.11.0) add haptic feedback "in the iOS and Android apps", TestFlight publishing from CI, and an iOS App Store listing kept in the repo — signals an App Store launch is being prepared but has not happened — [upcoming-release-notes (repo)](https://github.com/actualbudget/actual/tree/master/upcoming-release-notes)
- Offline on mobile: 26.6.0/26.7.0 fixed a "fatal error preventing PWA launch when offline on iOS devices"; 26.8.0 fixed the app "becoming unresponsive on Android when reopening after being in the background" — [Release 26.7.0](https://actualbudget.org/blog/release-26-7-0); [Release 26.8.0](https://actualbudget.org/blog/release-26-8-0)
- Mobile feature parity is an acknowledged gap: the maintainers' 2026 roadmap says the mobile view "still lacks a number of features that are available on desktop. We would like to bring that disparity down to close to 0 this year" — [Roadmap for 2026](https://actualbudget.org/blog/roadmap-for-2026)
- Parity progress in 2026: budget-automation UI on mobile and an experimental mobile calculator for amounts (26.7.0); a "#" tag button in mobile transaction edit (26.8.0); a mobile Tags page and copy/paste of mobile transactions are unreleased — [Release 26.7.0](https://actualbudget.org/blog/release-26-7-0); [Release 26.8.0](https://actualbudget.org/blog/release-26-8-0)
- Quick entry aid: Payee Locations (stable since 26.8.0) suggests nearby payees and can fill the nearest payee in one tap; it is mobile-only — [Payee Locations docs](https://actualbudget.org/docs/transactions/payee-locations)
- "Notifications" in Actual (added 26.10.0) is an in-app page of release notes and project announcements, not spending/bill alerts or push notifications — [Notifications docs](https://actualbudget.org/docs/notifications)

### Inferences
- Reviews written as late as October 2026 still say "no official app", so the TestFlight beta has little public visibility; until a store listing ships, the gap effectively persists for mainstream users, and look-alike App Store apps add confusion.
- Because the official app wraps the PWA, it is unlikely by itself to close the widget, push-notification, share-sheet or camera-capture gaps that competitors advertise; I found no docs for any of those.
- "Deprecated mobile apps" wording in reviews traces to the old FAQ text; it is now inaccurate but was accurate until mid-2026.

### Gaps
- No documentation found for home-screen widgets, push notifications, Siri/Shortcuts, or receipt photo capture in Actual; I take these as still absent but could not find an explicit maintainer statement.
- Could not read Reddit threads to gauge how switchers rate the PWA in practice (one snippet said it "worked fine").
- No independent hands-on review of the TestFlight iOS app was found.

## Reporting and analytics: reports, dashboards, custom reports, net worth, cash flow, trends, forecasting, export

### Takeaway
Reporting is the area where older criticism has aged worst: reviewers in 2026 mostly rate Actual's reports as equal to or better than YNAB's, and the remaining complaints are that they are less exhaustive than Firefly III or Monarch and that several of the newer analyses (forecast, Sankey, budget analysis, Monte Carlo, formulas) are still experimental.

### Cited Findings
- selfhosting.sh (26 Jan 2026, updated 18 Mar 2026) rates Actual's reports "Basic (spending trends)" and recommends Firefly III for "detailed reports, net worth tracking, or powerful rules". This understates Actual's documented reports (net worth and cash flow exist), so treat as low-accuracy — [selfhosting.sh](https://selfhosting-sh.pages.dev/compare/actual-budget-vs-firefly-iii/)
- Beancount.io (vendor blog, 26 Jul 2026): Actual's reporting is "solid, if intentionally less exhaustive than Firefly III's reporting"; Firefly recommended for multi-year reporting — [Beancount.io](https://beancount.io/blog/2026/07/26/firefly-iii-vs-actual-budget-self-hosted-open-source-budgeting-guide)
- Finny (21 Sep 2026): "YNAB's reports are simpler but clearer out of the box", while crediting Actual with powerful, customizable reports — [Finny: Actual vs YNAB 2026](https://getfinny.app/blog/actual-budget-vs-ynab-2026)
- fincomparelab (Jul 2026) presents reports as a strength (net worth, cash flow, custom report engine) but says bill payments "credit back into the budget, which muddles the spending charts" — [fincomparelab](https://www.fincomparelab.com/?p=1279)
- valebyte (Jul 2026) lists reports among features that "match (or beat) YNAB" — [valebyte](https://valebyte.com/en/blog/actual-budget-vs-ynab-self-hosted-vps/)
- Reddit (2024, snippet only): one switcher said reports were their main reason to move to Actual; another returned to YNAB specifically for Toolkit-for-YNAB reports — [r/ynab thread mirror](https://lr.in.psf.lt/r/ynab/comments/1e4ewh5/a_long_term_users_perspective_migrating_from_ynab)
- Monarch is credited by comparison sites with Sankey diagrams, custom reports, cash-flow visualisations and a budget forecast — [Slashdot comparison](https://slashdot.org/software/comparison/Actual-Budget-vs-Monarch-Money/)

Current status:
- Stable dashboard widgets: Cash Flow, Net Worth, Spending Analysis, Summary card, Calendar card, Text widget, Crossover Point, plus custom reports — [Reports docs](https://actualbudget.org/docs/reports/)
- Crossover report became first-party in 26.6.0; Age of Money became stable in 26.8.0 (it had been experimental in 26.5.0) — [Release 26.6.0](https://actualbudget.org/blog/release-26-6-0); [Release 26.8.0](https://actualbudget.org/blog/release-26-8-0)
- Still experimental as of the checkout's feature flags and docs: Balance Forecast report, Sankey report, Budget Analysis report, Monte Carlo retirement analysis, Formulas — [Experimental features docs](https://actualbudget.org/docs/experimental/)
- Balance Forecast (experimental, added 26.6.0) projects balances from schedules and, since 26.7.0, from future tracking-budget entries — [Release 26.7.0](https://actualbudget.org/blog/release-26-7-0)
- 26.11.0 added grouping custom reports by tags; 26.8.0 added day-level date ranges and CSV export of Budget Analysis reports — [Release 26.11.0](https://actualbudget.org/blog/release-26-11-0); [Release 26.8.0](https://actualbudget.org/blog/release-26-8-0)
- Unreleased: quarterly interval for custom reports, reorderable dashboards, API access to dashboard widgets — [upcoming-release-notes (repo)](https://github.com/actualbudget/actual/tree/master/upcoming-release-notes)

### Inferences
- The "weak reports" complaint is largely historical (pre-2025). The residual gap versus Monarch/Firefly is polish and discoverability, and the fact that forecasting and Sankey require opting in to experimental flags that the docs warn need regular backups.
- Investment-performance reporting is absent because there is no holdings model (see Accounts section), so net worth is balance-based only.

### Gaps
- No 2026 reviewer was found who tested the experimental forecast/Sankey reports against Monarch's equivalents.
- Could not confirm whether a general report-to-PDF/CSV export exists for all report types; only Budget Analysis CSV export and transaction CSV export were seen in release notes.

## Budgeting model: targets/goals UI, credit cards and debt, rollover, tracking vs envelope, loans, age of money, shared budgets

### Takeaway
The most-cited YNAB-parity gap is a graphical targets/goals UI; Actual's answer was text `#template` notes, and a GUI ("budget automations") now exists but remains experimental. Credit-card debt handling and loan accounts are the next most cited; both still rely on documented manual workarounds, and a debt account type promised in the 2026 roadmap has not shipped.

### Cited Findings

Targets and goals:
- Reddit r/ynab, "What YNAB has that Actual Budget doesn't have" (11 Aug 2024, snippet only): the big missing piece is "a graphical interface for the targets/goals"; a commenter counters that goal templates are "way more flexible/powerful than what YNAB offers" — [r/ynab thread mirror](https://lr.eu.psf.lt/r/ynab/comments/1ep7y3x/what_ynab_has_that_actual_budget_doesnt_have)
- Finny (Sep 2026): "Actual supports goal templates, but they take more setup"; names "guided targets" among Actual's polish shortfalls — [Finny: Actual vs YNAB 2026](https://getfinny.app/blog/actual-budget-vs-ynab-2026)
- Carlo (2026): "annual-expense templates are still experimental"; "no built-in flow for windfall allocation or variable income"; "does not tell you what you can spend today" — [Carlo vs Actual](https://carlo.money/compare/actual)
- Pocket Clear (Jun 2026): Actual has only "Budget goal templates", not savings goals as a first-class object — [Pocket Clear vs Actual](https://pocketclear.app/blog/pocket-clear-vs-actual-budget.html)
- Maintainers agree: 2026 roadmap says templates are "used by many, if not most of you" and promises "a proper GUI ... less prone to error", including predicting total needed, seeing all goals, and fill order — [Roadmap for 2026](https://actualbudget.org/blog/roadmap-for-2026)
- Status: a UI for budget automations was added as experimental in 26.6.0 and got mobile support in 26.7.0; both the text templates and the UI are still behind experimental flags (`goalTemplatesEnabled`, `goalTemplatesUIEnabled`) in the checkout — [Release 26.6.0](https://actualbudget.org/blog/release-26-6-0); [Budget automation docs](https://actualbudget.org/docs/experimental/budget-automation)
- Status: documented limitation — a long-term goal "does not automatically add funds or stop funds from being added after the goal has been hit"; a balance cap must be added — [Budget automation docs](https://actualbudget.org/docs/experimental/budget-automation)
- Unreleased: a goal progress ring beside underfunded categories, and showing the goal as soon as automations are saved — [upcoming-release-notes (repo)](https://github.com/actualbudget/actual/tree/master/upcoming-release-notes)

Credit cards and debt:
- fincomparelab (Jul 2026): Actual "assumes you can pay it off in full", so carrying a balance requires workarounds — [fincomparelab](https://www.fincomparelab.com/?p=1279)
- Status: the docs handle carried debt with a multi-step manual guide based on manual entry and reconciliation, rather than YNAB-style automatic credit-card payment categories — [Carrying Debt docs](https://actualbudget.org/docs/budgeting/credit-cards/carrying-debt)

Loans and mortgages:
- Maintainers' roadmap (Dec 2025): "Currently Actual only has a standard account ... less great for loans"; plan to "bring back account types ... starting with loan accounts"; today it must be done with rules and schedules — [Roadmap for 2026](https://actualbudget.org/blog/roadmap-for-2026)
- Status: no debt/loan account type appears in the docs or any 2026 release post reviewed; off-budget accounts "simply track balances over time". Loan functions (IPMT, PPMT, NPER) exist only as experimental formula functions (26.9.0) — [Accounts docs](https://actualbudget.org/docs/accounts/); [Release 26.9.0](https://actualbudget.org/blog/release-26-9-0)

Budget types and rollover:
- Lunch Money (2026) claims "Actual Budget only supports envelope-style budgeting" versus its own envelope, zero-based, rolling and monthly-cap modes. This is inaccurate: Actual has a Tracking Budget mode that "won't automatically rollover funds from month to month" — [Lunch Money page](https://lunchmoney.app/compare/actual-budget-alternative); contradicted by [Tracking Budget docs](https://actualbudget.org/docs/getting-started/tracking-budget)
- Reddit switcher (2024, snippet only): dislikes that scheduled future transactions entered in the register "affect the account balance and category available balance immediately" — [r/ynab thread mirror](https://lr.in.psf.lt/r/ynab/comments/1e4ewh5/a_long_term_users_perspective_migrating_from_ynab)

Age of money:
- Addressed: Age of Money was experimental in 26.5.0 and stable from 26.8.0 (2 Aug 2026) — [Release 26.8.0](https://actualbudget.org/blog/release-26-8-0)

Shared budgets and couples:
- Lunch Money (2026): sharing "requires exporting files or sharing access to your self-hosted server" — [Lunch Money page](https://lunchmoney.app/compare/actual-budget-alternative)
- Finny (Sep 2026): sharing is "Anyone with access to your server" versus YNAB's "Up to 6 people per subscription" — [Finny: Actual vs YNAB 2026](https://getfinny.app/blog/actual-budget-vs-ynab-2026)
- Pocket Clear (Jun 2026): "Actual Budget has no dedicated couples feature"; Carlo lists couple sharing as "Requires server setup" — [Pocket Clear vs Actual](https://pocketclear.app/blog/pocket-clear-vs-actual-budget.html); [Carlo vs Actual](https://carlo.money/compare/actual)
- Status: multi-user support with Basic/Admin roles and per-budget access exists, but requires configuring an OpenID provider — [Multi-user docs](https://actualbudget.org/docs/config/multi-user)

Onboarding and method guidance (raised as a model-adjacent gap):
- valebyte: "YNAB has more hand-holding"; Finny: Actual is "denser and closer to a spreadsheet" and "relies on its documentation and community" — [valebyte](https://valebyte.com/en/blog/actual-budget-vs-ynab-self-hosted-vps/); [Finny: Actual vs YNAB 2026](https://getfinny.app/blog/actual-budget-vs-ynab-2026)
- Status: an in-app tour for new users was added in 26.9.0 — [Release 26.9.0](https://actualbudget.org/blog/release-26-9-0)

### Inferences
- The goals gap is "narrowed but not closed": the GUI exists, yet a default install still shows no targets UI unless the user enables an experimental feature, so reviews saying templates "take more setup" remain fair.
- Credit-card debt and loans are the clearest unaddressed budgeting-model gaps versus YNAB (which has loan accounts with payoff simulation and automatic credit-card payment handling); the roadmap item for a debt account type looks missed for 2026.
- Per-user roles exist, but the OpenID prerequisite makes shared budgeting a self-hoster feature rather than a couples feature; the sharing critiques are about ease, not capability.

### Gaps
- Could not read Reddit threads in full, so the ranking of what YNAB switchers miss most rests on snippets plus the maintainers' own roadmap.
- No source found that discusses YNAB-style "underfunded" quick-budget actions or the Focus views specifically versus Actual.
- No reviewer comparison of Actual's rollover/overspending handling versus YNAB was found.

## Accounts and assets: multi-currency, investments, crypto, loans, attachments, tags, splits, schedules

### Takeaway
Multi-currency and investment tracking are the two structural asset gaps: Actual's docs still state it "does not support multi-currency", and investments are only manually updated off-budget balances. Transaction attachments/receipts and crypto are absent. Tags, by contrast, have been substantially built out through 2025-2026 and are no longer a real gap.

### Cited Findings

Multi-currency:
- Actual's own docs: "The Actual Budget software is currency agnostic and does not support multi-currency. People are working on implementing currency support, but it will take time"; the documented workaround uses rule templates, which were deprecated in 26.6.0 in favour of formulas — [Multi-currency docs](https://actualbudget.org/docs/budgeting/multi-currency); [Release 26.6.0](https://actualbudget.org/blog/release-26-6-0)
- Lunch Money (2026): "Multicurrency support is limited" versus its claimed 160+ currencies across accounts, budgets, transactions and reports — [Lunch Money page](https://lunchmoney.app/compare/actual-budget-alternative)
- Status: "Budget Currencies (still experimental)" was listed as a 2025 addition; in 2026 it is still behind the `currency` flag, and releases have mainly added currencies to the picker (CLP, IRR, PKR, MXN, ILS, MKD, PEN, UYU, ZAR, BDT, NOK, TZS). This is display currency for a budget, not per-account currencies with exchange rates — [Roadmap for 2026](https://actualbudget.org/blog/roadmap-for-2026); [Release 26.11.0](https://actualbudget.org/blog/release-26-11-0)
- selfhosting.sh lists multi-currency as supported in Actual, which conflicts with Actual's own docs; treat as an error in that source — [selfhosting.sh](https://selfhosting-sh.pages.dev/compare/actual-budget-vs-firefly-iii/); contradicted by [Multi-currency docs](https://actualbudget.org/docs/budgeting/multi-currency)

Investments and crypto:
- fincomparelab (Jul 2026): "Investment tracking is thin"; will not automatically price a portfolio; sends investors to Empower — [fincomparelab](https://www.fincomparelab.com/?p=1279)
- Lunch Money (2026): Actual "doesn't support tracking crypto tokens" — [Lunch Money page](https://lunchmoney.app/compare/actual-budget-alternative)
- selfhosting.sh recommends Firefly III for users "with many accounts (banks, cards, investments, loans)" — [selfhosting.sh](https://selfhosting-sh.pages.dev/compare/actual-budget-vs-firefly-iii/)
- Status: docs say off-budget accounts are "meant to track stuff like investments and mortgages" and "simply track balances over time"; no holdings, prices or performance. The experimental Monte Carlo report models stocks/bonds/cash mixes for retirement but is not portfolio tracking — [Accounts docs](https://actualbudget.org/docs/accounts/); [Release 26.10.0](https://actualbudget.org/blog/release-26-10-0)

Attachments and receipts:
- Lunch Money (2026): Actual "doesn't support file attachments on transactions"; Carlo: does not "attach photos to transactions" — [Lunch Money page](https://lunchmoney.app/compare/actual-budget-alternative); [Carlo vs Actual](https://carlo.money/compare/actual)
- Status: a search of the docs for attachments/receipts found no such feature (only community-project mentions) — [Community projects docs](https://actualbudget.org/docs/community-repos)

Tags and splits:
- Status: tags are implemented as `#hashtags` in the notes field, not a separate field; they cannot contain spaces. 2026 added tag autocomplete and creation (26.6.0), show/hide and "has any/all tags" filters (26.7.0), rename (26.9.0), and custom reports grouped by tag (26.11.0) — [Tags docs](https://actualbudget.org/docs/transactions/tags); [Release 26.11.0](https://actualbudget.org/blog/release-26-11-0)
- Status: split transactions are supported on desktop and mobile — [Split transactions docs](https://actualbudget.org/docs/transactions/split-transactions)

Schedules and recurring:
- Status: schedules support weekend adjustment and approximate amounts (±7.5%); 26.5.0 added a per-schedule "upcoming" window. "Upcoming" here is an in-ledger display, not a reminder or alert — [Schedules docs](https://actualbudget.org/docs/schedules); [Release 26.5.0](https://actualbudget.org/blog/release-26-5-0)
- Status: account groups (custom grouping of accounts in the sidebar) exist only in the experimental redesigned sidebar from 26.10.0 — [Release 26.10.0](https://actualbudget.org/blog/release-26-10-0)

### Inferences
- Multi-currency is the longest-running unresolved structural gap; the experimental flag gives currency formatting, and the only documented true multi-currency workaround depends on a deprecated mechanism, so the practical situation for expats and travellers may be getting worse before it gets better.
- Actual's investment gap is by design (budget-first scope) and is the main reason Monarch, Empower, Sure/Maybe-style net-worth apps are recommended instead; nothing in 2026 releases moves toward holdings tracking.
- Tags-in-notes is a design difference some users may still dislike versus Lunch Money/Monarch's dedicated tag field, but functionally the gap has closed.

### Gaps
- No 2026 source was found comparing Actual directly with Sure/Maybe, GnuCash, Tiller, Financier, Quicken/Simplifi or Copilot on features; searches returned only generic comparison-site pages. Statements about those competitors here are limited.
- No reviewer commentary found on split-transaction or schedule limitations specifically; the Reddit complaint about future-dated transactions is the only one.
- Did not verify what the experimental `currency` flag does beyond what release notes imply.

## Automation and ecosystem: rules, AI categorisation, API and integrations, plugins, importers, alerts, bill reminders

### Takeaway
The headline ecosystem gaps are the still-unshipped plugin system (promised for early 2026), an API that is an npm library rather than a hosted REST service, no built-in AI categorisation, and no spending alerts or bill reminders. Official import from other tools covers only YNAB4 and nYNAB.

### Cited Findings
- Plugins: maintainers said plugins were the one unmet 2025 goal, "have a tendency to break existing features", and hoped to have them "ready ... in the first few months of 2026" — [Roadmap for 2026](https://actualbudget.org/blog/roadmap-for-2026)
- Plugins status: no 2026 release post through 26.11.0 announces a user-facing plugin system, and there is no plugin feature flag in the checkout; selfhosting.sh describes the plugin ecosystem as "Limited" — [Release 26.11.0](https://actualbudget.org/blog/release-26-11-0); [selfhosting.sh](https://selfhosting-sh.pages.dev/compare/actual-budget-vs-firefly-iii/)
- API: Actual's docs state it "does not expose HTTP endpoints"; the API is a Node.js npm package that works on a local copy of the data, and "Other languages are not supported at this point" — [API docs](https://actualbudget.org/docs/api/)
- API as raised by others: fincomparelab notes it is "an npm package, not a REST API you can call"; Lunch Money says it "runs against your local data and requires a self-hosted sync server to use it across devices"; Beancount.io contrasts Firefly III's REST API — [fincomparelab](https://www.fincomparelab.com/?p=1279); [Lunch Money page](https://lunchmoney.app/compare/actual-budget-alternative); [Beancount.io](https://beancount.io/blog/2026/07/26/firefly-iii-vs-actual-budget-self-hosted-open-source-budgeting-guide)
- API status: the Actual CLI became stable in 26.7.0; a community "Local REST API" bridge is listed; per-budget API keys created from Security settings are in unreleased notes — [Release 26.7.0](https://actualbudget.org/blog/release-26-7-0); [Community projects docs](https://actualbudget.org/docs/community-repos)
- Rules: selfhosting.sh calls Actual's "Basic transaction rules" versus Firefly III's rule engine and recommends Firefly for "powerful rules" — [selfhosting.sh](https://selfhosting-sh.pages.dev/compare/actual-budget-vs-firefly-iii/)
- Rules status: rule action templating was deprecated in 26.6.0 in favour of formulas, which remain experimental — [Release 26.6.0](https://actualbudget.org/blog/release-26-6-0)
- AI: no built-in AI categorisation is documented; AI access is via three community MCP servers listed in the docs — [Community projects docs](https://actualbudget.org/docs/community-repos)
- Alerts and reminders: Carlo cites "No push notifications"; Actual's Notifications feature covers release notes and announcements only — [Carlo vs Actual](https://carlo.money/compare/actual); [Notifications docs](https://actualbudget.org/docs/notifications)
- Importers: docs say "Right now, only YNAB4 is officially supported" for migration, with nYNAB also documented; others rely on the API or community tools. Beancount.io says switching tools "still means manually rebuilding your account names, category structure, and opening balances" — [Migration docs](https://actualbudget.org/docs/migration/); [Beancount.io](https://beancount.io/blog/2026/07/26/firefly-iii-vs-actual-budget-self-hosted-open-source-budgeting-guide)
- Support and sustainability: reviewers list community-only support (Discord, GitHub) and volunteer maintenance as gaps versus company-backed apps — [Finny: Actual vs YNAB 2026](https://getfinny.app/blog/actual-budget-vs-ynab-2026); [Carlo vs Actual](https://carlo.money/compare/actual)

### Inferences
- Plugins are the linchpin: the maintainers tie new account types and additional providers to them, so their delay also explains the lack of progress on loans/investments.
- The API is capable (custom importers, MCP servers, CLI) but its library-plus-local-copy design is a real barrier for no-code integrations (Zapier, Shortcuts, webhooks) that Lunch Money and Firefly III users take for granted.
- No reviewer complained specifically about a missing AI categoriser; this is a gap relative to Copilot/Monarch marketing rather than a documented user complaint.

### Gaps
- Could not confirm the current state of the plugin work (branch status, target date) beyond the December 2025 roadmap; no later maintainer statement was found.
- No sources found on bill-reminder or budget-overspend alert requests from users; absence is inferred from docs.
- Did not find reviewer discussion of import from Mint, Monarch, Quicken or GnuCash.

## Which gaps are deal-breakers, and for whom

### Takeaway
Reviewers rarely use the word "deal-breaker", but they consistently redirect four groups elsewhere: phone-first budgeters, people wanting investments or a whole-net-worth picture, multi-currency users, and couples or beginners who want zero setup and guided targets. For desktop-first envelope budgeters, the same reviewers treat the remaining gaps as tolerable.

### Cited Findings
- Phone-first users: Finny says people who "mostly budget from their phone" should not pick Actual; fincomparelab sends users wanting native mobile apps to YNAB — [Finny: Actual vs YNAB 2026](https://getfinny.app/blog/actual-budget-vs-ynab-2026); [fincomparelab](https://www.fincomparelab.com/?p=1279)
- Investors: fincomparelab points users who need investment tracking to Empower — [fincomparelab](https://www.fincomparelab.com/?p=1279)
- Multi-account, multi-user and analysis-heavy users: selfhosting.sh recommends Firefly III for those needing detailed reports, powerful rules, many account types or multiple users, and Actual for envelope budgeters wanting offline use and simple deployment — [selfhosting.sh](https://selfhosting-sh.pages.dev/compare/actual-budget-vs-firefly-iii/)
- Couples and families: Finny lists people who "share a budget with a partner or family and want per-subscription sharing" as a poor fit — [Finny: Actual vs YNAB 2026](https://getfinny.app/blog/actual-budget-vs-ynab-2026)
- Beginners: fincomparelab says Actual "assumes more setup comfort" than YNAB or EveryDollar; Finny says those wanting "guided help, live workshops, or a support team" should look elsewhere — [fincomparelab](https://www.fincomparelab.com/?p=1279); [Finny: Actual vs YNAB 2026](https://getfinny.app/blog/actual-budget-vs-ynab-2026)
- Debt-carrying users: fincomparelab flags that the app "assumes you can pay it off in full" — [fincomparelab](https://www.fincomparelab.com/?p=1279)
- Scope framing: a competitor concedes Actual has "Extensive" power features and is simply not trying to be a whole-finances app; a Reddit commenter said Actual seemed to have "a tiny fraction of the features YNAB has" (2024, snippet only) — [Carlo vs Actual](https://carlo.money/compare/actual); [r/ynab thread mirror](https://lr.eu.psf.lt/r/ynab/comments/1ep7y3x/what_ynab_has_that_actual_budget_doesnt_have)

Summary table (status as of Nov 2026, from the findings above):

| Gap | Mainly raised by | Status |
|---|---|---|
| Native iOS/Android apps | Nearly every 2026 source | Partly addressed: iOS TestFlight beta; no store release; no official Android app |
| Widgets, push notifications, voice/photo capture | Carlo, Pocket Clear | Open |
| Mobile feature parity with desktop | Maintainers' roadmap | In progress |
| Targets/goals GUI | Reddit 2024, Finny 2026, roadmap | Partly addressed: experimental UI since 26.6.0 |
| Credit-card debt handling | fincomparelab 2026 | Open (manual guide) |
| Loan/debt account type | Maintainers' roadmap | Open (formula functions only, experimental) |
| Age of Money | YNAB switchers | Addressed (stable 26.8.0) |
| Multi-currency | Lunch Money, Actual docs | Open (experimental display currency only) |
| Investments, crypto | fincomparelab, Lunch Money | Open, out of scope by design |
| Attachments/receipts | Lunch Money, Carlo | Open |
| Tags | Older comparisons | Addressed (2025-2026) |
| Forecasting, Sankey | Monarch comparisons | Partly addressed (experimental) |
| Plugins | Maintainers, selfhosting.sh | Open (missed early-2026 target) |
| REST/cloud API | fincomparelab, Lunch Money | Open (npm library, CLI, community bridge) |
| Spending alerts, bill reminders | Carlo | Open |
| Easy partner sharing | Lunch Money, Finny, Pocket Clear | Partly addressed (multi-user needs OpenID) |
| Guided onboarding | valebyte, Finny | Partly addressed (in-app tour 26.9.0) |

### Inferences
- The gaps most likely to be true deal-breakers are structural ones with no workaround inside the product: per-account multi-currency, investment holdings, and receipt attachments. Mobile and goals are high-frequency complaints but are actively closing.
- Segments most affected: phone-first and partner-sharing households (mobile, sharing, alerts); expats and travellers (multi-currency); users in debt payoff (credit-card and loan modelling); "whole financial picture" users coming from Mint/Monarch/Quicken (investments, alerts, attachments). Least affected: desktop-first YNAB-method budgeters.
- Many 2026 review pages lag the product by months (still describing deprecated mobile apps, no Age of Money, basic reports), so perceived gaps are larger than actual ones; store presence and promoting features out of experimental would close much of the perception gap.

### Gaps
- No survey or quantitative data found on why users leave Actual; segment conclusions rest on reviewer recommendations and vendor marketing.
- The evidence base is dominated by competitor and SEO content; independent hands-on reviews from established outlets and full Reddit threads were not obtainable in this run.
- Copilot, Tiller, Quicken/Simplifi, GnuCash, Financier and Maybe/Sure were named in the brief but no source comparing them feature-by-feature with Actual was found.
