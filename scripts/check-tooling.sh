#!/usr/bin/env bash
# Preflight for the audit orchestrator.
#
# The audit leans on optional specialists — pr-review-toolkit, claude-security,
# typescript-lsp, context7. Without them it still runs, thinner, and the report would
# read exactly like a complete one. This says out loud what is actually there.
#
# It checks INSTALLED AND ENABLED. It cannot tell you an MCP server connected — that is
# only known inside a running session. The agent must confirm at runtime and name the
# gap in Coverage limitations.
set -uo pipefail

SETTINGS="${HOME}/.claude/settings.json"
OPTIONAL=(pr-review-toolkit claude-security typescript-lsp context7)
STATIC_TOOLS=(terraform tflint tfsec trivy checkov gh)
missing=0

if [ ! -f "$SETTINGS" ]; then
  echo "no ${SETTINGS} — cannot tell which plugins are enabled" >&2
  exit 1
fi

enabled=$(python3 - "$SETTINGS" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print('\n'.join(k.split('@')[0] for k, v in (d.get('enabledPlugins') or {}).items() if v))
PY
)

echo "Audit specialists (Claude Code plugins):"
for p in "${OPTIONAL[@]}"; do
  if grep -qx "$p" <<<"$enabled"; then
    printf '  present  %s\n' "$p"
  else
    printf '  MISSING  %s\n' "$p"
    missing=$((missing + 1))
  fi
done

echo
echo "Static tools on PATH (used when the stack needs them):"
for t in "${STATIC_TOOLS[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then
    printf '  present  %s\n' "$t"
  else
    printf '  absent   %s\n' "$t"
  fi
done

echo
if [ "$missing" -eq 0 ]; then
  echo "All optional specialists are enabled. Still confirm at runtime: an enabled MCP plugin can fail to connect."
else
  echo "$missing of ${#OPTIONAL[@]} specialists are missing. The audit runs without them via its own"
  echo "researcher and must say so in Coverage limitations. Install with:"
  echo "  claude plugin install <name>@claude-plugins-official"
fi
exit 0
