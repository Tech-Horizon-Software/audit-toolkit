---
name: audit
description: Audit a repository — a TypeScript backend or frontend, a Terraform project, or a mix — for correctness, security, performance, reliability, code style and tests, and end with one verdict and a report a person can read. Whole repository by default, or a diff (branch, PR, commit range). Recommended launch, from inside the repository, in your terminal — claude --agent audit-toolkit:audit-orchestrator "start" — which gives the audit its own session, model and turn budget. Invoking this skill in a plain session follows the same procedure here.
---

# Audit

This is the procedure. The orchestrator agent (`audit-toolkit:audit-orchestrator`) fixes the
mandate and the safety rules; this skill fixes what happens, in what order, and what comes out.

`LANGUAGE`: chosen by the user in Step 1 (default **English**). It governs everything you say to
the user, the summary at the top of the report, and the terminal summary. The evidence sections
of the report — finding IDs, code quotes, commands, paths — stay in English so the report can be
handed to anyone.

## Step 0 — Where you are

```bash
pwd && git rev-parse --show-toplevel && git branch --show-current && git status --short | head -20
"${CLAUDE_PLUGIN_ROOT}/scripts/check-tooling.sh"
```

The second command lists the optional specialists (`pr-review-toolkit`, `claude-security`,
`typescript-lsp`, `context7`) as `present` or `MISSING`, and which static tools are on `PATH`.
Keep the result: Step 1 offers to install what is missing, and the report's Coverage
limitations names what stayed missing.

You audit the repository the session is open in. If the user named a different path, say that you
audit only the current directory and ask them to relaunch there — do not `cd` into someone
else's checkout.

If this session is not running as the orchestrator agent (no `@audit-orchestrator` in the
banner), say once, verbatim:

> The full audit works best in its own session. From this repository's root, in your terminal:
> `claude --agent audit-toolkit:audit-orchestrator "start"`
> I can also run it here, in this session, with the same procedure — say which.

Wait for the answer. If they choose here, continue — same procedure, same rules.

## Step 1 — Language, job and scope (one interaction, at the very start)

Ask **once**, with a single AskUserQuestion call carrying up to three questions. Drop any
question the user's first message already answers.

**Question 1 — Language** (header `Language`, single select): **English (Recommended)**,
**Русский**, **Українська**. The user can type any other language via *Other*. If the first
message was written in a language other than English, put that language first and mark it
recommended instead. From the answer on, speak that language — see `LANGUAGE` above.

**Question 2 — Scope** (header `Scope`, single select):

1. **Whole repository (Recommended)** — every phase over the whole tree at `HEAD`.
2. **A diff** — a branch, PR number/URL, or commit range against a base ref. Ask for the base
   (`origin/main`, `origin/dev`, …) if not given; resolve a PR with `gh` when available.
3. **One area** — a directory, module or set of files, every phase.

**Question 3 — Specialists** (header `Specialists`, multi-select) — **only if Step 0 reported
any `MISSING` plugin.** One option per missing plugin, label = plugin name, description = what
the audit loses without it:

- `pr-review-toolkit` — correctness, silent failures, type design, test analysis (phases 3, 9, 10);
- `claude-security` — the security scan (phase 4);
- `typescript-lsp` — diagnostics, references and call chains for TypeScript;
- `context7` — version-specific library behaviour instead of memory.

Write the option labels and descriptions in English for this first question — the language
is not known yet.

**After the answers.** For each specialist the user selected, run

```bash
claude plugin install <name>@claude-plugins-official
```

and record the exit status. If any install succeeded, say in `LANGUAGE`: which were installed,
that a running session does not load new plugins by itself, and ask the user to run
`/reload-plugins` (or restart with the same launch command) and then say "continue". **Wait.**
When they do, re-run `${CLAUDE_PLUGIN_ROOT}/scripts/check-tooling.sh` and go on. If they
declined, or an install failed, go on without it — the gap goes to Coverage limitations, never
into a second offer.

