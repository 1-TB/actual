# Community sentiment and self-hosting complaints about Actual Budget (non-GitHub venues)

> Research caveats that apply to every section (read first):
>
> - **Reddit could not be read directly.** `reddit.com` / `old.reddit.com` fetches are blocked in this environment, and the redlib mirrors tried returned 503/403. Web search did not index r/actualbudgeting threads usefully. Reddit evidence below is therefore limited to **search-result snippets** (marked "snippet only, not verified against the thread"). No verbatim, attributable Reddit quotes with usernames were obtained. r/ynab, r/personalfinance and r/opensource yielded nothing.
> - **Hacker News was searched via the Algolia API** (stories and comments, 2023-07 onward). Only the first page (40-50 of ~121 comment hits) of each query was read; pages 2-4 were not.
> - Overall the evidence base is **thin**: about 20 distinct complaint data points, many of them one-line remarks. Recurrence counts below are counts within this small sample, not prevalence estimates.
> - Several "review" sites found are SEO-style blogs, some selling competing products; they are labelled as such and should be weighted low.

## What are the most common complaints (general usability, learning curve, UI polish, onboarding, documentation, stability, data loss, sync conflicts, update breakage)?

### Takeaway
In the venues that could be read, general-experience criticism is mild and low-volume: small UX rough edges, thin dashboards/reports, no notifications, no native mobile app, and "less user friendly" than commercial apps. The single clearest onboarding failure is not in the budgeting UI at all but the silent failure when the server is opened without HTTPS (covered in the self-hosting section). No first-hand data-loss or sync-conflict horror stories were found outside GitHub.

### Cited Findings

