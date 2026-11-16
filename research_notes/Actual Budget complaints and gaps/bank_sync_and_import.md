# Bank sync, file import and migration: complaints and gaps in Actual Budget (state as of mid-November 2026)

Source notes for the writer:

- "Local docs" below means the docs in the repository checkout (last commit 15 Nov 2026), cited by their published URL on actualbudget.org. Release-note items are cited to the published release blog post; PR numbers are given so they can be checked.
- GitHub caveat: in actualbudget/actual, feature requests are auto-closed by a bot and labelled "needs votes". A "closed" feature request therefore does NOT mean it was implemented. Bugs closed as completed usually are fixed.
- Reddit could not be fetched (redlib mirrors returned HTTP 403, web search surfaced no r/actualbudgeting threads). Almost all user-voice evidence here is from GitHub issue threads. See Gaps.

## 1. Which bank sync providers does Actual support as of November 2026, in which regions, at what cost? What changed with GoCardless?

### Takeaway
Actual ships five providers, each tied to one region and each requiring the user to obtain their own API credentials and run the sync server: Akahu (NZ), Enable Banking (Europe, still experimental), GoCardless (Europe, closed to new signups since July 2025), SimpleFIN Bridge (North America, US$1.50/month) and Pluggy.ai (Brazil). The GoCardless closure left new European and UK users without a built-in option for roughly ten months (July 2025 to the June 2026 release), and UK coverage remains the weakest point.

### Cited Findings

