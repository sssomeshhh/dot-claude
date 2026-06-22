# ~/.claude — my Claude Code configuration

Version-controlled `~/.claude`: the durable parts of my [Claude Code](https://code.claude.com) setup
— settings, hooks, skills, status line — kept in git and installed into `$HOME/.claude` as symlinks
by `./configure`.

## Why version-control `~/.claude`?

`~/.claude` mixes two very different things: a little durable configuration you author by hand, and a
lot of runtime state the tool regenerates (session logs, caches, downloaded plugins, per-project
memory — far larger than the config itself). This repo tracks only the first kind, so the setup is:

- **Reproducible** — clone, run `./configure`, and a new machine has the same configuration.
- **Reviewable** — every change to how the agent behaves is a diff in git history.
- **Quiet** — the bulk of regenerated state stays out of the way (see
  [What's tracked](#whats-tracked-and-what-isnt)).

## Install

**Prerequisites:** `git`, [`jq`](https://jqlang.github.io/jq/) (the hooks and status line parse JSON
with it), and Claude Code.

```bash
git clone https://github.com/sssomeshhh/dot-claude.git ~/code/dot-claude
cd ~/code/dot-claude
./configure
```

`./configure` symlinks each tracked item into `$HOME/.claude` (e.g. `~/.claude/settings.json` → this
repo). It is **idempotent and cautious**:

- Classifies every item as *already-linked*, *needs-relink*, *conflict*, or *new*, and prints that
  summary before doing anything.
- **Refuses to clobber** real files — if `~/.claude/<item>` exists as a normal file or directory
  (not a symlink), it stops and asks you to move it.
- Only after you confirm does it create or replace symlinks.

Because the files are symlinked, editing them in this repo changes your live `~/.claude` immediately
— no re-run needed (re-run only when adding a brand-new tracked item).

## What's tracked, and what isn't

The value of this repo is the curation. **Tracked** — the durable config you'd want on every machine:

| Item | What it is |
|------|------------|
| `CLAUDE.md` | Global instructions to the agent, loaded every session |
| `settings.json` | Claude Code settings — permissions, hooks, plugins, effort |
| `keybindings.json` | Key-binding overrides (currently none — a schema-anchored placeholder) |
| `hooks/` | Lifecycle shell hooks (session start/end, secret-path guard) |
| `scripts/statusline.sh` | Custom status-line renderer |
| `skills/` | Custom skills — see [Skills](#skills) |
| `configure` | The symlink installer itself |

**Ignored** (via `.gitignore`) — everything the tool regenerates or that's sensitive: per-project
session logs and memory (`projects/`), debug logs, file-edit history, downloaded `plugins/`
(reproducible from `enabledPlugins` in `settings.json`), assorted caches, ephemeral session runtime,
and secrets (`.credentials.json`, `history.jsonl`).

The one deliberate exception: **conversation threads** under `.claude/threads/` are runtime-ish but
*git-tracked*, because they're durable knowledge meant to travel with the branch they document (see
[`skills/threads/`](#skillsthreads) below).

## Components

### `CLAUDE.md`

Cross-project instructions injected into *every* session, so it's kept deliberately short — only
durable working principles (currently: fact-based work with strict source traceability) and a pointer
to the threads workflow. Project-specific guidance belongs in each project's own `CLAUDE.md`, not here.

### `settings.json`

User-scope Claude Code settings. This repo documents the *choices*, not every key — for the full
surface see the [official docs](#official-docs). Notable choices:

- **`effortLevel: xhigh`** — bias toward thorough reasoning by default.
- **`permissions.defaultMode: auto`** with a tool allow-list (`Bash`, `Read`, `Edit`, `Write`,
  `WebFetch`, `WebSearch`, `Grep`, `Glob`) — low friction for the common tools.
- **Skip-prompt flags** (`skipAutoPermissionPrompt`, `skipDangerousModePermissionPrompt`,
  `skipWorkflowUsageWarning`) — trade confirmation dialogs for flow; see
  [caveats](#caveats-for-adopters).
- **`enabledPlugins`** — 25 plugins enabled; the code isn't vendored, the names are just
  restored on startup. See the [Plugins](#plugins) section below.
- **Hook wiring** — points the three lifecycle events at `hooks/` (below).
- **`statusLine`** — runs `scripts/statusline.sh`.
- **`env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"`** — opts into agent teams.

### `hooks/`

Three lifecycle hooks, wired in `settings.json`. Each parses its JSON stdin with `jq`.

- **`guard-secret-paths.sh`** (`PreToolUse`, matching `Read`/`Edit`/`Write`/`Bash`) — blocks access
  to `.env*` files and `secrets/` paths. *Key mechanic:* the deny decision is carried by **stdout
  JSON** and the script **always exits 0**, so even a `jq` hiccup can never wedge the session by
  failing closed.
- **`session-start.sh`** (`SessionStart`) — resolves the two paths the threads workflow needs and
  exports them for the session. *Key mechanic:* the shared active-thread pointer is anchored to the
  **primary git worktree** (via `git rev-parse --git-common-dir`) so sessions in different linked
  worktrees share one pointer, while the thread *files* stay **local to each worktree** and travel
  with their branch.
- **`session-end.sh`** (`SessionEnd`) — removes this session's line from the shared pointer file on
  exit.

### `scripts/statusline.sh`

Renders a dense two-line status line from the JSON Claude Code feeds it: host / user / version,
repo / branch / worktree, model / context-window / effort / agent (with a ⚡ for fast mode),
context-window %, 5-hour and 7-day rate-limit usage with reset countdowns, session cost and duration,
lines added/removed, and — when a thread is loaded — its name and progress.

### `keybindings.json`

Currently an empty, schema-anchored placeholder (`"bindings": []`) — no custom keys yet, kept tracked
so overrides have a versioned home when needed.

## Skills

Custom skills authored in this repo, loaded from `~/.claude/skills/`:

- [threads](skills/threads/SKILL.md) — resumable conversation threads: durable markdown summaries in `.claude/threads/` (YAML frontmatter for decisions, open items, and discussion state), with `INDEX.md` + Mermaid `GRAPH.md` generation and cross-thread priority/backlog views — the workflow behind `CLAUDE.md`’s "Conversation Threads" pointer.

## Plugins

25 plugins are enabled via `settings.json` → `enabledPlugins`, all from the official
[`claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) marketplace —
the code isn't vendored, the names are just restored on startup. Grouped by what they do:

**Claude Code authoring & config**

- [skill-creator](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) — Create, improve, and eval Claude Code skills
- [claude-md-management](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) — Audit and keep CLAUDE.md files current
- [claude-code-setup](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-code-setup) — Recommends tailored Claude Code automations (hooks, skills, MCP, agents)
- [hookify](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/hookify) — Create custom hooks from conversation patterns or instructions
- [explanatory-output-style](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/explanatory-output-style) — Educational notes on implementation choices and patterns
- [remember](https://github.com/Digital-Process-Tools/claude-remember) — Continuous memory — compresses conversations into daily logs

**Feature development**

- [feature-dev](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/feature-dev) — Feature workflow — explore → architect → review agents
- [superpowers](https://github.com/obra/superpowers) — Brainstorming, subagent-driven dev, TDD, debugging, skill authoring
- [ralph-loop](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop) — Self-referential iterative loops (the Ralph technique) until a task is done

**Frontend & UI**

- [frontend-design](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/frontend-design) — Distinctive, production-grade frontend UI generation
- [playground](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/playground) — Build interactive single-file HTML playgrounds

**Code review & quality**

- [code-review](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-review) — Multi-agent automated PR review with confidence scoring
- [pr-review-toolkit](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/pr-review-toolkit) — Specialized PR-review agents (tests, types, errors, quality)
- [code-simplifier](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-simplifier) — Simplifies recently-changed code while preserving behavior
- [security-guidance](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/security-guidance) — Security review of generated code (injection, XSS, secrets, and more)

**Browser & web debugging**

- [playwright](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/playwright) — Microsoft Playwright MCP — browser automation and e2e testing
- [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) — Drive and inspect a live Chrome — perf, network, console, automation

**Version control**

- [github](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/github) — Official GitHub MCP — issues, PRs, repo and API access
- [commit-commands](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/commit-commands) — Git commit / push / PR-creation commands

**Language servers**

- [typescript-lsp](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/typescript-lsp) — TypeScript / JavaScript language server
- [pyright-lsp](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/pyright-lsp) — Python language server (Pyright) — types & code intelligence
- [clangd-lsp](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/clangd-lsp) — C / C++ language server (clangd)
- [kotlin-lsp](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/kotlin-lsp) — Kotlin language server
- [jdtls-lsp](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/jdtls-lsp) — Java language server (Eclipse JDT.LS)

**Integrations**

- [telegram](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/telegram) — Telegram messaging bridge with access control

## Caveats for adopters

This is **my** setup, not a turnkey template — worth reading before borrowing from it:

- **`~/.claude` config is global.** Permissions, allow-lists, and the skip-prompt flags apply to
  *every* project you run Claude Code in. The skip-prompt flags in particular reduce confirmation
  friction; only adopt them if you understand and accept that trade-off.
- **Hooks need `jq`** on `PATH`, and they run on every session/tool event — keep them fast.
- **Symlinks are live.** Edits in this repo take effect in `~/.claude` instantly; a bad edit to
  `settings.json` or a hook affects your next (or current) session.
- **The secret-path guard is a safety net, not a guarantee** — it's a regex over `.env*` and
  `secrets/`, not a comprehensive secret scanner.

## Official docs

This README covers only what's in this repo. For the full Claude Code configuration surface — every
`settings.json` key, permission and sandbox rules, the complete hook event list, MCP, skills, and
keybindings — see the official documentation at **https://code.claude.com/docs**.
