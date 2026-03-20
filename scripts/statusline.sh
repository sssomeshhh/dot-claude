#!/usr/bin/env bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
session_id=$(echo "$input" | jq -r '.session_id // empty')
model=$(echo "$input" | jq -r '.model.id // empty')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
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
C_EFFORT="\033[38;5;146m"
C_THREAD="\033[38;5;104m"
C_PROGRESS="\033[38;5;147m"
C_WIN="\033[38;5;66m"

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

# Section 3: model:effort
sec3=""
[ -n "$model" ] && sec3="${C_MODEL}${model}${R}"
[ -n "$model" ] && [ -n "$effort" ] && sec3="${sec3}${S}:${R}${C_EFFORT}${effort}${R}"

# Section 4: window_size:ctx%
sec4=""
if [ -n "$ctx" ]; then
  win=""
  if [ -n "$ctx_size" ]; then
    if [ "$ctx_size" -ge 1000000 ]; then
      win="$((ctx_size / 1000000))m"
    elif [ "$ctx_size" -ge 1000 ]; then
      win="$((ctx_size / 1000))k"
    fi
  fi
  if [ -n "$win" ]; then
    sec4="${C_WIN}${win}${R}${S}:${R}${C_CTX}${ctx}%${R}"
  else
    sec4="${C_CTX}${ctx}%${R}"
  fi
fi

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

# Join with dark gray pipes
out="${sec1} ${D}|${R} ${sec2}"
[ -n "$sec5" ] && out="${out} ${D}|${R} ${sec5}"
[ -n "$sec3" ] && out="${out} ${D}|${R} ${sec3}"
[ -n "$sec4" ] && out="${out} ${D}|${R} ${sec4}"

printf "%b" "$out"
