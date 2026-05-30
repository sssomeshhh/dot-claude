#!/usr/bin/env bash
# SessionStart hook: persist session_id + resolve the two thread paths.
# The state pointer (untracked) anchors to the PRIMARY worktree so linked-worktree
# sessions share one pointer; the threads dir (git-tracked, per-branch) stays local to
# this worktree's cwd so thread files follow the branch they belong to.
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')
cwd=$(echo "$input" | jq -r '.cwd')

# state pointer: anchored to the primary worktree (shared across all worktrees)
common_dir=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ -n "$common_dir" ]; then base=$(dirname "$common_dir"); else base=$cwd; fi
state_file="$base/.claude/memory/.threads-state"
# threads dir: local to this worktree (git-tracked thread files travel with the branch)
threads_dir="$cwd/.claude/threads"

# Persist for the rest of the session: session id + resolved paths.
if [ -n "$CLAUDE_ENV_FILE" ]; then
  [ -n "$session_id" ] && echo "export CLAUDE_SESSION_ID=$session_id" >> "$CLAUDE_ENV_FILE"
  echo "export CLAUDE_THREADS_DIR=$threads_dir" >> "$CLAUDE_ENV_FILE"
  echo "export CLAUDE_THREADS_STATE=$state_file" >> "$CLAUDE_ENV_FILE"
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