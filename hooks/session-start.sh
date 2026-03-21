#!/usr/bin/env bash
# SessionStart hook: persist session_id as env var and create empty thread state entry
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')
state_file="$(echo "$input" | jq -r '.cwd')/.claude/threads/.state"

# Persist session_id as env var for the rest of the session
if [ -n "$CLAUDE_ENV_FILE" ] && [ -n "$session_id" ]; then
  echo "export CLAUDE_SESSION_ID=$session_id" >> "$CLAUDE_ENV_FILE"
fi

# Create default entry in thread state (session exists, no thread loaded)
if [ -n "$session_id" ]; then
  mkdir -p "$(dirname "$state_file")"
  touch "$state_file"
  # Remove any stale entry for this session_id, then add empty entry
  grep -v "^${session_id}=" "$state_file" 2>/dev/null > "${state_file}.tmp" || true
  echo "${session_id}=none" >> "${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
fi