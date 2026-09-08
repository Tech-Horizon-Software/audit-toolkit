# Audit checklists — phases 3 to 10, frontend, Terraform pointer

Roughly two hundred items; any one audit uses a handful. **Read the phase you are briefing
for, at the moment you write the brief** — the brief must name which items the scope can reach
and which it cannot. Read later, this is a list you check your own work against after the fact,
which is how it ends up never read.

Repository conventions outrank anything here. Where the repository states none, the *Code
style* items are `Recommendation` at most.

---

## Phase 3: General correctness

Specialists: `pr-review-toolkit:code-reviewer`, `silent-failure-hunter`, `type-design-analyzer`;
`comment-analyzer` only when documentation or load-bearing comments are in scope. Never
`code-simplifier`.

- incorrect branching and conditions; inverted or off-by-one comparisons;
- null / undefined handling; optional chaining that hides a required value;
- wrong defaults and fallbacks (`?? 0`, `|| []` masking absence);
- swallowed exceptions; broad or empty catch; errors downgraded to logs;
- partially completed operations without rollback or compensation;
- missing `await`; unhandled promise; `Promise.all` where one failure should not cancel others
  (or should);
- incorrect async iteration (`forEach` with async callback);
- resource, timer, listener, subscription leaks;
- invalid state transitions; state machines with unreachable or duplicate transitions;
- API contract changes; backward compatibility of DTOs, events, queue payloads;
- incorrect pagination (offset drift, missing stable ordering, total mismatch);
- timezone and date errors; `Date` vs UTC; DST; month arithmetic;
- type assertions (`as`, `!`) hiding invalid states; `any` at boundaries;
- DTO / domain / database type mismatch (string ids vs numbers, Decimal vs number);
- missing input validation at a boundary; validation after a side effect;
- missing regression test for a fixed defect.

A finding identifies a concrete failure scenario reachable from the scope.

## Phase 4: Security

Specialist: `claude-security:claude-security` in repo or diff scan mode. If unavailable or
failing, `audit-researcher` with this list; the audit continues either way.

- authentication bypass; auth guard missing on a route, gateway, subscription, cron endpoint;
- IDOR / BOLA; missing object-level authorization; horizontal and vertical privilege escalation;
- tenant, organisation, account, owner, resource isolation;
- incorrect permission / role / scope / ability conditions; authorization after side effects;
- mass assignment (`...body` into an update); over-permissive DTO whitelists;
- SQL / NoSQL / command / template / log injection; unsafe raw queries; string-built SQL;
- SSRF; path traversal; unsafe file upload/download; zip-slip;
- XSS (server-rendered and DOM); unsafe `innerHTML`, `dangerouslySetInnerHTML`, `v-html`;
- prototype pollution; unsafe deserialization; unsafe `eval`/`Function`;
- hardcoded or logged secrets; secrets in git history; secrets in client bundles;
- JWT / session / token / cookie / CORS / CSRF problems; token in URL; missing `HttpOnly`,
  `Secure`, `SameSite`; overly long lifetimes; weak default secrets in config;
- missing rate limits on login, recovery, OTP, webhooks, expensive endpoints;
- unsafe webhooks (no signature check, replay); replay attacks;
- CSV / formula injection in exports; open redirects;
- dependency vulnerabilities (audit output) and infrastructure exposure.

Security findings require: an attacker-controlled source, a complete source-to-sink path, a
missing or ineffective protection, realistic attacker permissions and preconditions, a concrete
exploit scenario, a concrete impact. Never output a full secret; mask it.

## Phase 5: Money and financial correctness (only when the `money` stack is detected)

For every operation that can affect money, balances, accounts, orders, positions, invoices,
payouts, commissions, conversion, margin or PnL, trace the complete state transition.

- `number` / float / `REAL` / `DOUBLE PRECISION` used for money or exact quantities;
- incorrect Decimal conversion; precision loss during JSON serialization; inconsistent scale
  and rounding modes; rounding at the wrong stage;
- trusting client-provided price, fee, amount, balance, rate, discount;
- check-then-update balance logic; missing atomic reservation; negative balance possible;
- double spend; duplicate deposit / withdrawal / payout; missing, reusable or mis-scoped
  idempotency keys;
- duplicate, partial or out-of-order events (fills, webhooks, callbacks);
- repeated fee / interest / commission calculation; wrong sign conventions;
- stale prices or rates; missing rate snapshot at transaction time;
- mutable financial history; deletion instead of reversal or compensating entry; missing audit
  trail; ledger and balance inconsistency; snapshot chains computed outside the lock;
- incorrect transaction isolation; missing unique / check / foreign-key constraints;
- inability to reconcile or replay history.

Each money finding: the violated invariant, a numeric example, a concurrent or repeated-event
scenario when applicable, the exact impact, the regression test that fails before the fix. Do
not invent business rules — unclear ones go under *Business decisions required*.

## Phase 6: Concurrency and multi-instance (backend)

Assume production runs several API instances, several workers, several realtime instances,
rolling deployments, shared database and cache, and processes that can die at any point.

- mutable in-memory state; in-memory sessions, rate limits, caches that diverge per instance;
- cron on every instance; duplicated scheduled jobs; non-idempotent consumers;
- retries after completed side effects; stalled job recovery; poison messages;
- duplicate, out-of-order, stale events;
- check-then-act races; lost updates; missing row locks; wrong optimistic locking;
- distributed locks without ownership tokens; unsafe TTL; expired holder continuing; no fencing;
- non-atomic database + cache operations; commit then failed publish; missing outbox / inbox;
- cache invalidation races; realtime fan-out without a shared adapter or pub/sub;
- graceful shutdown: workers accepting jobs while stopping; readiness stays healthy during
  shutdown; in-flight requests dropped;
