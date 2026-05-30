#!/usr/bin/env bash
# SessionEnd hook: remove this session's entry from the canonical thread state file.
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')
cwd=$(echo "$input" | jq -r '.cwd')

# Prefer the path resolved at SessionStart; re-derive identically as a fallback.
state_file="$CLAUDE_THREADS_STATE"
if [ -z "$state_file" ]; then
  common_dir=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  if [ -n "$common_dir" ]; then base=$(dirname "$common_dir"); else base=$cwd; fi
  state_file="$base/.claude/memory/.threads-state"
fi

if [ -n "$session_id" ] && [ -f "$state_file" ]; then
  grep -v "^${session_id}=" "$state_file" > "${state_file}.tmp" 2>/dev/null || true
  mv "${state_file}.tmp" "$state_file"
fi
