---
name: threads
description: >
  Manage resumable conversation threads in .claude/threads/ — persistent markdown
  files with YAML frontmatter that capture decisions, context, and open items across
  sessions. Supports initializing, creating, loading, searching, updating, closing,
  merging, forking, linking, and renaming threads, plus capturing an existing conversation
  as a thread. Use when the user wants to save, resume, search, or manage discussion
  topics, set up conversation threads for a new project, or list and load threads.
---

# Conversation Threads

Persistent, resumable conversation summaries stored as markdown files. Each thread captures
decisions, context, and open items so a conversation can span multiple sessions, machines,
and even different people picking up the same topic.

## Core Concepts

**Thread** — a markdown file in the threads directory with YAML frontmatter and
structured sections. One thread per topic.

**INDEX.md** — auto-generated table of all threads, grouped by status. Never edit it
manually — it is derived from thread frontmatter.

**Frontmatter** — YAML metadata at the top of each thread. Source of truth for status,
description, relationships, and timestamps.

## Storage

Default location: `.claude/threads/`

If an `INDEX.md` exists in a different location and the project's CLAUDE.md or configuration
points to it, use that location instead. Otherwise, always use the default.

## .state File

The `.claude/threads/.state` file tracks which thread is active per session. **Always
update it using `Bash` with `sed`, never using the `Edit` tool.** The Edit tool may
prompt for permissions on dotfiles inside `.claude/` subdirectories, while Bash/sed
runs without prompting.

```bash
sed -i "s/^${CLAUDE_SESSION_ID}=.*/${CLAUDE_SESSION_ID}=thread-name/" .claude/threads/.state
```

## Thread Format

Every thread is a markdown file with YAML frontmatter followed by required core sections
and optional freeform sections.

### Frontmatter

```yaml
---
status: active
summary: short free-text about current state
description: one-line summary of what this thread is about
last_updated: 2026-03-01
progress: 3o/5r/1d
related:
  - blocks: server-deployment
  - blocked-by: opencode-fork
---
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| status | yes | One of: `active`, `blocked`, `parked`, `closed` |
| summary | yes | Free-text elaboration on current state |
| description | yes | One-line summary for INDEX.md scanning |
| last_updated | yes | ISO date, updated on every change |
| progress | yes | Item counts as `Xo/Yr/Zd` — open/resolved/deferred (see Progress Tracking) |
| related | no | Typed list of thread relationships |

### Required Core Sections

Every thread must have these sections, in this order, after the frontmatter:

```markdown
# Thread Title

## Context
Why this thread exists. Background, motivation, scope.

## Decisions
| Question | Answer |
|----------|--------|
| ... | ... |

## Open Items
Numbered list of unresolved questions or tasks. Remove items as they are resolved
(move the answer to the Decisions table).
```

### Freeform Sections

Add whatever sections make sense for the topic after the core sections. Examples from
real threads: "Integration Points" tables, "Three Options" comparisons, "Documents
Produced" lists, "Key Design Points". The skill does not constrain these — they are
driven by the content.

## File Naming

Enforce **kebab-case** for all thread filenames. Convert the thread title automatically:

- "Model Server Deployment" → `model-server-deployment.md`
- "AI Coding Agent (OpenCode Fork)" → `ai-coding-agent-opencode-fork.md`

Strip parentheses, special characters, and excess whitespace. Lowercase everything.
Use hyphens as separators.

## Progress Tracking

Every thread tracks item progress in its frontmatter as `Xo/Yr/Zd`:

- **X (open)** — items in `## Open Items` that are NOT marked blocked or deferred
- **Y (resolved)** — rows in the `## Decisions` table (excluding header and separator rows)
- **Z (deferred)** — items in `## Open Items` that ARE marked as blocked, deferred, or have a `**Status:** blocked` marker

**When to update:** Recompute `progress` whenever items are added, resolved, or reclassified —
during Create (initial counts), Update (after any item change), and Close (final counts).

## Status Tags

Four statuses with specific meanings:

| Status | Meaning |
|--------|---------|
| `active` | Being worked on — this is a live topic |
| `blocked` | Waiting on something specific (explain in summary) |
| `parked` | Intentionally set aside — not blocked, just not being worked on now |
| `closed` | Done — decisions are final, no open items remain |

Closed threads stay in the threads directory (no archiving to a subdirectory).
The generated INDEX.md groups closed threads at the bottom.

## Related Threads

Express relationships between threads using a typed list in frontmatter:

```yaml
related:
  - blocks: server-deployment
  - blocked-by: opencode-fork
  - related: rbac-design
  - parent: infrastructure-overview
  - child: sidecar-implementation
  - supersedes: old-deployment-plan
  - superseded-by: new-deployment-plan
```