Static tools the stack needs but `PATH` lacks (`terraform`, `tflint`, `tfsec`/`trivy`,
`checkov`) are system packages: name them and the usual install command for the platform, do
not install them.

Then one fixed confirmation, in the chosen language, skipped only when the request already
accepted it in words (English wording; translate faithfully):

> A full audit runs several agents in parallel and uses a significant amount of tokens and
> time (typically 20–60 minutes). Start it?

Wait for the answer. Past this point, decide and proceed; ask again only if a decision would
change what runs and the user is demonstrably present.

## Step 2 — Discover the repository

Do this yourself, cheaply, before any specialist:

1. **Stack detection.** Record every stack present:
   - `ts-backend`: `package.json` with `@nestjs/*`, `express`, `fastify`, `koa`, `hono`,
     `prisma`, `typeorm`, `drizzle`, `knex`, a `server`/`api`/`apps/*` layout;
   - `ts-frontend`: `react`, `next`, `vue`, `nuxt`, `@angular/*`, `svelte`, `vite`,
     `webpack` with a browser target;
   - `terraform`: any `*.tf` outside `node_modules`/vendored dirs;
   - `money`: the code moves money or balances — schema or code with `balance`, `ledger`,
     `payment`, `transaction`, `invoice`, `withdrawal`, `deposit`, `order`, `wallet`,
     `settlement`, `pnl`, `margin` used as domain concepts, not just as words. When unsure,
     ask the user in the Step 1 question rather than guessing.
2. **Repository rules.** Find and read `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`,
   `docs/CODE_STYLE.md`, `README.md`, `CONTEXT.md`, `ARCHITECTURE.md`, and any `CLAUDE.md`
   nested in modules you will audit. These outrank the defaults in `checklists.md`.
3. **Mechanical enforcement.** `package.json` scripts, ESLint/Biome/Prettier config,
   `tsconfig` strictness, husky/lint-staged, `.tflint.hcl`, `.pre-commit-config.yaml`, CI
   workflows — and whether CI actually runs tests on pull requests, or only deploys. If nothing
   checks pull requests, say so in the report: then the audit is the only check this code got.
4. **Toolset.** Take the final `check-tooling.sh` result from Steps 0–1, then confirm at
   runtime that the specialists you intend to dispatch actually answer (an enabled MCP plugin
   can still fail to connect). Record both lists for Coverage limitations.
5. **Baseline and revision.** `git rev-parse HEAD`; in diff mode also the base, the merge-base,
   `git diff --stat <merge-base>..<head>`, `--name-status`, `git log --oneline`. Review committed
   changes only; report uncommitted changes separately.

Write everything from this step to `audit/RUN-<yyyymmdd-HHMM>/00-inventory.md`. If `audit/` is
not git-ignored, say so once and recommend adding it — never commit it yourself.

## Step 3 — Phase 1: inventory and risk map

Classify what you will audit (each file in diff mode; each module/directory in repo mode):
API / auth-authz / money / database-migration / queue-event-worker-scheduler / cache /
realtime-websocket / infrastructure-config / frontend-UI / tests / internal refactor / docs.

Identify externally reachable entry points, trust boundaries, data flows, authorization
decisions, financial state transitions, asynchronous processing, transaction boundaries,
schema and constraints, dependencies, and the business invariants that can be affected.

Produce the **review plan**: which phases apply, which specialists get which brief, what runs
in parallel, what is skipped and why. A shared guard, money primitive, transaction helper,
ORM model, queue abstraction, root Terraform module or common middleware needs wider reading
than its diff size suggests.

## Step 4 — Phase 2: deterministic checks

Run what exists, never invent scripts, never use an auto-fix flag, write every log in full to
`audit/RUN-*/logs/` and grep the file — never pipe a test run through `head`/`tail`.

