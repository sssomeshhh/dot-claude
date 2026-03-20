#!/usr/bin/env bash
# SessionEnd hook: remove thread state entry for this session
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')
state_file="$(echo "$input" | jq -r '.cwd')/.claude/threads/.state"

if [ -n "$session_id" ] && [ -f "$state_file" ]; then
  grep -v "^${session_id}=" "$state_file" > "${state_file}.tmp" 2>/dev/null || true
  mv "${state_file}.tmp" "$state_file"
fi