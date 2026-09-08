# audit-toolkit

```bash
# once
claude plugin marketplace add Tech-Horizon-Software/audit-toolkit
claude plugin install audit-toolkit@audit-toolkit

# every audit — from inside the repository you want checked
claude --agent audit-toolkit:audit-orchestrator "start"
```

A Claude Code plugin that audits **any** repository — a TypeScript backend, a TypeScript
frontend, a Terraform project, or a mix. It is not tied to a project: it picks up the
conventions of the repository it runs in and falls back to its own defaults where there are none.

The approach is that of a strict PR quality gate: an orchestrator briefs specialists, every
serious finding is verified independently, the checks (lint, typecheck, build, tests) are
actually run, and the result is exactly one verdict and a report a person can read without
opening the code.

---

## Install

```bash
claude plugin marketplace add Tech-Horizon-Software/audit-toolkit
claude plugin install audit-toolkit@audit-toolkit
```

The repository is public — no GitHub account or SSH key is needed to install.

For local plugin development, point the marketplace at a path instead:

```bash
claude plugin marketplace add /path/to/audit-toolkit
```

Recommended (optional) specialists. Without them the audit still runs, but thinner — and the
report says so under Coverage limitations:

```bash
claude plugin install pr-review-toolkit@claude-plugins-official
claude plugin install claude-security@claude-plugins-official
claude plugin install typescript-lsp@claude-plugins-official
claude plugin install context7@claude-plugins-official
```

To see what is present, ask the agent — it runs `scripts/check-tooling.sh` at startup — or run
the script from the plugin cache directly.

For Terraform, these help when on `PATH`: `terraform`, `tflint`, `tfsec` or `trivy`, `checkov`.

Update: `claude plugin update audit-toolkit`, then restart the session.

---

## Run

From inside the repository you want audited:

```bash
claude --agent audit-toolkit:audit-orchestrator "start"
```

The quoted word is the first prompt — any text works, and you can name the scope right there
(`"whole repo"`, `"diff against origin/main"`, `"PR 42"`, `"src/payments only"`). Without it
the session opens idle: Claude Code does not currently auto-submit a plugin agent's
`initialPrompt`, so just type something to begin.

The agent asks two things up front — the language to talk in (English, Russian, Ukrainian,
or any other you type) and the scope: the whole repository, a diff (branch / PR / commit
range), or one area — then for confirmation that you accept a long multi-agent run. After that
it works on its own.

In a plain session, `/audit-toolkit:audit` follows the same procedure in the current context.
For a full run the first form is better: it has its own turn budget and model.

The report lands in `audit/RUN-<date>/` inside the audited repository. Add `audit/` to that
repository's `.gitignore` — the agent reminds you, but never commits anything.

---

## What it does

| Phase | Checks | Who |
|---|---|---|
| 1 | Inventory and risk map | orchestrator |
| 2 | lint / typecheck / build / tests / `terraform validate` — actually run | orchestrator |
| 3 | Correctness | `pr-review-toolkit`, or the built-in researcher |
| 4 | Security | `claude-security`, or the built-in researcher |
| 5 | Money (only if the repository moves money) | built-in researcher |
| 6 | Concurrency and multi-instance operation | built-in researcher |
| 7 | Performance | built-in researcher |
| 8 | Reliability and recovery | built-in researcher |
| 9 | Tests | `pr-review-toolkit`, or the built-in researcher |
| 10 | Code style and maintainability — against the repository's own rules | `pr-review-toolkit`, or the built-in researcher |
| FE | Frontend specifics | built-in researcher |
| TF | Terraform | `terraform-auditor` |

Every Critical / High / meaningful Medium finding — and every refutation whose being wrong
would leave a Critical or High — goes to an independent verifier. Without its `CONFIRMED` a
finding cannot stay Critical or High.

The verdict is one of `BLOCK`, `CHANGES REQUIRED`, `ACCEPTABLE WITH FOLLOW-UP`, `PASS`.
`PASS` is possible only when the checks actually ran and passed.

The conversation, the summary at the top of the report and the terminal summary are in the
language chosen at the start; the evidence sections of the report stay in English so it can be
handed to anyone.

---

## What the agent will not do

- modify any file in the audited repository other than under `audit/`;
- commit, push, or switch branches in your working copy (a diff is checked in a throwaway
  worktree);
- read secrets (`.env*`, `*.pem`, `*.tfstate`, `*.tfvars` with values);
- connect to a remote database or run a migration;
- run `terraform plan` / `apply` — `plan` needs credentials and reads state, so only on an
  explicit yes; `apply` / `destroy` / `state *` never;
- say "checks passed" without having run them;
- approve or block a PR — only a comment, and only on an explicit yes.

---

## Layout

```
.claude-plugin/
  plugin.json             plugin metadata
  marketplace.json        this repository as a one-plugin marketplace
agents/
  audit-orchestrator.md   entry point: mandate, operating mode, safety rules
  audit-verifier.md       independent verification of one finding / one refutation
  audit-researcher.md     phase researcher used when no specialist plugin is present
  terraform-auditor.md    Terraform: checklist and static tools
skills/audit/
  SKILL.md                procedure: steps, phases, verdict, report format
  checklists.md           checklists for phases 3–10, frontend, Terraform pointer
scripts/
  check-tooling.sh        which specialists and static tools are available
```

---

## Developing the plugin

```bash
claude plugin validate .            # manifests, agents, skills
# edit → bump version in .claude-plugin/plugin.json →
claude plugin tag                   # git tag audit-toolkit--v<version>
git push --tags
```

Colleagues then run `claude plugin update audit-toolkit`.