TypeScript: lint in check mode, typecheck (`tsc --noEmit` or the project's script), build,
unit tests, integration/e2e tests against a **local** test database only, schema validation
(`prisma validate` and the like), dependency audit when dependency files are in scope.
Terraform: as the `terraform-auditor` prescribes — static only, no `plan`.

Record per command: exact command, exit status, relevant output, whether a failure is related
to the scope, whether it pre-dates the scope (diff mode: run the same on the base ref, once,
and reuse), whether it blocks.

**Diff mode — do not check the branch out in the user's working copy.** Throwaway tree:

```bash
SCRATCH=$(mktemp -d)
git worktree add --detach "$SCRATCH/head" <head-ref>
[ -d node_modules ] && ln -s "$PWD/node_modules" "$SCRATCH/head/node_modules"
# copy .env / .env.test if the suites need them — copy, never read or compose
# run the checks in $SCRATCH/head, logs to the audit dir
rm -f "$SCRATCH/head/node_modules" && git worktree remove --force "$SCRATCH/head"
```

Remove the symlink before `worktree remove`, or it follows the link and deletes the real
`node_modules`. Same recipe pointed at the base ref for the baseline.

**Repo mode**: run in place only if `git status --short` shows a clean tree, or the user says
it is fine; otherwise use the throwaway tree at `HEAD`.

Provisioning that a check needs (`nvm use`, install, generate client, start local containers)
is allowed; say what you did. A check you could not run is not skipped silently — it goes to
Coverage limitations with the reason.

## Step 5 — Phases 3–9: the review itself

Checklists are in `${CLAUDE_PLUGIN_ROOT}/skills/audit/checklists.md`. **Open the phase you are
briefing for, at the moment you write the brief** — not at startup, not after. Each brief names
which items the code can reach and which it cannot.

| Phase | Covers | Specialist first choice | Fallback |
|---|---|---|---|
| 3 | Correctness | `pr-review-toolkit:code-reviewer`, `silent-failure-hunter`, `type-design-analyzer` | `audit-researcher` |
| 4 | Security | `claude-security:claude-security` (repo scan or diff scan) | `audit-researcher` with the Phase 4 checklist |
| 5 | Money (only when `money` detected) | `audit-researcher` | — |
| 6 | Concurrency and multi-instance (backend) | `audit-researcher` | — |
| 7 | Performance | `audit-researcher` | — |
| 8 | Reliability and recovery (backend, infra) | `audit-researcher` | — |
| 9 | Tests | `pr-review-toolkit:pr-test-analyzer` | `audit-researcher` |
| 10 | Code style and maintainability | `pr-review-toolkit:code-reviewer` against repo rules; `comment-analyzer` when docs matter | `audit-researcher` |
| TF | Terraform, all of the above for infra | `audit-toolkit:terraform-auditor` | — |
| FE | Frontend-specific (XSS, state, a11y, bundle, data fetching) | `audit-researcher` with the FE section | — |

Order: correctness and data integrity before performance and style. Skip a phase the scope
cannot reach and say so in the report. Do not use `code-simplifier` at all — this is an audit.

Every brief: the scope (files), the checklist items reachable / unreachable, the named
hypotheses from the risk map, the repository conventions that apply, the ID prefix to use, and
in diff mode the standing question about state left behind.

## Step 6 — Merge and verify

1. Merge candidates from all agents; drop duplicates (same mechanism, same place).
2. Send every Critical, High and meaningful Medium to `audit-toolkit:audit-verifier` — one
   candidate per dispatch, parallel.
3. Send every **refutation** whose being wrong would leave a Critical or High to a verifier too,
   and record the verified ones under *Rejected candidate findings* with the evidence.
4. Apply the verifier's re-grading. Re-check every path and line against the audited revision.
5. A finding cannot stay Critical or High without a `CONFIRMED` from a verifier.

Severity scale:

- `Critical` — theft, double spend, mass auth bypass, RCE, unrecoverable data or financial
  corruption, platform-wide outage, public exposure of a data store or a live secret.
- `High` — unauthorized data or financial modification, tenant/ownership isolation bypass,
  duplicate execution, lost operation, serious exploitable race, severe production-impacting
  regression, an infra change path without review.
- `Medium` — a real defect with limited impact or meaningful preconditions.
- `Low` — a small, concrete correctness, security or operational defect.
- `Recommendation` — an improvement with no demonstrated current failure. All style findings
  where the repository has no rule.

Do not report: generic best practice, style preferences, hypotheticals without a reachable
path, what the linter already enforces, missing comments without correctness impact,
micro-optimizations without measurable value, duplicates.

## Step 7 — Verdict

Exactly one:

- `BLOCK` — a Critical, a confirmed data/financial corruption, an exploitable High security
  issue, an unsafe migration or infra change, or a certain outage.
- `CHANGES REQUIRED` — confirmed bugs or important missing tests that must be fixed.
- `ACCEPTABLE WITH FOLLOW-UP` — nothing blocking, bounded improvements to schedule. **Also the
  ceiling when the checks did not run.**
- `PASS` — no confirmed material problems, and the checks ran and passed.

Lint, typecheck, build or test failures caused by the scope require at least `CHANGES
REQUIRED`. Pre-existing failures are listed separately and do not move the verdict unless the
scope worsens them.

Diff mode, later rounds: scope is the diff since the head you reported on plus every finding
claimed closed; "the author says it is fixed" is not evidence — read the fix. One report per
head SHA. Say so when the loop stops converging and hand it to a person.

## Step 8 — Report

`audit/RUN-<yyyymmdd-HHMM>/AUDIT-REPORT-<repo>-<short-sha>.md` (diff mode:
`AUDIT-REPORT-<branch>-<short-sha>.md`).

**It opens with a summary in `LANGUAGE` that a person can read** — for someone who was not in
this session and will not read further. No section numbers, no jargon, no counts in place of
content. Four short parts (headings translated into `LANGUAGE`):

- **What was audited** — what the repository (or the change) is, in product terms, and what
  scope the audit had.
- **What is wrong** — each real problem in one or two sentences: **what happens, when, and what
  it costs.** Not the defect's name, not its severity label — the consequence in words someone
  who does not read this code can act on. Say plainly when the answer is "nothing".

  Bad: `SEC-002 (High): IDOR in chat join handler.`
  Good: `Any logged-in customer can subscribe to someone else's chat by guessing its number —
  numbers are sequential, so it takes minutes. They then see every message in that chat in
  real time. There is no ownership check at all.`
- **What is sound** — what was checked and found sound; the reader needs to know the audit had
  reach, not only what it disliked.
- **What to do** — the next action and who decides it; what blocks vs what can be scheduled.

The rest is the evidence, in this order: executive summary; verdict; revision (base, merge-base,
head); scope included and excluded; stack and repository rules applied; commands executed and
results; risk map; confirmed findings by severity (each with ID, category, severity, confidence,
file:lines, evidence, path, scenario, impact, why protection fails, remediation direction,
regression test, verification status); rejected candidates; performance findings with evidence
level (`Confirmed` / `Probable` / `Needs benchmark`); invariants affected; multi-instance
scenarios checked; test coverage gaps; business decisions required; manual verification
required; **coverage limitations** (specialists used and missing, commands not run and why,
areas not reached); recommended remediation order.

Then print the terminal summary in `LANGUAGE` — counts first, then the same four parts, a line
or two each:

```text
Verdict:
Critical:  High:  Medium:  Low:  Recommendations:
Commands passed:  failed:  not run:
Report:

What was audited:
What is wrong:
What is sound:
What to do:
```

Do not modify any other file in the repository.

## Step 9 — Offer, then stop

`audit/` never leaves the machine. Offer **once**, in `LANGUAGE`:

> Post the summary as a comment on PR #<n> / the issue? It goes up under your GitHub account.

Only on an explicit yes: `gh api user -q .login` first, then post the four-part summary plus the
report path as a **comment** — never `--approve` or `--request-changes`; the verdict is advice,
the decision is a person's. If declined, say where the report is and stop. Do not offer again.
