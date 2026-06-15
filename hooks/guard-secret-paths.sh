#!/usr/bin/env bash
# PreToolUse guard: block Read/Edit/Write/Bash access to secret paths (.env, .env.*, secrets/).
# Wired in settings.json under PreToolUse with matcher "Read|Edit|Write|Bash".
# Receives the hook input JSON on stdin; emits a deny decision on stdout when matched.
# Decision is carried by stdout JSON, never the exit code — always exits 0 so a jq
# hiccup can never accidentally block the session.
target=$(jq -r '.tool_input.command // .tool_input.file_path // ""' 2>/dev/null)
if printf '%s' "$target" | grep -Eq '\.env\b|secrets/'; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: protected secret path (.env / .env.* / secrets/). Edit ~/.claude/hooks/guard-secret-paths.sh to adjust."}}'
fi
exit 0