**Relationship types:** `blocks`, `blocked-by`, `related`, `parent`, `child`,
`supersedes`, `superseded-by`

**Auto-sync is mandatory.** When adding a directional relationship to one thread,
always add the inverse to the other:

- Adding `blocks: X` to thread A → add `blocked-by: A` to thread X
- Adding `parent: X` to thread A → add `child: A` to thread X
- Adding `supersedes: X` to thread A → add `superseded-by: A` to thread X
- `related` is symmetric — add `related: A` to X and `related: X` to A

## INDEX.md Generation

INDEX.md is **auto-generated** from thread frontmatter. Regenerate it whenever a thread
is created, updated, merged, forked, or has its status changed.

**Format:**

```markdown
# Conversation Threads

## Active

| Thread | Description | Status | Updated |
|--------|-------------|--------|---------|
| [server-deployment](server-deployment.md) | Server-side deployment — sidecar, weight storage, fleet mgmt | active — plan written, 4 details remain | 2026-03-01 |

## Blocked

| Thread | Description | Status | Updated |
|--------|-------------|--------|---------|
| ... |

## Parked

| Thread | Description | Status | Updated |
|--------|-------------|--------|---------|
| ... |

## Closed

| Thread | Description | Status | Updated |
|--------|-------------|--------|---------|
| ... |
```