Provider list and general constraints
- The official provider list is: Akahu (New Zealand banks), Enable Banking (European banks), GoCardless BankAccountData (European banks, "not accepting new accounts"), SimpleFIN Bridge (North American banks), Pluggy.ai (Brazilian banks). — [Actual docs: Connecting Your Bank](https://actualbudget.org/docs/advanced/bank-sync/)
- Bank sync "relies on you providing your own API credentials", "only works if you are using actual-server", and needs a config file. — [Actual docs: Connecting Your Bank](https://actualbudget.org/docs/advanced/bank-sync/)
- Bank sync secrets are stored on the server and are "not covered by end-to-end encryption"; server admins or hosting providers can read bank sync tokens. (Doc clarification added in 26.5.0, PR #7392.) — [Actual docs: Connecting Your Bank](https://actualbudget.org/docs/advanced/bank-sync/); [release 26.5.0](https://actualbudget.org/blog/release-26.5.0)
- Since 25.6.0 the sync server can be run from inside the desktop app, pitched as making "it much simpler to get access to features such as bank sync". — [release 25.6.0](https://actualbudget.org/blog/release-25.6.0)

GoCardless (formerly Nordigen), Europe
- "From July 2025 onwards, GoCardless has stopped accepting new Bank Account Data accounts... if you are an existing user, your account should continue to work." — [Actual docs: GoCardless Setup](https://actualbudget.org/docs/advanced/bank-sync/gocardless/)
- Free tier limits per the docs: up to 50 bank connections per month, each bank syncable up to 4 times per day. — [Actual docs: GoCardless Setup](https://actualbudget.org/docs/advanced/bank-sync/gocardless/)
- Issue #5445 "Alternative to GoCardless" (opened 1 Aug 2025, 27 thumbs-up): poster's bank was supported, but GoCardless support said it had stopped offering the API to new personal users. — [GitHub #5445](https://github.com/actualbudget/actual/issues/5445)
- Issue #6617 (11 Jan 2026): "With GoCardless closing the option to create new accounts, people with EU banks cannot reliably sync automatically"; the poster called it a likely reason for stagnant adoption in EU regions. — [GitHub #6617](https://github.com/actualbudget/actual/issues/6617)
- A user in #5445 (27 Feb 2026) said the lack of UK bank support made Actual unusable for them without manual imports. — [GitHub #5445](https://github.com/actualbudget/actual/issues/5445)
- GoCardless is still maintained for existing users: Actual replaced the nordigen-node library with its own implementation (26.5.0, #7352), and continued to fix GoCardless issues through 26.11.0 (expired access token handling #9088, surfacing IP-block/rate-limit reasons #8778). — [release 26.5.0](https://actualbudget.org/blog/release-26.5.0); [release 26.11.0](https://actualbudget.org/blog/release-26.11.0)

Enable Banking, Europe (the GoCardless replacement)
- Timeline from #5445: proposed 6 Aug 2025; Enable Banking's CTO said they would offer a free option for Actual users (22 Nov 2025); maintainers targeted 26.1.0; Enable Banking's terms were updated to allow personal use (10 Jan 2026); the original PR (#5570) stalled because its author left; implemented in PR #7345. — [GitHub #5445](https://github.com/actualbudget/actual/issues/5445)
- Shipped as experimental in 26.6.0 (1 June 2026): "Experimental: Add Enable Banking integration as a bank sync provider". — [release 26.6.0](https://actualbudget.org/blog/release-26.6.0)
- Still behind an experimental flag in the current docs ("Enable Banking sync (EU banks)", feedback issue #7799), with the note that functionality "may not be available in the latest stable release". — [Actual docs: Enable Banking Setup](https://actualbudget.org/docs/advanced/bank-sync/enable-banking/)
- Setup constraints: the server must be reachable over HTTPS; setup must be done in a web browser because the desktop app's `app://` redirect is rejected; one Enable Banking application per server shared by all budget files (a second application replaces the first and its accounts stop syncing). — [Actual docs: Enable Banking Setup](https://actualbudget.org/docs/advanced/bank-sync/enable-banking/)
- Bank access "lasts for 90 days at most, and some banks allow less"; when it lapses syncing stops and the user must reauthorize and re-map each account. — [Actual docs: Enable Banking Setup](https://actualbudget.org/docs/advanced/bank-sync/enable-banking/)
- Cost: Enable Banking's free "restricted mode" only exposes accounts the user has first linked in the Enable Banking control panel; terms allow production use for linked accounts for evaluation or personal use by private individuals; the number of linked accounts may be capped; commercial pricing is volume-based with no public price list. — [Firefly III Enable Banking tutorial](https://docs.firefly-iii.org/tutorials/data-importer/eb/); [Enable Banking Terms](https://enablebanking.com/terms); [Enable Banking FAQ](https://enablebanking.com/docs/faq)
- UK coverage is disputed/thin: users in #5445 said it lacked UK banks (Dec 2025, Feb 2026); in #6617 a user said (May 2026) it now covers UK banks and the issue author replied only six banks were listed. — [GitHub #5445](https://github.com/actualbudget/actual/issues/5445); [GitHub #6617](https://github.com/actualbudget/actual/issues/6617)

SimpleFIN Bridge, North America
- Price: "$1.50 + tax per month, or $15.00 + tax per year"; "Connect up to 25 institutions and 25 apps". — [SimpleFIN Bridge](https://beta-bridge.simplefin.org/)
- Actual's docs: sync pulls at most 90 days of history per account (less for some), and SimpleFIN data updates about once per day per account, at times that vary by bank and by the upstream provider (MX). — [Actual docs: SimpleFIN Setup](https://actualbudget.org/docs/advanced/bank-sync/simplefin/)
- SimpleFIN became stable in server/client 24.10.0. — [Actual docs: SimpleFIN Setup](https://actualbudget.org/docs/advanced/bank-sync/simplefin/)
- Per-budget SimpleFIN credentials arrived in 26.11.0 (#9214); self-hosted SimpleFIN bridges on private networks now require a server allowlist (#9245). — [release 26.11.0](https://actualbudget.org/blog/release-26.11.0)

Pluggy.ai, Brazil
- Added experimentally in 25.4.0 (#4049); "Release pluggy bank-sync integration" in 25.9.0 (#5628). — [release 25.4.0](https://actualbudget.org/blog/release-25.4.0); [release 25.9.0](https://actualbudget.org/blog/release-25.9.0)
- Free access goes through "Meu Pluggy", which can only be connected while the pluggy.ai trial period is active; afterwards the connector list is not editable. Users must copy Item IDs by hand from the Pluggy demo app. Item IDs expire if access is revoked or the token expires. — [Actual docs: Pluggy.ai Setup](https://actualbudget.org/docs/advanced/bank-sync/pluggyai/)
- The Pluggy docs page still says the integration "is experimental at this point" and must be enabled under experimental features, which conflicts with the 25.9.0 "release" note. — [Actual docs: Pluggy.ai Setup](https://actualbudget.org/docs/advanced/bank-sync/pluggyai/); contradicted by [release 25.9.0](https://actualbudget.org/blog/release-25.9.0)
- Origin was a heavily voted request: #3995 "Open Banking from Brazil" had 42 thumbs-up. — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+bank+sync+sort%3Areactions-%2B1-desc)

Akahu, New Zealand
- Added as experimental in 26.7.0 (#6041). — [release 26.7.0](https://actualbudget.org/blog/release-26.7.0)
- Setup requires creating a personal Akahu app, agreeing to developer terms, identity verification and MFA, then pasting an App ID token and User Access Token. — [Actual docs: Akahu Setup](https://actualbudget.org/docs/advanced/bank-sync/akahu/)
- The Akahu feedback issue (#8020) was closed on 4 Nov 2026 and the current Akahu docs page carries no experimental warning. — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+csv+import+%28mapping+OR+duplicate+OR+date+OR+profile%29+sort%3Aupdated-desc); [Actual docs: Akahu Setup](https://actualbudget.org/docs/advanced/bank-sync/akahu/)

Maintainer stance on adding providers
- Maintainer (2 Sep 2025): the team is cautious about which providers it ships in order to protect user data; providers are evaluated individually and some have been rejected; other providers are expected to become possible through a future plugin system as "use-at-own-risk" options. — [GitHub #5445](https://github.com/actualbudget/actual/issues/5445)

### Inferences
- Every provider is "bring your own aggregator account": there is no one-click, Actual-brokered connection as in YNAB/Monarch. Cost to the user is low (free to US$15/year) but the setup burden (developer portals, tokens, HTTPS callback URLs, identity verification) is high for non-technical users.
- New European users had no first-party sync between July 2025 and June 2026, and what they have now is still labelled experimental roughly five months after shipping.
- Akahu appears to have graduated from experimental around November 2026 (feedback issue closed, no warning in docs); I did not find a release note stating this explicitly.

### Gaps
- No authoritative statement on whether existing GoCardless users have since been cut off or told of a shutdown date; the docs only say existing accounts "should continue to work".
- No reliable count of Enable Banking's UK institutions as of Nov 2026.
- Could not confirm SimpleFIN's Canadian coverage from a primary source; SimpleFIN's landing page names no countries (it links to an institution search), and Actual's docs say only "North American Banks".
- Could not verify exact Akahu pricing for personal apps.

## 2. What do users complain about with bank sync?

### Takeaway
The most persistent complaints are regional gaps (UK, Canada, Australia, India and other Asian markets have no dependable first-party route), recurring re-authorization, silent or opaque failures, pending-transaction and duplicate/matching problems, and (until 26.11.0) the lack of automatic sync. Automatic sync now exists but only runs while the app is open.

### Cited Findings

Missing regions, banks and providers
- Plaid: #898 "[Feature] Plaid Integration" has 50 thumbs-up and is closed/"needs votes" (not implemented); Plaid exists only as a community project (actualplaid). — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+bank+sync+sort%3Areactions-%2B1-desc); [Actual docs: Community Repos](https://actualbudget.org/docs/community-repos)
- UK: #6617 requested TrueLayer "or equal alternative" for UK/EU banks (11 thumbs-up, closed by bot, no written maintainer reply); the only working route reported in-thread (Oct 2026) was a third-party tool, truelayer2actual. — [GitHub #6617](https://github.com/actualbudget/actual/issues/6617)
- India: requests #5571 "Connecting Indian Banks" (closed Aug 2025) and #6352 "Access financial information for accounts based in India" (closed Dec 2025), both unimplemented feature requests; the community answer is a statement converter (india2actual). — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+csv+import+%28mapping+OR+duplicate+OR+date+OR+profile%29+sort%3Aupdated-desc); [Actual docs: Community Repos](https://actualbudget.org/docs/community-repos)
- Australia, Israel: no official provider in the supported list; coverage exists only through community projects (Up bank via actualbudget-sync, ANZ Plus PDF-to-OFX converter, MoneyMan for Israeli banks). — [Actual docs: Connecting Your Bank](https://actualbudget.org/docs/advanced/bank-sync/); [Actual docs: Community Repos](https://actualbudget.org/docs/community-repos)
- Other providers floated by users and not adopted: Tink, Mastercard Aiia, Finicity, MX, woob, Lunch Flow. — [GitHub #5445](https://github.com/actualbudget/actual/issues/5445)

Re-authentication and connection expiry
- Enable Banking: consent capped at 90 days; a user (13 Nov 2026) noted Actual caps `valid_until` at 90 days even though banks such as N26, Revolut and DKB allow 180, so users re-link twice as often as necessary. — [GitHub #7799](https://github.com/actualbudget/actual/issues/7799)
- Enable Banking reauthorization requires re-selecting country and bank and re-mapping each bank account to its Actual account. — [Actual docs: Enable Banking Setup](https://actualbudget.org/docs/advanced/bank-sync/enable-banking/)
- Enable Banking + Openbank (Spain): after the first sync, later syncs failed with `TOKEN_EXPIRED` although the session stayed authorized; workarounds were re-linking or CSV import (14 Nov 2026). — [GitHub #7799](https://github.com/actualbudget/actual/issues/7799)
- SimpleFIN: one user reports an account that needs re-authentication on every update, forcing them to check the SimpleFIN site often. — [GitHub #7333](https://github.com/actualbudget/actual/issues/7333)
- GoCardless: handling of expired end-user agreements as relink requests was only added in 26.8.0 (#8383); banks with "special continuous access requirements" needed specific handling (25.11.0 #5967, 26.6.0 #7890). — [release 26.8.0](https://actualbudget.org/blog/release-26.8.0); [release 26.6.0](https://actualbudget.org/blog/release-26.6.0)

Silent failures and opaque errors
- #7333 (opened 30 Mar 2026, 14 thumbs-up, about 10 reporters): SimpleFIN connections stuck on "We are upgrading this connection" while Actual kept showing a green sync dot. The original reporter's account had been stuck six weeks unnoticed; another user lost ten days of transactions and had to upload a file manually. Root cause was upstream; SimpleFIN changed its API on 28 Oct 2026 and Actual now shows the error. Resolved. — [GitHub #7333](https://github.com/actualbudget/actual/issues/7333)
- Enable Banking: users saw only "Failed syncing account"/`InternalError` with empty server logs until `DEBUG=*` (13 Nov 2026); an inactive application or a leading space in the Application ID produced an empty bank list with no error. — [GitHub #7799](https://github.com/actualbudget/actual/issues/7799)
- Failed-sync status used to disappear on reload and did not propagate across devices; fixed in 26.7.0 (#8017, #8170). Bank sync could hang indefinitely on mobile; fixed in 26.7.0 (#8113). — [release 26.7.0](https://actualbudget.org/blog/release-26.7.0)
- SimpleFIN rate limits: staying under 24 requests per day is the stated workaround, and hitting the limit surfaces as an "account missing" error (#3228, older); repeated linking attempts triggered a Cloudflare block requiring a credential reset (#7785, 2026). — [GitHub #3228 mirror](https://github.xay.workers.dev/actualbudget/actual/issues/3228); [GitHub #7785 mirror](https://www.goodfirstissue.org/actualbudget/actual/issues/7785)
- SimpleFIN: a replacement credit card stopped syncing and the user went a week without transactions (#6649). — [GitHub #6649](https://github.com/actualbudget/actual/issues/6649)

Open bank-sync bugs (9 open with the "bank sync" label, checked Nov 2026)
- #9325 duplicating a transaction copies `imported_id` from the original (Oct 2026); #9063 Enable Banking silently skips a booked transaction on import (Oct 2026, 9 comments); #8902 ING Direct Italy fails to link via GoCardless (Sep 2026); #8326 Enable Banking imagin/CaixaBank linking fails on desktop but works in mobile browser (Jun 2026); #5502 Revolut via GoCardless adds a transaction the day before the earliest one (Aug 2025); #4779 linking one SimpleFIN account causes all accounts to sync (Apr 2025); #4460 GoCardless linking times out before completion (Feb 2025, 21 comments); #3218 starting balance not created if other accounts create transfers (Aug 2024); #2952 can't link to bank on iOS (Jul 2024). — [GitHub open "bank sync" issues](https://github.com/actualbudget/actual/issues?q=is%3Aissue+state%3Aopen+label%3A%22bank+sync%22)

Duplicate or missing transactions, bad payees
- Enable Banking produced duplicates when a continuation key repeated during pagination (fixed 26.11.0, #9046); picked the account holder as payee when the counterparty was missing (fixed 26.11.0, #9204). — [release 26.11.0](https://actualbudget.org/blog/release-26.11.0)
- Enable Banking user reports: Deutsche Bank Spain returned transfers and direct debits but not debit card payments (8 Nov 2026); payees copied from notes or empty (Trade Republic, Oct 2026); a chosen start date was ignored and full history imported, giving 371 uncategorized transactions (May 2026). — [GitHub #7799](https://github.com/actualbudget/actual/issues/7799)
- New bank transactions could match parts of an already-matched split transaction (fixed 26.11.0, #8909); fuzzy matching now prefers a candidate not already linked in a previous sync (26.11.0, #9001). — [release 26.11.0](https://actualbudget.org/blog/release-26.11.0)
- Pluggy sync repeatedly rewrote uncategorized and transfer transactions (fixed 26.8.0, #8392). — [release 26.8.0](https://actualbudget.org/blog/release-26.8.0)
- Deleted synced transactions "respawning" was a long-running request (#2289, Jan 2024); a per-account option controlling reimport of deleted transactions arrived in 25.4.0 (#4644). — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+bank+sync+sort%3Areactions-%2B1-desc); [release 25.4.0](https://actualbudget.org/blog/release-25.4.0)
- Bank-specific payee/date quirks need per-bank handlers contributed by users (e.g. Alior Bank payee fix 26.9.0 #8738; Commerzbank payee names stalling imports fixed 26.11.0). — [release 26.9.0](https://actualbudget.org/blog/release-26.9.0); [release 26.11.0](https://actualbudget.org/blog/release-26.11.0)

Pending transactions
- Requests and bugs, all closed without a dedicated feature: #3138 "Imported pending transactions don't follow bank behavior (SimpleFIN)" (Aug 2024); #3502 "Improve handling of pending transactions for SimpleFIN sync" (Sep 2024); #4292 "Better visibility for newly imported, pending and matched transactions" (Feb 2025); #5651 automatically merge pre-tip (uncleared) and post-tip cleared transactions (Aug 2025); #8757 "automatically merge modified-at-post-date bank sync transactions" (Aug 2026); #8895 API option to disable fuzzy matching for pending transactions (Sep 2026). — [GitHub issue search: pending transactions](https://github.com/actualbudget/actual/issues?q=is%3Aissue+pending+transactions+sort%3Areactions-%2B1-desc)
- Enable Banking: future payments and card holds appeared as deposits and skewed the running balance (May 2026). — [GitHub #7799](https://github.com/actualbudget/actual/issues/7799)
- Actual's design intent is that reconciliation on import matches previously pending transactions once they post. (2019-era article by the original author; old.) — [How Transaction Reconciliation Works](https://medium.com/actualbudget/how-transaction-reconciliation-works-8dc5749bbd21)

Balance mismatches
- #2354 "Future transactions should not be included in the account balance summary": 70 thumbs-up, closed 8 Apr 2026. — [GitHub issue search: pending transactions](https://github.com/actualbudget/actual/issues?q=is%3Aissue+pending+transactions+sort%3Areactions-%2B1-desc)
- #6070 "Add option in Bank Sync to choose which balance to sync" (closed Nov 2025, needs votes); #2911 track statement balance separately for credit cards (closed Jun 2024, needs votes). — [GitHub issue search: pending transactions](https://github.com/actualbudget/actual/issues?q=is%3Aissue+pending+transactions+sort%3Areactions-%2B1-desc)
- Enable Banking: for Morrow Bank (Sweden) cards Actual used available credit instead of booked debt (Oct 2026). — [GitHub #7799](https://github.com/actualbudget/actual/issues/7799)
- Docs warn that pulling in historic data "has caused some users a lot of headaches with subsequent reconciliation" and recommend starting from a recent opening balance. — [Actual docs: GoCardless Setup](https://actualbudget.org/docs/advanced/bank-sync/gocardless/)
- Mitigations shipped: custom starting date and balance when linking (26.3.0, #6629); option to overwrite dates with the bank's value (26.3.0, #6850); a fix for a custom start date producing an opening balance of 0 (26.9.0, #8750). — [release 26.3.0](https://actualbudget.org/blog/release-26.3.0); [release 26.9.0](https://actualbudget.org/blog/release-26.9.0)

Manual trigger / automatic sync
- #3831 "Periodic automatic bank sync" (23 thumbs-up) was closed Nov 2024 as an unimplemented request. — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+bank+sync+sort%3Areactions-%2B1-desc)
- Automatic syncing shipped in 26.11.0 (1 Nov 2026, #8744): off by default; intervals of 12 hours, a day, a week or custom (minimum 15 minutes). — [release 26.11.0](https://actualbudget.org/blog/release-26.11.0); [Actual docs: Connecting Your Bank](https://actualbudget.org/docs/advanced/bank-sync/)
- Remaining limitation: "Syncing only happens while Actual is open. If you close Actual, it catches up the next time you open it." Each automatic sync covers all linked accounts. — [Actual docs: Connecting Your Bank](https://actualbudget.org/docs/advanced/bank-sync/)
- On mobile, pull-to-refresh on the Budget screen syncs with the server but "does not fetch new bank transactions"; the title-bar "Sync" label was changed to an icon in 26.4.0 "to alleviate confusion with Bank Sync" (#7005). — [Actual docs: Connecting Your Bank](https://actualbudget.org/docs/advanced/bank-sync/); [release 26.4.0](https://actualbudget.org/blog/release-26.4.0)
- Stale documentation: the GoCardless page FAQ still says "it is not yet possible for Actual to automatically sync with your bank", and the Importing page still lists only SimpleFIN, GoCardless and Pluggy.ai. — [Actual docs: GoCardless Setup](https://actualbudget.org/docs/advanced/bank-sync/gocardless/); [Actual docs: Importing Transactions](https://actualbudget.org/docs/transactions/importing)

Transfers, investment and other account types
- #1628 "Bank Sync - Recognise transfers between accounts" (11 thumbs-up, Sep 2023) and #6529 "automatic transfers on bank-sync based on matching amount/date" (Jan 2026) are both closed as unimplemented requests. — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+bank+sync+sort%3Areactions-%2B1-desc); [GitHub issue search: pending transactions](https://github.com/actualbudget/actual/issues?q=is%3Aissue+pending+transactions+sort%3Areactions-%2B1-desc)
- #2718 "Update balance of SimpleFin linked investment accounts when syncing" (10 thumbs-up, May 2024); a bank sync option to import only the account balance shipped in 25.10.0 (#5711). — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+bank+sync+sort%3Areactions-%2B1-desc); [release 25.10.0](https://actualbudget.org/blog/release-25.10.0)

Scale of feedback and security history
- The SimpleFIN feedback issue (#2272) drew 203 thumbs-up and the Nordigen feedback issue (#724) 82, among the most-reacted issues in the repository. — [GitHub issue search: pending transactions](https://github.com/actualbudget/actual/issues?q=is%3Aissue+pending+transactions+sort%3Areactions-%2B1-desc)
- 26.2.1 (22 Feb 2026) was a security release: "Fix: simplefin and pluggy not requiring auth" (#7034). 26.7.0 added SSRF protection to SimpleFIN (#8012); 26.11.0 kept bank connection credentials out of server request logs. — [release 26.2.1](https://actualbudget.org/blog/release-26.2.1); [release 26.7.0](https://actualbudget.org/blog/release-26.7.0); [release 26.11.0](https://actualbudget.org/blog/release-26.11.0)

### Inferences
- Much of Actual's bank-sync reliability depends on upstream aggregators (SimpleFIN/MX, Enable Banking connectors, bank ASPSPs). Actual historically passed their failures through poorly (green dot while data was stale, generic errors); 2026 releases improved error surfacing but several threads show users still discovering gaps only when balances drift.
- The per-bank handler model for GoCardless (dozens of bank-specific formatters contributed over time) has to be rebuilt for Enable Banking, so payee/notes quality for European users regressed for those who had to switch.
- Pending-transaction handling is the clearest unaddressed functional theme: at least six separate requests between 2024 and 2026, none implemented as a first-class feature.
- "No automatic sync" is now only partly valid: resolved for users who keep the app open, unresolved for true background/server-side sync (which is why community cron tools persist, see section 5).

### Gaps
- No Reddit, Hacker News or blog-post quotes could be retrieved; sentiment evidence is GitHub-only and so skews to technical users.
- I found no direct evidence of Canada-specific complaints in the sources fetched; whether SimpleFIN covers major Canadian banks adequately is unverified.
- I found no specific issues about loan/mortgage account sync.
- The "resolved" state of #2354 (future transactions in balance) is inferred from its closure date; I did not read the thread.
- Thumbs-up counts were read off GitHub listing pages by an automated summarizer and should be treated as approximate.

## 3. What are the complaints about CSV/OFX/QFX/QIF/CAMT import?

### Takeaway
File import works but is one file, one account at a time, with heuristic duplicate matching that can silently merge distinct transactions, and a long tail of parsing bugs (encodings, dates, amount formats) that were still being fixed in autumn 2026. Category import, multi-account files and named import profiles remain unimplemented requests.

### Cited Findings
- Supported formats: CSV, QIF, OFX, QFX and CAMT; OFX/QFX is recommended. Import is started from within a single account. — [Actual docs: Importing Transactions](https://actualbudget.org/docs/transactions/importing)
- Duplicate handling: Actual first checks the file's transaction id (OFX/QFX), then looks for "transactions around the same date, with the same amount, and with a similar payee"; it "will always favor the imported transaction" and overwrite the date of a matched manual entry. CSV files carry no id, so matching is purely heuristic. — [Actual docs: Importing Transactions](https://actualbudget.org/docs/transactions/importing)
- #8464 (closed Oct 2026): CSV import silently merges new transactions that share an amount with an existing one. Related fix in 26.11.0 (#9135): CSV import "merged a new transaction into an existing one with the same amount after you unchecked a matched row". — [GitHub issue search: CSV import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+csv+import+%28mapping+OR+duplicate+OR+date+OR+profile%29+sort%3Aupdated-desc); [release 26.11.0](https://actualbudget.org/blog/release-26.11.0)
- #6737 "Incorrect transaction matching on import" (closed as duplicate Oct 2026); #5354 weekly debits incorrectly matched to the previous week's debit (closed Jul 2025, needs votes). — [GitHub issue search: ynab import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+ynab+import+sort%3Aupdated-desc)
- #4280 (open since Feb 2025): the `importTransactions` API doesn't check for duplicates within the same import. — [GitHub issue search: CSV import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+csv+import+%28mapping+OR+duplicate+OR+date+OR+profile%29+sort%3Aupdated-desc)
- #669 "Merge unmatched transactions" (20 thumbs-up) and #2953 "Reject Imported Transactions"/#4230 "ability to approve new transactions" (8 thumbs-up) are closed feature requests about reviewing or fixing matches after import. — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+bank+sync+sort%3Areactions-%2B1-desc); [GitHub issue search: ynab import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+ynab+import+sort%3Aupdated-desc)
- Reimport of deleted transactions: an override was added in 26.4.0 (#6926) and then made on-by-default and persisted in 26.5.0 (#7610); the API defaults `reimportDeleted` to true. — [release 26.4.0](https://actualbudget.org/blog/release-26.4.0); [release 26.5.0](https://actualbudget.org/blog/release-26.5.0); [Actual docs: Importing Transactions](https://actualbudget.org/docs/transactions/importing)
- Parsing bugs fixed during 2026 (evidence of fragility): trailing whitespace in amounts from Excel-saved CSVs (26.4.0, #7149); CSV settings reset when changing "Skip end lines" (26.7.0, #7827); UTF-16 CSV exports failing, with a per-account encoding selector added (26.10.0, #8924); garbled accented characters in OFX/QFX (#8874) and CAMT (#8913) (26.10.0); "Sept" month abbreviation not parsed (26.10.0, #8957); amounts read without their decimal point when a currency symbol follows (26.11.0, #9100); QIF categories dropped (26.6.0 #7869, again 26.11.0 #9041). — [release 26.4.0](https://actualbudget.org/blog/release-26.4.0); [release 26.7.0](https://actualbudget.org/blog/release-26.7.0); [release 26.10.0](https://actualbudget.org/blog/release-26.10.0); [release 26.11.0](https://actualbudget.org/blog/release-26.11.0); [release 26.6.0](https://actualbudget.org/blog/release-26.6.0)
- Bug reports closed in Sep-Oct 2026: #8888 invalid date on CSV import; #8986 can't import Czech characters in CSV; #6327 no transactions detected in bank CSV export; #5020 error when an amount has only one decimal digit. — [GitHub issue search: CSV import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+csv+import+%28mapping+OR+duplicate+OR+date+OR+profile%29+sort%3Aupdated-desc)
- File encoding options had been requested since Nov 2024 (#3848) and arrived in Oct 2026. — [GitHub issue search: import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+import+csv+OR+ofx+OR+qfx+OR+qif+sort%3Areactions-%2B1-desc); [release 26.10.0](https://actualbudget.org/blog/release-26.10.0)
- Unimplemented requests (closed, "needs votes"): import "Category" from file (#557, 16 thumbs-up, 2023; #6511 Dec 2025; #9285 show/create unmatched categories, Oct 2026; #2226); importing across multiple accounts at once (#525, 7 thumbs-up; #810; #9065 "Match imported files to configured accounts", Oct 2026); check number column (#1852); drag-and-drop import (#4192); clipboard import (#8561, Jul 2026); progress indicator for bank file imports (#7652, Apr 2026); "Remember merged payees on future imports" (#9489, closed 9 Nov 2026). — [GitHub issue search: import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+import+csv+OR+ofx+OR+qfx+OR+qif+sort%3Areactions-%2B1-desc); [GitHub issue search: CSV import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+csv+import+%28mapping+OR+duplicate+OR+date+OR+profile%29+sort%3Aupdated-desc); [GitHub issue search: ynab import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+ynab+import+sort%3Aupdated-desc)
- CSV mapping is stored as synced per-account preferences ("csv column mappings for specific accounts"), settable through the API since 26.10.0 (#8893). — [release 26.10.0](https://actualbudget.org/blog/release-26.10.0)
- Small improvements in 2026: swap payee/memo on import (#7101) and "only import transactions since" (#7139) in 26.4.0; import preview sorted by parsed date (26.2.0, #6543); CSV import modal performance fix (25.11.0, #5980). — [release 26.4.0](https://actualbudget.org/blog/release-26.4.0); [release 26.2.0](https://actualbudget.org/blog/release-26.2.0); [release 25.11.0](https://actualbudget.org/blog/release-25.11.0)
- The docs give no column-level help beyond a short list of toggles (flip amount, split inflow/outflow, multiply amount, delimiter, date format) and ask users to "let us know" if their delimiter is not listed. — [Actual docs: Importing Transactions](https://actualbudget.org/docs/transactions/importing)

### Inferences
- "Lack of saved import profiles" is only partly accurate: mappings are remembered per account, but there are no named or shareable profiles, no per-bank presets, and no way to route one file to several accounts. The steady supply of community bank-statement converters (section 5) reflects that.
- Payee matching on import depends on rules plus fuzzy matching; the rejection of "Remember merged payees on future imports" (Nov 2026) indicates payee clean-up still has to be redone via manually authored rules.
- The volume of encoding/number-format fixes in 26.10-26.11 suggests non-US/non-English bank exports were a weak spot until very recently.

### Gaps
- No direct user quotes about reconciliation friction after file import were retrieved.
- No OFX/QFX/QIF-specific open issues surfaced in searches; I cannot say whether that reflects few problems or search limits.
- Did not verify how CAMT (camt.053) coverage compares with what European banks actually export.

## 4. What are the complaints about migrating from YNAB or other apps?

### Takeaway
Only YNAB4 and nYNAB have official importers; nYNAB migration depends on a third-party export tool or manual API calls, and imported budgets need manual clean-up because Actual models credit cards and "Ready to Assign" differently. Importers for Mint and other apps were declined or left as unvoted requests.

### Cited Findings
- Official migration paths are YNAB4 and nYNAB (plus the old Actual desktop app). The migration index page still says "Right now, only YNAB4 is officially supported" and that the API "allows anyone to write a custom importer". — [Actual docs: Switching from Another App](https://actualbudget.org/docs/migration/); [Actual docs: Community Repos](https://actualbudget.org/docs/community-repos)
- nYNAB export relies on a community-run web tool (json-exporter-for-ynab.netlify.app) that "may occasionally be unavailable or show an authorization restriction from YNAB"; fallbacks are YNAB's API documentation UI, a CLI tool (ynab-export), or cURL with a personal access token. — [Actual docs: Migrating from nYNAB](https://actualbudget.org/docs/migration/nynab)
- YNAB API change broke imports: exports from YNAB's current API failed with a "not-ynab5" error until fixed in 26.7.0 (#8184); the docs still describe a manual workaround of editing `"plan"` to `"budget"` in the JSON on older versions. — [release 26.7.0](https://actualbudget.org/blog/release-26.7.0); [Actual docs: Migrating from nYNAB](https://actualbudget.org/docs/migration/nynab)
- Credit cards: "If you import credit cards with previous debt, you must handle these differently. Otherwise, your budget months will show overspending." The fix is manual: create a Credit Card category, recategorize overspent transactions, enable rollover overspending, then "look through each month" in YNAB to find and re-enter the extra amount assigned. — [Actual docs: Migrating from nYNAB](https://actualbudget.org/docs/migration/nynab)
- Leftover money in To Budget after import: nYNAB's per-card Credit Card Payment categories have no equivalent in Actual, and nYNAB's Ready to Assign includes funds budgeted in future months; users must apply "Hold for next month" and "Repeat for all desired months". — [Actual docs: Migrating from nYNAB](https://actualbudget.org/docs/migration/nynab)
- Duplicate categories/groups from YNAB are renamed with a "-1" suffix and must be cleaned up by hand. — [Actual docs: Migrating from nYNAB](https://actualbudget.org/docs/migration/nynab)
- A Reddit user (r/ynab, July 2024, old) said the import "seems to have wiped out all the credit card categories", including minimum payment information stored in targets, and found Actual's credit card handling unsuitable for a debt paydown plan. — [r/ynab thread mirror](https://lr.eu.psf.lt/r/ynab/comments/1e4ewh5/a_long_term_users_perspective_migrating_from_ynab/ldjahlv/?context=3)
- #1995 "Handle credit cards like nYNAB" (18 thumbs-up) is a closed, unimplemented request. — [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+bank+sync+sort%3Areactions-%2B1-desc)
- YNAB4: split transactions "may import incorrectly" and require Settings > Repair split transactions. Bug #3561 "YNAB4 import leads to malformed split transactions" stayed open from 2024 until Sep 2026; fixes landed in 25.7.0 (#5226) and 26.10.0 (#8973). — [Actual docs: Migrating from YNAB4](https://actualbudget.org/docs/migration/ynab4); [GitHub issue search: ynab import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+ynab+import+sort%3Aupdated-desc); [release 26.10.0](https://actualbudget.org/blog/release-26.10.0)
- YNAB4 notes were dropped on import (#9188, Oct 2026); month notes and category budget notes are imported from 26.11.0 (#9198). — [GitHub issue search: ynab import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+ynab+import+sort%3Aupdated-desc); [release 26.11.0](https://actualbudget.org/blog/release-26.11.0)
- Fidelity gaps closed only recently in the nYNAB importer: category notes (25.9.0, #5461); scheduled transactions into schedules (26.3.0, #6844); flags mapped to tag colours (26.3.0, #6866); duplicate-category import errors (26.3.0, #6878); payee locations (26.4.0, #6157); an unused duplicate payee per linked transfer account (26.8.0, #8424); progress bar during import (26.10.0, #8956). — [release 25.9.0](https://actualbudget.org/blog/release-25.9.0); [release 26.3.0](https://actualbudget.org/blog/release-26.3.0); [release 26.4.0](https://actualbudget.org/blog/release-26.4.0); [release 26.8.0](https://actualbudget.org/blog/release-26.8.0); [release 26.10.0](https://actualbudget.org/blog/release-26.10.0)
- Other apps: "Import transactions from mint export" (#1873, 13 thumbs-up) was closed as wontfix; "Generic Migration Importer" (#2045), Budgetbakers Wallet (#1198), Splitwise (#3187), "Merge budget files" (#3260) and snowmint Budget (#7964, May 2026) are closed unimplemented requests. — [GitHub issue search: import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+import+csv+OR+ofx+OR+qfx+OR+qif+sort%3Areactions-%2B1-desc); [GitHub issue search: ynab import](https://github.com/actualbudget/actual/issues?q=is%3Aissue+ynab+import+sort%3Aupdated-desc)

### Inferences
- Migration from anything other than YNAB means importing transactions per account via CSV/OFX and rebuilding categories, budget history, rules and schedules by hand, or writing an API script.
- YNAB migration fidelity improved a lot during 2026 (schedules, flags, notes, locations), so older complaints about lost flags/notes/schedules are largely resolved; the credit-card and Ready-to-Assign differences are structural and remain.
- The nYNAB path is fragile because it depends on YNAB's API and a volunteer-hosted OAuth app; a non-technical user who hits an "authorization restriction" is pushed to a terminal or to YNAB's API docs.

### Gaps
- No recent (2026) first-hand user accounts of YNAB migration were retrieved; the Reddit quote is from 2024.
- No data on whether YNAB goals/targets are imported; the 2024 anecdote suggests not, but I could not confirm the current state.
- Did not find evidence about migration from Monarch, Quicken, GnuCash, Firefly III or MoneyMoney in the issue searches.

## 5. What third-party workarounds have users built?

### Takeaway
Actual's own docs list a sizeable ecosystem of community sync bridges, statement converters and scheduling tools covering exactly the regions and capabilities missing from the core product (Plaid, UK, Australia, Israel, India, Germany, background sync), which is direct evidence of unmet need.

### Cited Findings
- The docs state: "There are also community projects that implement bank syncing." — [Actual docs: Importing Transactions](https://actualbudget.org/docs/transactions/importing)
- Community bank sync and importer projects listed in the docs: actualbudget-sync (Akahu and Up bank, NZ/Australia); enable-actual (Enable Banking for European banks); Lunch Flow's actual-flow ("GoCardless, MX, Finicity, Finverse, and more"); MoneyMan (Israeli banks); actualplaid (Plaid); bank2actual (BofA, Chase, Citi, Amex CSV and Chase PDF to Actual-ready CSV); PDFtoOFX (ANZ Plus PDF to OFX); actual-bank-importer (German DKB and Comdirect); india2actual (Indian bank statements in CSV, Excel, HTML and PDF to CSV). — [Actual docs: Community Repos](https://actualbudget.org/docs/community-repos)
- actual-auto-sync: "A background service that automatically syncs your Actual Budget accounts on a scheduled basis." — [Actual docs: Community Repos](https://actualbudget.org/docs/community-repos)
- Migration helper: ynab-export, a terminal tool that exports nYNAB data as JSON, now referenced in the official migration guide. — [Actual docs: Community Repos](https://actualbudget.org/docs/community-repos); [Actual docs: Migrating from nYNAB](https://actualbudget.org/docs/migration/nynab)
- Lunch Flow (paid, a few pounds a month per users in #5445) added Actual Budget support via an import script in September 2025; its own feedback board has a request to update pending status of duplicates in Actual, which "the duplicates logic in the import script currently prevents". A UK tester found connections stuck "pending" for about nine hours and called it "not a reliable solution" (Jan 2026). — [Lunch Flow changelog](https://lunchflow.featurebase.app/changelog/actual-budget-support-and-new-website-pages-dart); [Lunch Flow feature request](https://lunchflow.featurebase.app/p/option-to-update-pending-status-of-duplicates-in-actualbudget); [GitHub #5445](https://github.com/actualbudget/actual/issues/5445); [GitHub #6617](https://github.com/actualbudget/actual/issues/6617)
- truelayer2actual was reported in Oct 2026 as a working third-party bridge for UK banks. — [GitHub #6617](https://github.com/actualbudget/actual/issues/6617)
- Synci announced (25 July 2026) connecting banks to Actual Budget and "SimpleFIN-powered apps", i.e. a commercial service emulating the SimpleFIN protocol. — [Synci changelog](https://synci.featurebase.app/changelog/connect-your-bank-to-actual-budget-and-simplefin-powered-apps)
- SyncBank, a paid proprietary tool, markets EU bank transaction sync to Actual Budget among other targets. — [AlternativeTo: SyncBank](https://alternativeto.net/software/syncbank/about/)
- Other community tooling: actual-simplefin-sync (pre-dates built-in SimpleFIN), csv2actual, actual-moneymoney (MoneyMoney on macOS), and the actualpy Python library with a documented custom-CSV import example. — [actual-simplefin-sync](https://github.com/duplaja/actual-simplefin-sync); [csv2actual](https://awesome.ecosyste.ms/projects/github.com%2Fjorisnoo%2Fcsv2actual); [actual-moneymoney](https://app.unpkg.com/actual-moneymoney@3.2.0/files/README.md); [actualpy docs](https://actualpy.readthedocs.io/en/latest/examples/importing-a-custom-csv-file/)
- Core changes made specifically to support custom importers: `balance_current` settable via the Account API "making balances visible for reconciliation when using custom importers" (26.3.0, #6915); `payeeNameNormalization` option on `importTransactions` (26.9.0, #8710); `runBankSync` now reports what a sync did (26.11.0, #8998); the CLI was released as stable in 26.7.0. — [release 26.3.0](https://actualbudget.org/blog/release-26.3.0); [release 26.9.0](https://actualbudget.org/blog/release-26.9.0); [release 26.11.0](https://actualbudget.org/blog/release-26.11.0); [release 26.7.0](https://actualbudget.org/blog/release-26.7.0)
- Maintainers have said additional providers are expected via a future plugin system as "use-at-own-risk" options rather than endorsed integrations; #737 "Common way to enable future bank syncing tools" (26 thumbs-up) was closed Jan 2025. — [GitHub #5445](https://github.com/actualbudget/actual/issues/5445); [GitHub issue search](https://github.com/actualbudget/actual/issues?q=is%3Aissue+bank+sync+sort%3Areactions-%2B1-desc)

### Inferences
- Two workaround patterns dominate: (a) API-driven sync bridges for regions without a first-party provider, and (b) "statement converter" tools that normalise bank CSV/PDF exports into something Actual's importer accepts. Pattern (b) signals that Actual's importer lacks per-bank presets and PDF/Excel input.
- Commercial middlemen (Lunch Flow, Synci, SyncBank) have emerged to sell connectivity to Actual users, which suggests willingness to pay for dependable sync that the project itself does not broker.
- A server-side/background sync tool (actual-auto-sync) remains relevant after 26.11.0 because built-in automatic sync runs only while a client is open.

### Gaps
- No usage or star counts were gathered for the community projects, so relative popularity is unknown.
- I did not find evidence that actual-ai (LLM categorisation) relates to import; it is a categorisation tool and likely belongs to another researcher's scope.
- The plugin system's status as of Nov 2026 was not verified.
