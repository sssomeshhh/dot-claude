#!/usr/bin/env bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
session_id=$(echo "$input" | jq -r '.session_id // empty')
model=$(echo "$input" | jq -r '.model.id // empty')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
rl5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
rl5h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' | cut -d. -f1)
rl7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
rl7d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' | cut -d. -f1)
agent=$(echo "$input" | jq -r '.agent.name // "default"')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // "0"')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // "0"')
effort="${CLAUDE_CODE_EFFORT_LEVEL:-}"

# Git branch from cwd
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

# Thread name from state file
thread=""
state_file="$cwd/.claude/threads/.state"
if [ -n "$session_id" ] && [ -f "$state_file" ]; then
  thread=$(grep "^${session_id}=" "$state_file" 2>/dev/null | cut -d= -f2-)
fi

# Separators
D="\033[90m"
S="\033[2m"
R="\033[0m"

# 256-color palette
C_USER="\033[38;5;116m"
C_HOST="\033[38;5;23m"
C_DIR="\033[38;5;24m"
C_BRANCH="\033[38;5;117m"
C_MODEL="\033[38;5;103m"
C_EFFORT="\033[38;5;60m"
C_THREAD="\033[38;5;104m"
C_PROGRESS="\033[38;5;147m"
C_WIN="\033[38;5;66m"
C_AGENT="\033[38;5;146m"

# Dynamic context color
if [ -n "$ctx" ]; then
  if [ "$ctx" -ge 80 ]; then
    C_CTX="\033[38;5;131m"
  elif [ "$ctx" -ge 50 ]; then
    C_CTX="\033[38;5;137m"
  else
    C_CTX="\033[38;5;65m"
  fi
fi

# Section 1: host:user
sec1="${C_HOST}$(hostname -s | tr '[:upper:]' '[:lower:]')${R}${S}:${R}${C_USER}$(whoami)${R}"

# Section 2: dir:branch
sec2="${C_DIR}$(basename "$cwd")${R}"
[ -n "$branch" ] && sec2="${sec2}${S}:${R}${C_BRANCH}${branch}${R}"

# Section 3: identity — model:window:effort:agent
model="${model#claude-}"; model="${model%%\[*}"; model=$(echo "$model" | sed 's/\([0-9]\)-\([0-9]\)/\1.\2/g')
win=""
if [ -n "$ctx_size" ]; then
  if [ "$ctx_size" -ge 1000000 ]; then
    win="$((ctx_size / 1000000))M"
  elif [ "$ctx_size" -ge 1000 ]; then
    win="$((ctx_size / 1000))k"
  fi
fi
sec3=""
[ -n "$model" ] && sec3="${C_MODEL}${model}${R}" || sec3=""
[ -n "$win" ] && { [ -n "$sec3" ] && sec3="${sec3}${S}:${R}${C_EFFORT}${win}${R}" || sec3="${C_EFFORT}${win}${R}"; }
[ -n "$effort" ] && { [ -n "$sec3" ] && sec3="${sec3}${S}:${R}${C_EFFORT}${effort}${R}" || sec3="${C_EFFORT}${effort}${R}"; }
[ -n "$sec3" ] && sec3="${sec3}${S}:${R}${C_AGENT}${agent}${R}" || sec3="${C_AGENT}${agent}${R}"

# Section 4: usage — ctx:% + rate limits (space-joined, uniform label:percent)
sec4=""
[ -n "$ctx" ] && sec4="${C_WIN}ctx${R}${S}:${R}${C_CTX}${ctx}%${R}"

# Section 5: thread + progress from frontmatter
sec5=""
if [ -n "$thread" ] && [ "$thread" != "none" ]; then
  sec5="${C_THREAD}${thread}${R}"
  thread_file="$cwd/.claude/threads/${thread}.md"
  if [ -f "$thread_file" ]; then
    progress=$(sed -n '/^---$/,/^---$/{ s/^progress: *//p }' "$thread_file" | head -1)
    if [ -n "$progress" ]; then
      o=$(echo "$progress" | grep -oP '\d+(?=o)'); o=${o:-0}
      r=$(echo "$progress" | grep -oP '\d+(?=r)') ; r=${r:-0}
      d=$(echo "$progress" | grep -oP '\d+(?=d)') ; d=${d:-0}
      total=$((o + r + d))
      if [ "$total" -gt 0 ]; then
        sec5="${sec5}${S}:${R}${C_PROGRESS}${progress}${R}"
      fi
    fi
  fi
fi

# Format seconds remaining as human-readable duration
fmt_remaining() {
  local now reset diff d h m
  now=$(date +%s)
  reset=$1
  diff=$((reset - now))
  [ "$diff" -le 0 ] && return
  d=$((diff / 86400))
  h=$(( (diff % 86400) / 3600 ))
  m=$(( (diff % 3600) / 60 ))
  if [ "$d" -gt 0 ]; then
    echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then
    echo "${h}h${m}m"
  else
    echo "${m}m"
  fi
}

# Section 6: rate limits (5h and/or 7d, conditionally present)
sec6=""
if [ -n "$rl5h" ]; then
  if [ "$rl5h" -ge 80 ]; then C_RL="\033[38;5;131m"
  elif [ "$rl5h" -ge 50 ]; then C_RL="\033[38;5;137m"
  else C_RL="\033[38;5;65m"; fi
  sec6="${C_WIN}5h${R}${S}:${R}${C_RL}${rl5h}%${R}"
  if [ -n "$rl5h_reset" ]; then
    ttl=$(fmt_remaining "$rl5h_reset")
    [ -n "$ttl" ] && sec6="${sec6}${S}(${R}${C_WIN}${ttl}${R}${S})${R}"
  fi
fi
if [ -n "$rl7d" ]; then
  if [ "$rl7d" -ge 80 ]; then C_RL="\033[38;5;131m"
  elif [ "$rl7d" -ge 50 ]; then C_RL="\033[38;5;137m"
  else C_RL="\033[38;5;65m"; fi
  [ -n "$sec6" ] && sec6="${sec6} "
  sec6="${sec6}${C_WIN}7d${R}${S}:${R}${C_RL}${rl7d}%${R}"
  if [ -n "$rl7d_reset" ]; then
    ttl=$(fmt_remaining "$rl7d_reset")
    [ -n "$ttl" ] && sec6="${sec6}${S}(${R}${C_WIN}${ttl}${R}${S})${R}"
  fi
fi

# Line 1: identity — host:user | dir:branch | thread:progress
line1="${sec1} ${D}|${R} ${sec2}"
[ -n "$sec5" ] && line1="${line1} ${D}|${R} ${sec5}"

# Section 7: lines added/removed (hidden when both 0)
sec7=""
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
  sec7="\033[38;5;65m+${lines_added}${R}${S}/${R}\033[38;5;131m-${lines_removed}${R}"
fi

# Merge usage: context + rate limits (space-joined)
usage=""
[ -n "$sec4" ] && usage="${sec4}"
[ -n "$sec6" ] && { [ -n "$usage" ] && usage="${usage} ${sec6}" || usage="${sec6}"; }

# Line 2: identity | usage | lines
line2="${sec3}"
[ -n "$usage" ] && { [ -n "$line2" ] && line2="${line2} ${D}|${R} ${usage}" || line2="${usage}"; }
[ -n "$sec7" ] && { [ -n "$line2" ] && line2="${line2} ${D}|${R} ${sec7}" || line2="${sec7}"; }

printf "%b\n" "$line1"
[ -n "$line2" ] && printf "%b" "$line2"