UX polish / usability (4 data points, all mild)
- HN, Semaphor, 2025-11-21, on moving to Actual: "Some tiny ux issues, but improvement in many more areas." — [HN comment 46008459](https://news.ycombinator.com/item?id=46008459)
- HN, Ronnie76er, 2025-11-22: "Some things are better and some things worse than YNAB, but it's open source and self-hosted." — [HN comment 46017870](https://news.ycombinator.com/item?id=46017870)
- AlternativeTo, Robert Yates, 2025-04-08 (5-star review): "Not as user friendly as Simplifi but still pretty simple once you connect your accounts." — [AlternativeTo](https://alternativeto.net/software/actual-budget/about)
- HN, coffeecoders, 2025-07-05, explaining why they built their own tool: "Actual Budget etc is too heavy so I built this." — [HN comment 44474688](https://news.ycombinator.com/item?id=44474688)

Reports / dashboard / notifications (3 data points)
- HN, ramon156, 2025-02-07: "So far Actual Budget is pretty good, although I wish the dashboard was a bit more extensive." — [HN comment 42978295](https://news.ycombinator.com/item?id=42978295)
- HN, anthropodie, 2025-01-05, answering someone who wanted spending alerts: "It won't notify you but it has dashboard that can show you how you are spending" — [HN comment 42603350](https://news.ycombinator.com/item?id=42603350)
- Review blog (Expense Sorted, published 2026-05-05, updated 2026-09-20; vendor of its own finance products, so biased): "The built-in reports cover essentials but lack the depth of a custom spreadsheet." — [Expense Sorted](https://www.expensesorted.com/blog/144_actual_budget)

Mobile (3 data points)
- AlternativeTo, syntax, 2022-12-02 (4 stars; OLD): "The only missing part for me is a mobile version, as the native apps were discontinued." A reply from wdpk on 2024-06-30 notes the web app can now be installed as a PWA and works offline, i.e. partially addressed. — [AlternativeTo](https://alternativeto.net/software/actual-budget/about)
- HN, bombcar, 2026-04-06, in a thread about web apps vs native apps, on Actual's web-only mobile experience: "but a button on the home screen would be nicer." — [HN comment 47662261](https://news.ycombinator.com/item?id=47662261)
- Expense Sorted (2026): "There is no official Android app yet." and mobile is "not quite YNAB-level polish." The same article says an iOS app is in TestFlight beta; this could not be corroborated and may refer to third-party clients. — [Expense Sorted](https://www.expensesorted.com/blog/144_actual_budget)
- Third-party native iOS clients keep being launched on HN (a SwiftUI client 2025-10-04; "Actuali: free Actual Budget client for iOS" 2026-09-13), which indicates the gap is still felt. — [HN story 45475902](https://news.ycombinator.com/item?id=45475902); [HN story 49680654](https://news.ycombinator.com/item?id=49680654)

Onboarding / workflow fit
- AlternativeTo, Simon, 2025-03-26: the app "didn't do the job for me"; "there were no viable options to automatically categorize or pre-process the data", and handling quarterly/yearly bills was difficult. (Partly an import/categorisation complaint, which is out of this note's scope; the irregular-bills part is general budgeting UX.) — [AlternativeTo](https://alternativeto.net/software/actual-budget/about)
- Expense Sorted (2026): "The ecosystem is smaller", with fewer tutorials than YNAB, so users solve edge cases themselves. — [Expense Sorted](https://www.expensesorted.com/blog/144_actual_budget)

Stability / sync / updates
- No first-hand report of data loss or sync conflict was found on Reddit, HN, Lemmy or forums in this research. The only data-loss account surfaced by search was a 2022 GitHub issue mirrored on Lightrun (a sync reset replacing a budget with a previously deleted one); it is old, on the issue tracker, and out of scope. — [Lightrun mirror](https://lightrun.com/answers/actualbudget-actual-your-data-is-still-out-of-sync)
- The official sync docs describe a version-mismatch failure mode: a device that receives data it cannot apply because the app is out of date must be updated before sync works; and after a sync reset "other devices cannot sync anymore" until reverted. — [Actual docs: syncing across devices](https://www.actualbudget.com/docs/overview/syncing-across-devices)
- Release 26.10.0 added a warning for API and CLI users when synced changes from a newer Actual version are waiting on an update (per search-result summary of the release post; not fetched in full). — [Actual release 26.10.0](https://actualbudget.org/blog/release-26.10.0)
- Cloudron forum, abuyuy, 2024-05-10: "I can't update to 24.5 version". This was a Cloudron packaging mistake fixed the next day (re-released as package 1.2.1), not an Actual defect. RESOLVED. — [Cloudron forum](https://forum.cloudron.io/topic/10774/actual-package-updates/25)
- The Cloudron package changelog notes that existing installs were switched to non-SSO mode after one package update (changelog note, not a user complaint). — [Cloudron forum](https://forum.cloudron.io/topic/10774/actual-package-updates/25)

### Inferences
- Outside GitHub, Actual attracts little hostile commentary; most mentions on HN are recommendations with a one-clause caveat. The complaint volume found is far lower than the task's premise assumed, though the Reddit blind spot means this cannot be generalised.
- The recurring "soft" themes are: reporting/dashboard depth, absence of notifications, mobile being a PWA rather than a native app, and general polish relative to paid apps. All appear still valid as of 2026.
- The version-mismatch sync behaviour (all devices and the server must be on compatible versions) is a plausible source of "update broke my sync" complaints given the monthly release cadence, but no user quote confirming it was found here.

### Gaps
- r/actualbudgeting, r/selfhosted, r/ynab and r/personalfinance threads could not be read; the most common Reddit complaints are therefore unknown from this research. A researcher with Reddit access should re-run this question.
- No sourced complaints were found about documentation quality, learning curve of envelope budgeting in Actual, or UI aesthetics beyond the items above.
- No sourced first-hand data-loss, corruption, or sync-conflict reports in community venues.
- HN comment search pages 2-4 (about 80 more hits) were not read.

## What reasons do people give for leaving Actual Budget or choosing something else after trying it?

### Takeaway
Very few explicit "I left" accounts were found. The stated reasons in the sample are: too heavy for simple needs, could not get the workflow to fit (auto-categorisation, irregular bills), and not being able to get it set up at all.

### Cited Findings
- "Too heavy": coffeecoders built their own tracker instead, 2025-07-05: "Actual Budget etc is too heavy so I built this." — [HN comment 44474688](https://news.ycombinator.com/item?id=44474688)
- Workflow misfit: Simon, 2025-03-26, the app "didn't do the job for me". — [AlternativeTo](https://alternativeto.net/software/actual-budget/about)
- Failed setup: Lemmy (Selfhosted@lemmy.world, thread "What else should I self-host?", about one year old when viewed in Nov 2026; absolute date not shown), blitzen@lemmy.ca: "I've had the same problem with getting Actual set up." — [Lemmy thread](https://yall.theatl.social/comment/10484097)
- No hosted option (older, 2022): Korwin, 2022-06-05 (2 stars), quoting the then-site notice: "New signups are currently disabled until we figure out a plan for a potential hosted option." OLD; the project has since settled on self-hosting plus third-party hosts rather than restoring an official service, so the underlying gap persists in a different form. — [AlternativeTo](https://alternativeto.net/software/actual-budget/about)
- Review blogs frame the likely leaver as someone wanting "hand-holding" and polish; this is reviewer opinion, not user testimony. — [Expense Sorted](https://www.expensesorted.com/blog/144_actual_budget)
- A targeted search for "stopped using" / "gave up on" / "moved away from" Actual Budget returned no departure stories, only positive or neutral reviews. — [search result example: deuts.net 2024 review](https://deuts.net/2024/06/actual-budget-is-the-opensource-selfhosted-alternative-to-ynab/)

### Inferences
- Abandonment appears to happen mostly at the setup stage (cannot get it running) or early in use (workflow does not match), rather than after long-term use; but the sample is three data points.

### Gaps
- No Reddit "why I left Actual" threads could be read. This question is essentially unanswered at scale.

## What do users say about self-hosting friction (server setup, HTTPS requirement, Docker, updates, backups, PikaPods/Fly.io, lack of an official hosted service)?

### Takeaway
The HTTPS requirement is the most consistently documented friction point across venues (Lemmy, TrueNAS forum, a blog post, and r/selfhosted snippets): the app refuses to work over plain HTTP, the failure can be a silent infinite spinner or a "SharedArrayBuffer" fatal error, and non-expert users get stuck on reverse proxies, local DNS and certificates. The lack of an official hosted service is noted, with PikaPods cited as the workaround.

### Cited Findings

HTTPS requirement (6 data points, 2023-2025; STILL VALID as of Oct 2025)
- Blog, David Bures, 2023-12-03: after install the app showed "An empty screen with an infinite loading spinner. What now?"; searching gave "no useful results"; Safari showed no error and only Firefox surfaced the cause; the fix was simply to use HTTPS. The author preferred not to ask on Discord: "I have social anxiety, so I'd prefer not to do that." OLDER (2023); the error is now surfaced more explicitly (see next item) but the requirement itself remains. — [buresdv.substack.com](https://buresdv.substack.com/p/actual-budget-how-to-fix-infinite)
- TrueNAS forum, Wayda, 2025-10-07 to 2025-10-10: installing the catalog app (Actual 25.10.0) gave the fatal error "Actual requires access to `SharedArrayBuffer` in order to function properly." A responder (dan) said the catalog version "doesn't appear to enable HTTPS" and recommended Nginx Proxy Manager; the user, with limited experience, then had to ask about domain placeholders, Pi-hole, redirects and local DNS. The thread ends without a confirmed fix. — [TrueNAS forum](https://forums.truenas.com/t/help-with-actual-budget-installation/55462)
- An earlier TrueNAS thread, "Installing Actual-Budget", exists on the same topic (not fetched). — [TrueNAS forum](https://forums.truenas.com/t/installing-actual-budget/31319)
- Lemmy, PlutoniumAcid@lemmy.world (about 2025): "Correct. It refuses to run without https. That is by design." and, sceptically, "They probably think they have a good reason for it." The comment being answered was deleted. — [Lemmy thread](https://yall.theatl.social/comment/10484097)
- r/selfhosted, "Thoughts on Actual budgeting app", 2024-06-10 (snippet only, not verified against the thread): a commenter says the HTTPS requirement "tripped me up initially too" and suggests Tailscale serve/funnel; others recommend Caddy or Traefik. — [redlib mirror of thread](https://redlib.cypherpunktools.com/r/selfhosted/comments/1dcq0e6/thoughts_on_actual_budgeting_app)
- r/selfhosted, 2024-12-04, thread about local-only domain names and HTTPS (snippet only): a reply notes you must install a certificate on every device used to access the service. — [redlib mirror of thread](https://redlib.hbubli.cc/r/selfhosted/comments/1h6qstx/setup_local_only_domain_name_and_https_possible)
- The official docs acknowledge the requirement and document two local approaches plus a reverse-proxy route for internet access. — [Actual docs: HTTPS](https://actualbudget.org/docs/config/https)

Docker / skills barrier
- Expense Sorted (2026, biased source): "Self-hosting has a learning curve." Running the sync server needs basic Docker or command-line familiarity. — [Expense Sorted](https://www.expensesorted.com/blog/144_actual_budget)
- Lemmy, blitzen@lemmy.ca: "I've had the same problem with getting Actual set up." — [Lemmy thread](https://yall.theatl.social/comment/10484097)

No official hosted service / third-party hosting
- HN, matthiaswh, 2026-07-17, recommending Actual with a caveat: "There's no cloud version but it still largely fits your criteria." — [HN comment 48945666](https://news.ycombinator.com/item?id=48945666)
- HN, bombcar, 2026-05-13, mentions Actual as an app PikaPods hosts (neutral/positive; cited as the standard workaround, not a complaint). — [HN comment 48122203](https://news.ycombinator.com/item?id=48122203)
- Review sites disagree on hosting status: one says the hosted subscription service shut down and everything is now community self-host; another lists a hosted option at $6/month. The latter likely refers to third-party hosting or is stale; treat as unresolved. — [myownsuite.org](https://myownsuite.org/docs/apps/actual-budget/); [lemsubs.com review](https://lemsubs.com/reviews/actual-budget)

Backups / updates
- A review notes "backups and updates are yours" as the standing cost of self-hosting (reviewer statement, not a user complaint). — [myownsuite.org](https://myownsuite.org/docs/apps/actual-budget/)

### Inferences
- The HTTPS/SharedArrayBuffer wall disproportionately hits the least technical self-hosters (NAS app-catalog users on TrueNAS, LAN-only users), because one-click catalog installs produce an HTTP endpoint that the app then rejects. The complaint has persisted from at least Dec 2023 through Oct 2025.
- Improvement over time: the 2023 symptom was a silent infinite spinner in Safari; by 2025 users see an explicit SharedArrayBuffer/HTTPS error. The message is clearer, but the remediation (reverse proxy, DNS, certificates) is unchanged and still beyond some users.
- Absence of an official hosted tier is mentioned as a caveat rather than an angry complaint; PikaPods appears to absorb most of that demand.

### Gaps
- No sourced user complaints specifically about PikaPods or Fly.io hosting quality, Docker image/update mechanics, or backup/restore difficulty were found.
- Reddit snippets on HTTPS could not be verified against the original threads; usernames and exact wording are unavailable.

## What do users say about multi-user or shared household use, partner access, and permissions?

### Takeaway
Almost no community complaints were found; what exists is confusion about whether shared use is possible at all, plus third-party reviews (some apparently outdated) saying partner sharing and granular permissions are missing. The project's own security policy reportedly states that user roles are not a security boundary between users on one server.

### Cited Findings
- Cloudron forum, IniBudi, 2026-02-20: "My question is, if I wanna track finances together with my wife, is that possible?" after enabling OpenID; staff (fbartels) answered yes, via the "server online" menu. Shows discoverability confusion, not a defect. — [Cloudron forum](https://forum.cloudron.io/topic/15098/collaborative-budget-tracking-on-actual-budget-with-family-members/3)
- Expense Sorted (2026; biased, possibly outdated): "Actual Budget doesn't have built-in support for shared budgets between partners", with no granular permissions or separate individual/joint views. This conflicts with the official docs, which describe a shared budget file used by both partners and a multi-user (OpenID) mode. — [Expense Sorted](https://www.expensesorted.com/blog/144_actual_budget); contradicted by [Actual docs: joint accounts](https://actualbudget.org/docs/budgeting/joint-accounts) and [Actual docs: OpenID](https://actualbudget.org/docs/config/oauth-auth/)
- Official docs: multi-user support must be explicitly enabled via OpenID/OAuth2; the first user to log in becomes admin/server owner. — [Actual docs: OpenID](https://actualbudget.org/docs/config/oauth-auth/)
- Multi-user/OpenID support arrived in v25.1 (January 2025) after a long-running request (per search-result summary; GitHub pages not opened). Before that, a household shared one server password. — [Actual docs: OpenID](https://actualbudget.org/docs/config/oauth-auth/)
- Per search-result summary of the project's security policy (not fetched): Basic/Admin roles and budget ownership are organisational and "not a security boundary" between users on the same server; all account holders are treated as trusted. — [Actual security policy](https://github.com/actualbudget/actual/security)
- A third-party write-up discusses server exposure where password access is "only the first boundary" (not fetched; title only). — [dev.to](https://dev.to/jeffreyciend/actual-budget-server-exposure-password-access-is-only-the-first-boundary-4i4m)

### Inferences
- The still-valid gap is fine-grained permissions (read-only partner, per-category or per-account visibility, separate personal plus joint views within one budget), not basic sharing, which works.
- Review sites still repeating "no shared budgets" in 2026 suggests the multi-user feature is poorly known or poorly surfaced, consistent with the Cloudron user's question.

### Gaps
- No Reddit or HN user quotes about partner onboarding, simultaneous-edit conflicts, or permission needs were obtained.
- The security-policy wording is from a search summary and should be verified directly before quoting.

## What do users say about project governance, pace of development, and support (Discord-centric support, breaking changes, monthly release cadence)?

### Takeaway
No direct community complaints about governance, release pace or breaking changes were found in readable venues. The only support-channel friction found is one blogger who avoided asking on Discord and could not find answers via search, plus reviewer notes that support is community-only.

### Cited Findings
- Blog, 2023-12-03: troubleshooting by web search gave "no useful results", and the author did not want to ask on Discord ("I have social anxiety, so I'd prefer not to do that."), so wrote up the fix publicly. Illustrates the cost of support knowledge living in a non-indexed chat. OLDER. — [buresdv.substack.com](https://buresdv.substack.com/p/actual-budget-how-to-fix-infinite)
- Expense Sorted (2026, biased): "There's no phone support line."; help is community-based and users handle most troubleshooting themselves. — [Expense Sorted](https://www.expensesorted.com/blog/144_actual_budget)
- A review describes the project as maintained by a community team with roughly monthly releases and no company behind it (descriptive, not a complaint). — [myownsuite.org](https://myownsuite.org/docs/apps/actual-budget/)
- Downstream packagers track monthly version bumps (Cloudron changelog through 26.1.0 at the time of the search result); one package update changed auth mode for existing installs (non-SSO), a packager-level behaviour change. — [Cloudron forum](https://forum.cloudron.io/topic/10774/actual-package-updates/25)
- A review warns of a fake/unofficial iOS app trading on the Actual Budget name (title only; not fetched). — [fincomparelab.com](https://www.fincomparelab.com/reviews/actual-budget-review/)

### Inferences
- Because troubleshooting knowledge sits largely in Discord, it is not discoverable by search; this matches how little complaint or troubleshooting material this research could find on the open web at all.
- Monthly releases combined with the "all devices must be up to date to sync" behaviour create a standing update obligation for self-hosters, but no user was found complaining about cadence itself.

### Gaps
- No sourced complaints about governance, maintainer responsiveness, feature-request voting, breaking changes, or release quality. Discord itself was not searchable.
- No evidence either way on whether users consider development pace too slow or too fast.