Omit sections that have no threads (don't show an empty "Blocked" table). The Status
column shows the tag plus the summary. Thread names link to the file.

## Operations

### Argument Routing

Match the skill argument to an operation:

| Argument | Operation |
|----------|-----------|
| `init` | Initialize Project |
| `create` | Create |
| `capture` | Capture |
| (none) | Index |
| `index` | Index |
| `load <name>` | Load |
| `search <keyword>` | Search |
| `update [name]` | Update (defaults to active thread) |
| `close [name]` | Close (defaults to active thread) |
| `merge` | Merge (asks for source and target) |
| `fork [name]` | Fork (defaults to active thread) |
| `link` | Link (asks for threads and relationship) |
| `rename [name]` | Rename (defaults to active thread) |
| `help` | Help |
| anything else | Load (treat argument as thread name) |

### Initialize Project

When the user wants to set up conversation threads for a project that doesn't have them yet:

1. Create the threads directory (`.claude/threads/`)
2. Create an empty `INDEX.md` with the header and no threads
3. Add the CLAUDE.md pointer (see CLAUDE.md Integration below) — if CLAUDE.md doesn't
   exist, create it with just the pointer section; if it exists, append the section
4. Confirm to the user that the project is ready

This is idempotent — if the directory or INDEX.md already exists, skip those steps and
only add what's missing. If everything is already in place, tell the user the project
is already set up.

### Index

When the user asks what threads are available, or invokes `/threads` with no arguments:

1. Read all thread files in the threads directory
2. Regenerate INDEX.md from frontmatter (ensures it is current)
3. Present the INDEX.md table to the user
4. Check `last_updated` on all active and blocked threads. If any are older than 14 days,
   append a stale thread warning after the table listing thread names and age in days

### Load

When the user invokes `/threads <name>` or `/threads load <name>`:

1. Resolve the thread name to a file in the threads directory
2. If the file does not exist, inform the user — do not fall through to Create
3. Read the thread file's full contents into context
4. Update `.claude/threads/.state` via Bash/sed (see .state File section — never use Edit):
   ```bash
   sed -i "s/^${CLAUDE_SESSION_ID}=.*/${CLAUDE_SESSION_ID}=thread-name/" .claude/threads/.state
   ```
5. Present the thread's current state to the user

### Create Thread

When the user wants to start a new topic:

1. Get a thread title (ask if not provided)
2. Convert to kebab-case filename
3. Create the file with frontmatter (status: active, progress: 0o/0r/0d) and empty core sections
4. Fill in Context based on what the user describes
5. Regenerate INDEX.md
6. Update `.claude/threads/.state` via Bash/sed (see .state File section)

### Capture From Conversation

When the user says "save this as a thread" or "turn this into a thread" mid-conversation:

1. Review the current conversation for decisions made, open questions, and context
2. Extract and organize them into the thread format
3. Ask the user for a thread title (suggest one based on the content)
4. Create the thread file with populated sections
5. Present the draft to the user for review before finalizing
6. Regenerate INDEX.md
7. Update `.claude/threads/.state` via Bash/sed (see .state File section)

This is different from Create — it retroactively structures an existing conversation
rather than starting blank.

### Update Thread

When decisions are made or the situation changes during a conversation:

1. Add new decisions to the Decisions table
2. Resolve open items (move to Decisions when answered, remove from Open Items)
3. Add new open items as they surface
4. Update frontmatter: summary, status if changed, last_updated, recompute progress
5. Regenerate INDEX.md if frontmatter changed

Update incrementally — append to existing content, don't rewrite settled sections.

### Close Thread

When a topic is complete:

1. Check the Open Items section. If any items are unresolved, **list them explicitly
   to the user** and ask for confirmation before closing. Unresolved items represent
   decisions that were never made — silently clearing them loses information. The user
   might want to: resolve them now, move them to another thread, or acknowledge they
   are no longer relevant. Do not close without this confirmation step.
2. Set status to `closed`, update summary, recompute progress (should be `0o/Yr/Zd`)
3. Update last_updated
4. Regenerate INDEX.md (thread moves to Closed section)

### Merge Threads

When two threads converge into one topic:

1. Ask the user which thread survives (the "target") and which gets absorbed (the "source")
2. Merge the source's content into the target:
   - Combine Decisions tables (deduplicate, flag conflicts for user resolution)
   - Combine Open Items (deduplicate)
   - Merge Context sections (target's context first, then relevant source context)
   - Combine freeform sections (keep both, reorder if needed)
3. Union the Related links from both threads
4. Close the source thread with status `closed` and summary "merged into [target]"
5. Add `supersedes: [source]` to target, `superseded-by: [target]` to source
6. Regenerate INDEX.md

If decisions conflict between threads, present both to the user and ask which stands.

### Fork Thread

When a thread spawns a clearly separate subtopic:

1. Ask the user for the new thread's title and which content to move
2. Create the new thread with the extracted content
3. Remove the forked content from the original thread
4. Add `parent: [original]` to new thread, `child: [new]` to original
5. Regenerate INDEX.md

### Link Threads

When the user wants to express a relationship between threads:

1. Identify the relationship type (ask if ambiguous)
2. Add the relationship to the source thread's frontmatter
3. Auto-sync the inverse to the target thread
4. Regenerate INDEX.md

### Rename Thread

When a thread's scope has evolved and the filename no longer fits:

1. Ask for the new title (suggest one based on current content if not provided)
2. Convert to kebab-case filename
3. Rename the file
4. Update the `# Thread Title` heading inside the file to match
5. Update all `related` references in other threads that point to the old filename
6. Regenerate INDEX.md
7. If the renamed thread is currently loaded (old name matches this session's `.claude/threads/.state` entry), update the entry to the new name via Bash/sed (see .state File section)

### Search

When the user invokes `/threads search <keyword>`:

1. Grep all `.md` files in the threads directory (excluding `INDEX.md`) for the keyword
2. Group results by thread name
3. For each matching thread, show its status from frontmatter and the matching lines with
   a few lines of surrounding context
4. Show a summary line at the end: `N threads, M matches`

If no matches are found, say so. The keyword is a substring or regex — no fuzzy matching.

### Help

When the user invokes `/threads help`:

Present this quick reference:

```
/threads init         Initialize threads for a new project
/threads create       Start a new thread
/threads capture      Save current conversation as a thread
/threads              List all threads (Index)
/threads <name>       Load a specific thread
/threads search <kw>  Search across all threads
/threads update       Record decisions/items on active thread
/threads close        Mark thread as done
/threads merge        Combine two threads
/threads fork         Split a subtopic into its own thread
/threads link         Add relationship between threads
/threads rename       Change thread title and filename
/threads help         This message
```

## Size Management

When a thread exceeds approximately **150 lines**, suggest to the user that it may benefit
from one of:

- **Forking** — splitting a subtopic into its own thread
- **Summarizing** — condensing settled decisions and old context into a shorter form

This is a suggestion, not a hard rule. Some threads are naturally long because they have
many decisions. The goal is to keep threads scannable — if it reads well at 180 lines,
that's fine.

## CLAUDE.md Integration

For a project to use conversation threads, its CLAUDE.md needs a one-line pointer. This
is the recommended addition:

```markdown
## Conversation Threads

Resumable conversation summaries in `.claude/threads/`.
```

The skill handles everything else. The CLAUDE.md pointer just tells Claude that this
project uses conversation threads.

## Migrating Existing Threads

If a project already has conversation threads without frontmatter (like inline status
and last-updated), offer to migrate them:

1. Extract metadata from inline fields into YAML frontmatter
2. Restructure into core sections if needed
3. Strip behavioral instructions from INDEX.md (the skill owns that behavior now)
4. Regenerate INDEX.md from the new frontmatter