- connection-pool exhaustion after scaling; shared-filesystem and temp-file assumptions.

Every concurrency finding has a timeline with at least two actors and the exact interleaving.

## Phase 7: Performance and scalability

- N+1 queries; queries in loops; unbounded `findMany`/`SELECT *`; missing pagination;
  OFFSET pagination on large tables; fetching unneeded columns or relations; large include trees;
- missing indexes for new access patterns; wrong composite-index order; missing FK indexes;
  likely full scans; long transactions; locks held across network calls; hot rows;
- repeated round trips; missing batching / pipelining; cache hot keys; large cached values;
- synchronous CPU work on the event loop; unbounded concurrency; missing backpressure; queue
  buildup; wrong worker concurrency;
- large JSON serialization; whole files / datasets in memory; memory leaks; unclosed connections;
- recomputation of unchanged values; broadcast amplification;
- missing timeouts; retry storms.

Frontend: see the FE section. Never claim a performance defect from style alone. Classify
evidence — `Confirmed` (complexity, query count, plan, benchmark), `Probable` (code path
strongly indicates; needs measurement), `Needs benchmark` (depends on data, config, traffic).
Database findings carry the access pattern, expected cardinality, schema and indexes, and a
suggested `EXPLAIN (ANALYZE, BUFFERS)`. Never run load tests against production.

## Phase 8: Reliability and recovery (backend, infra)

- missing timeouts; unlimited retries; retry without backoff and jitter; retrying
  non-idempotent operations; missing dead-letter handling; poison messages; no backpressure;
  circuit-breaker needs;
- errors swallowed or downgraded; missing structured context in logs; secret or PII logging;
  missing correlation ids; missing metrics and alerts on critical operations;
- partial failures; crash before commit; crash after commit before acknowledgement;
  cache up / database down and the reverse; external API timeout after a remote side effect;
- rolling-deployment incompatibility; non-backward-compatible or destructive migrations; old and
  new versions on one schema simultaneously;
- missing reconciliation; missing recovery procedure for inconsistencies.

Distinguish: correctness bug, security issue, reliability risk, observability gap, operational
recommendation. Observability gaps alone are not Critical or High unless they block recovery
from a demonstrated high-impact failure.

## Phase 9: Tests

Specialist: `pr-review-toolkit:pr-test-analyzer`. Assess by changed behaviour and risk, not by
coverage percentage.

Look for tests of: happy path; validation failure; authorization failure; ownership / tenant
isolation; duplicate request; concurrent request; retry after partial success; rollback;
constraint violation; cache or queue failure; worker restart; boundary values (min, max,
rounding, empty, unicode); stale and duplicated events; multiple instances; backward
compatibility.

The one question that decides more than the list: **would this test go red if the thing it
guards were removed?** Answer by reasoning about the mechanism (this role does not edit source).
A vacuous assertion, a test that never reaches the branch it names, or a fix whose test passes
without the fix, is a finding. Prefer behavioural tests over implementation-detail tests. Ask
for a missing test only when it proves a meaningful scenario.

## Phase 10: Code style and maintainability

Audit **against the repository's own conventions** (`CLAUDE.md`, `CONTRIBUTING.md`,
`docs/CODE_STYLE.md`, lint config). Do not re-report what the linter enforces; run the linter
instead. Where the repository has no rule, the items below are `Recommendation` at most.

- layering and import boundaries the project declares (shared must not import apps; no
  cross-app imports; no API layer in a shared library);
- validators / guards / business logic living where the project says they live;
- naming consistent with the codebase; dead code, dead exports, commented-out blocks,
  leftover diagnostics (`console.log`, `TEMP`, `DIAG`, `TODO` without owner);
- duplicated code that has already drifted apart (two copies with one difference);
- comments that lie about the code they sit on; docs naming symbols that no longer exist;
- `any`, `as`, non-null `!` density at boundaries; `strict` off; `skipLibCheck` hiding errors;
- file and function size that hurts reading, only when it does;
- dependency hygiene: unpinned or duplicate deps, unused deps, `resolutions` that override
  transitive expectations, missing `engines` where the toolchain needs a version;
- scripts that mutate on "check" (`lint` with `--fix` as the only lint command).

## Frontend section (ts-frontend)

Security: DOM XSS sinks; unsafe HTML rendering; tokens in `localStorage` when cookies were the
design; secrets in the bundle (`NEXT_PUBLIC_`, `VITE_` with private values); open redirects;
`postMessage` without origin checks; third-party scripts without integrity.

Correctness: stale closures and missing effect deps; race conditions in data fetching (response
for an old query overwriting a new one); missing cancellation; state derived and stored
inconsistently; forms that submit twice; optimistic updates without rollback; error boundaries
missing where a failure would blank the page; i18n / timezone / number formatting.

Performance: unbounded lists without virtualization; re-render storms (unstable props,
missing memoization where measured); bundle size and code splitting; blocking main-thread work;
images without sizing; waterfalls of dependent requests; missing caching of server state.

Accessibility and UX (Recommendation unless the project requires it): keyboard reachability,
focus management in modals, labels and roles, colour contrast, motion preferences.

Tests: components tested by behaviour, not by implementation; critical flows covered end to
end; mocks that make the test pass whatever the component does.

## Terraform

The full checklist lives with the specialist: `agents/terraform-auditor.md`. Brief it with the
roots and modules in scope, the environments, the CI wiring you found, and any repository
conventions on tagging, naming and module layout.
