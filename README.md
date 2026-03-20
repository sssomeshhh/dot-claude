# ~/.claude/ Directory Reference

Exhaustive reference for the Claude Code user-level configuration directory.
Based on official documentation at [code.claude.com/docs](https://code.claude.com/docs).

---

## This Instance

This repository is a version-controlled `~/.claude/` directory. The `.gitignore` separates
durable config (settings, hooks, skills, scripts) from ephemeral or sensitive data (projects/,
sessions/, debug/, credentials, history). Everything below this section is generic Claude Code
reference material; this section documents what's actually configured here.

### Active Configuration

- **settings.json** — effort: high, experimental agent teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`), skill-creator plugin active. Permissions allow all core tools (Bash, Read, Edit, Write, WebFetch, WebSearch, Grep, Glob, LS, MultiEdit) and deny `.env` and `secrets/` paths.
- **keybindings.json** — no overrides (empty bindings array).
- **hooks/** — session lifecycle hooks supporting the threads skill (see below).
- **scripts/statusline.sh** — custom status line: `host:user | dir:branch | thread:progress | model:effort | window:ctx%`. Uses 256-color ANSI with dynamic context color (green <50%, amber 50-80%, red >80%).
- **skills/threads/** — conversation thread management (`/threads`). Full spec in `skills/threads/SKILL.md`, test scenarios in `skills/threads/evals/evals.json`.

### Architecture: Hooks → .state → Statusline

The hooks, statusline, and threads skill form a pipeline through a shared `.state` file:

1. **session-start.sh** (SessionStart hook) — persists `CLAUDE_SESSION_ID` as an env var via `$CLAUDE_ENV_FILE`, then writes `session_id=none` into the project's `.claude/threads/.state` file.
2. **The threads skill** — when a thread is loaded, updates the `.state` entry to `session_id=thread-name` via `sed`. Uses Bash/sed (never the Edit tool) to avoid permission prompts on dotfiles inside `.claude/`.
3. **statusline.sh** — reads `.state` to find the active thread for the current session, then reads the thread file's frontmatter for progress (`Xo/Yr/Zd`). Displays both in the status line.
4. **session-end.sh** (SessionEnd hook) — removes the session's `.state` entry.

The `.state` file format is one `session_id=thread-name` pair per line. It lives at `.claude/threads/.state` within each project that uses threads.

### Operational Cautions

- **Hooks run in every Claude Code session.** A syntax error in session-start.sh or session-end.sh will fire on every session start/end across all projects. Test changes carefully.
- **The statusline script runs continuously.** Performance matters — it should complete in milliseconds. Avoid network calls or expensive operations.
- **settings.json permissions are global.** The allow/deny rules here apply to every project. Overly broad allows or missing denies affect all sessions.

---

## Directory Layout

### Tracked (version-controlled config)

```
~/.claude/
├── CLAUDE.md                        # User-level instructions (loaded every session)
├── settings.json                    # User-level settings (global across all projects)
├── keybindings.json                 # Keyboard shortcut overrides
├── agents/                          # User-level subagent definitions
│   └── <agent-name>.md
├── skills/                          # User-level custom skills
│   └── <skill-name>/
│       └── SKILL.md
├── rules/                           # User-level rules (path-scoped instructions)
│   └── <rule>.md
├── commands/                        # Legacy slash commands (superseded by skills/)
│   └── <command-name>.md
├── scripts/                         # Custom scripts (statusline, hooks, etc.)
│   └── statusline.sh
└── teams/                           # Agent team definitions
    └── <team-name>/
```

### Ignored (ephemeral / sensitive / generated)

```
~/.claude/
├── .credentials.json                # Auth secrets
├── history.jsonl                    # Conversation history
├── stats-cache.json                 # Usage statistics cache
├── projects/                        # Per-project session logs + auto memory
├── debug/                           # Debug logs
├── file-history/                    # File edit history
├── plugins/                         # Marketplace plugin cache (reproducible via settings.json)
├── sessions/                        # Session state files
├── session-env/                     # Per-session environment snapshots
├── shell-snapshots/                 # Shell environment snapshots
├── plans/                           # Conversation-scoped plans
├── tasks/                           # Background task state
├── todos/                           # Todo tracking
├── cache/                           # General cache
├── paste-cache/                     # Clipboard cache
├── backups/                         # Auto-backups of config files (5 most recent retained)
├── ide/                             # IDE integration state
├── downloads/                       # Temporary downloads
└── telemetry/                       # Usage telemetry
```

### Related files outside ~/.claude/

| File | Purpose |
|------|---------|
| `~/.claude.json` | MCP servers (user/local scope), OAuth state, per-project trust, preferences |
| `/etc/claude-code/managed-settings.json` | Organization-enforced settings (Linux/WSL) |
| `/etc/claude-code/managed-mcp.json` | Organization-enforced MCP servers (Linux/WSL) |
| `/etc/claude-code/CLAUDE.md` | Organization-enforced instructions (Linux/WSL) |

macOS equivalents: `/Library/Application Support/ClaudeCode/`
Windows equivalents: `C:\Program Files\ClaudeCode\`

---

## Settings Precedence

All configuration follows this precedence (highest to lowest):

1. **Managed** — `managed-settings.json` / MDM / OS policies (cannot be overridden)
2. **CLI arguments** — `--model`, `--allowedTools`, `--disallowedTools`, etc.
3. **Local project** — `.claude/settings.local.json` (per-machine, gitignored)
4. **Shared project** — `.claude/settings.json` (committed, team-shared)
5. **User** — `~/.claude/settings.json` (personal, all projects)

Array settings (permissions, hooks, allowed domains) merge across scopes. If denied at any level, no other level can allow it.

---

## settings.json

Schema: `https://json.schemastore.org/claude-code-settings.json`

### Model & Authentication

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `model` | string | — | All | Default model override. Example: `"claude-opus-4-6"` |
| `availableModels` | string[] | — | Project+ | Restrict model selection. Example: `["sonnet", "haiku"]` |
| `modelOverrides` | object | — | All | Map Anthropic model IDs to provider-specific IDs (Bedrock ARNs, etc.) |
| `apiKeyHelper` | string | — | All | Script to generate auth value (run in `/bin/sh`) |
| `forceLoginMethod` | string | — | Managed | `"claudeai"` or `"console"` |
| `forceLoginOrgUUID` | string | — | Managed | Auto-select organization UUID during login |

### Effort & Thinking

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `effortLevel` | string | — | All | `"low"`, `"medium"`, or `"high"` |
| `alwaysThinkingEnabled` | boolean | false | User/Project/Local | Enable extended thinking by default |
| `fastModePerSessionOptIn` | boolean | false | Managed | Require per-session fast mode opt-in |

### Permissions

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `permissions` | object | — | All | See [Permissions Object](#permissions-object) |
| `disableBypassPermissionsMode` | string | — | Managed | Set to `"disable"` to prevent bypass mode |
| `allowManagedPermissionRulesOnly` | boolean | false | Managed | Only managed permission rules apply |

### Sandbox

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `sandbox` | object | — | All | See [Sandbox Object](#sandbox-object) |

### Hooks & Automation

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `hooks` | object | `{}` | All | See [Hooks](#hooks) |
| `disableAllHooks` | boolean | false | All | Disable all hooks and custom status line |
| `allowManagedHooksOnly` | boolean | false | Managed | Only managed/SDK hooks load |
| `allowedHttpHookUrls` | string[] | — | All | Allowlist for HTTP hook URLs (supports `*` wildcard) |
| `httpHookAllowedEnvVars` | string[] | — | All | Allowlist of env vars HTTP hooks may interpolate |

### Status Line & File Picker

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `statusLine` | object | — | User/Project/Local | `{"type": "command", "command": "path/to/script.sh"}` |
| `fileSuggestion` | object | — | User/Project/Local | Custom `@` file autocomplete script |
| `respectGitignore` | boolean | true | User/Project/Local | Whether `@` picker respects `.gitignore` |

### MCP Servers

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `enableAllProjectMcpServers` | boolean | false | User/Project/Local | Auto-approve all servers from `.mcp.json` |
| `enabledMcpjsonServers` | string[] | — | User/Project/Local | Allowlist specific servers by name |
| `disabledMcpjsonServers` | string[] | — | User/Project/Local | Blocklist specific servers by name |
| `allowManagedMcpServersOnly` | boolean | false | Managed | Only managed allowlist applies |
| `allowedMcpServers` | object[] | — | Managed | Allowlist: `[{"serverName": "..."}]` |
| `deniedMcpServers` | object[] | — | Managed | Denylist (takes precedence over allowlist) |

### Plugins & Marketplaces

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `enabledPlugins` | object | `{}` | User/Project/Local | `{"plugin-name@marketplace": true}` |
| `extraKnownMarketplaces` | object | — | All | Register additional plugin marketplaces |
| `strictKnownMarketplaces` | object[] | — | Managed | Allowlist of marketplace sources |
| `blockedMarketplaces` | object[] | — | Managed | Blocklist of marketplace sources |
| `pluginTrustMessage` | string | — | Managed | Custom message appended to plugin trust warning |

### Agents & Teams

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `agent` | string | — | User/Project/Local | Run main thread as named subagent |
| `teammateMode` | string | `"auto"` | User/Project/Local | `"auto"`, `"in-process"`, or `"tmux"` |

### Memory & Sessions

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `autoMemoryEnabled` | boolean | true | All | Enable/disable auto memory |
| `autoMemoryDirectory` | string | — | Local/User/Managed | Custom memory directory (not allowed in project settings) |
| `cleanupPeriodDays` | integer | 30 | All | Delete inactive sessions after N days (0 = disable persistence) |
| `plansDirectory` | string | `~/.claude/plans` | User/Project/Local | Where plan files are stored |

### Git & Attribution

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `attribution` | object | — | User/Project/Local | `{"commit": "text", "pr": "text"}` |
| `includeCoAuthoredBy` | boolean | true | User/Project/Local | **Deprecated** — use `attribution` |
| `includeGitInstructions` | boolean | true | All | Include built-in git workflow instructions |

### Output & UX

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `language` | string | — | All | Preferred response language (e.g., `"japanese"`) |
| `outputStyle` | string | — | User/Project/Local | Output style name |
| `spinnerVerbs` | object | — | User/Project/Local | `{"mode": "append"\|"replace", "verbs": [...]}` |
| `spinnerTipsEnabled` | boolean | true | All | Show tips in spinner |
| `spinnerTipsOverride` | object | — | User/Project/Local | `{"excludeDefault": bool, "tips": [...]}` |
| `prefersReducedMotion` | boolean | false | User/Project/Local | Reduce UI animations |

### Environment & Telemetry

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `env` | object | `{}` | All | Environment variables applied every session |
| `otelHeadersHelper` | string | — | All | Script for OpenTelemetry headers |
| `feedbackSurveyRate` | number | — | All | Survey probability (0–1) |

### Cloud & Enterprise

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `awsAuthRefresh` | string | — | All | Custom AWS auth refresh script |
| `awsCredentialExport` | string | — | All | Script outputting AWS credentials as JSON |
| `companyAnnouncements` | string[] | — | Managed | Startup announcements |
| `channelsEnabled` | boolean | false | Managed | Allow channels for Team/Enterprise |
| `voiceEnabled` | boolean | false | User/Project/Local | Push-to-talk voice dictation |
| `autoUpdatesChannel` | string | `"latest"` | All | `"stable"` or `"latest"` |

### File & Directory Access

| Key | Type | Default | Scope | Description |
|-----|------|---------|-------|-------------|
| `additionalDirectories` | string[] | `[]` | User/Project/Local | Additional working directories |
| `claudeMdExcludes` | array | — | All | Exclude CLAUDE.md files by path/glob |
| `worktree` | object | — | All | `{"symlinkDirectories": [...], "sparsePaths": [...]}` |

---

## Permissions Object

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": ["Bash(npm run *)", "Read(./.env)"],
    "ask": ["Bash(git push *)"],
    "deny": ["Bash(curl *)", "Read(./secrets/**)"],
    "additionalDirectories": ["../docs/"]
  }
}
```

### Modes

| Mode | Description |
|------|-------------|
| `default` | Prompts for permission on first use |
| `acceptEdits` | Auto-accept file edit permissions |
| `plan` | Analyze only — no modifications or commands |
| `dontAsk` | Auto-deny unless pre-approved |
| `bypassPermissions` | Skip prompts (except `.git`, `.claude`, `.vscode`, `.idea`) |

### Rule Syntax

Evaluation order: Deny → Ask → Allow. First match wins.

| Pattern | Example | Matches |
|---------|---------|---------|
| Tool (all) | `Bash` | Any bash command |
| Exact command | `Bash(npm run build)` | Only `npm run build` |
| Wildcard suffix | `Bash(npm run *)` | `npm run test`, `npm run build` |
| Wildcard prefix | `Bash(* install)` | Any command ending with ` install` |
| Path (cwd-relative) | `Read(./file.env)` | `<cwd>/file.env` |
| Path (project-relative) | `Edit(/src/**/*.ts)` | `<project>/src/...` |
| Path (home-relative) | `Read(~/.zshrc)` | Home directory file |
| Path (absolute) | `Edit(//tmp/scratch.txt)` | `/tmp/scratch.txt` |
| Domain | `WebFetch(domain:example.com)` | Requests to example.com |
| MCP (all tools) | `mcp__puppeteer` | All puppeteer tools |
| MCP (specific) | `mcp__puppeteer__navigate` | One specific tool |
| Subagent | `Agent(Explore)` | Built-in Explore agent |

Note: Read/Edit deny rules block Claude's file tools but NOT bash subprocesses (e.g., `cat .env` still works).

---

## Sandbox Object

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["git", "docker"],
    "allowUnsandboxedCommands": true,
    "filesystem": {
      "allowWrite": ["/tmp/build", "~/.kube"],
      "denyWrite": ["/etc"],
      "denyRead": ["~/.aws/credentials"],
      "allowRead": ["."],
      "allowManagedReadPathsOnly": false
    },
    "network": {
      "allowUnixSockets": ["~/.ssh/agent-socket"],
      "allowAllUnixSockets": false,
      "allowLocalBinding": false,
      "allowedDomains": ["github.com", "*.npmjs.org"],
      "allowManagedDomainsOnly": false,
      "httpProxyPort": 8080,
      "socksProxyPort": 8081
    },
    "enableWeakerNestedSandbox": false,
    "enableWeakerNetworkIsolation": false
  }
}
```

Path prefixes: `/` = absolute, `~/` = home, `./` or bare = project root (project settings) or `~/.claude` (user settings).

---

## CLAUDE.md

User-level instructions loaded every session. Composes with project and directory-level files.

### Loading Order

1. **Managed** — `/etc/claude-code/CLAUDE.md` (cannot be excluded)
2. **Ancestor hierarchy** — walk up from working directory, load `./CLAUDE.md` and `./.claude/CLAUDE.md` at each level, plus `./.claude/rules/**/*.md`
3. **User** — `~/.claude/CLAUDE.md` and `~/.claude/rules/**/*.md`
4. **Nested** — subdirectory `CLAUDE.md` files (lazy-loaded when reading files there)

More specific files take precedence. Content is concatenated across levels.

### @import Syntax

```markdown
See @README.md for project overview.
Architecture details: @docs/architecture.md
Shared rules: @~/.claude/my-shared-rules.md
```

- Relative paths resolve relative to the file containing the import
- Absolute and `~/` paths supported
- Max depth: 5 hops
- First encounter shows approval dialog

### Excluding

```json
{
  "claudeMdExcludes": [
    "**/monorepo/CLAUDE.md",
    "/home/user/monorepo/other-team/.claude/rules/**"
  ]
}
```

Managed CLAUDE.md cannot be excluded.

---

## keybindings.json

Keyboard shortcut overrides. Defaults are built-in — only overrides go here.

```json
{
  "$schema": "https://www.schemastore.org/claude-code-keybindings.json",
  "$docs": "https://code.claude.com/docs/en/keybindings",
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "ctrl+e": "chat:externalEditor",
        "ctrl+s": null
      }
    }
  ]
}
```

Set to `null` to unbind. Reserved (not rebindable): Ctrl+C, Ctrl+D.

### Keystroke Syntax

- Modifiers: `ctrl`, `alt`/`opt`, `shift`, `meta`/`cmd` — combine with `+`
- Chords: `ctrl+k ctrl+s` (press Ctrl+K, release, then Ctrl+S)
- Special keys: `escape`, `enter`, `tab`, `space`, `up`, `down`, `left`, `right`, `backspace`, `delete`
- Uppercase standalone letter (e.g., `K`) implies Shift

### Contexts and Actions

#### Global

| Action | Default | Description |
|--------|---------|-------------|
| `app:interrupt` | Ctrl+C | Cancel current operation (reserved) |
| `app:exit` | Ctrl+D | Exit Claude Code (reserved) |
| `app:toggleTodos` | Ctrl+T | Toggle task list |
| `app:toggleTranscript` | Ctrl+O | Toggle verbose transcript |
| `history:search` | Ctrl+R | Open history search |
| `history:previous` | Up | Previous history item |
| `history:next` | Down | Next history item |

#### Chat

| Action | Default | Description |
|--------|---------|-------------|
| `chat:submit` | Enter | Submit message |
| `chat:cancel` | Escape | Cancel input |
| `chat:cycleMode` | Shift+Tab | Cycle permission modes |
| `chat:modelPicker` | Meta+P | Open model picker |
| `chat:thinkingToggle` | Meta+T | Toggle extended thinking |
| `chat:undo` | Ctrl+_ | Undo last action |
| `chat:externalEditor` | Ctrl+G | Open in external editor |
| `chat:stash` | Ctrl+S | Stash current prompt |
| `chat:imagePaste` | Ctrl+V | Paste image (Alt+V on Windows) |
| `voice:pushToTalk` | Space | Hold to dictate (when voice enabled) |

#### Autocomplete

| Action | Default |
|--------|---------|
| `autocomplete:accept` | Tab |
| `autocomplete:dismiss` | Escape |
| `autocomplete:previous` | Up |
| `autocomplete:next` | Down |

#### Confirmation

| Action | Default |
|--------|---------|
| `confirm:yes` | Y, Enter |
| `confirm:no` | N, Escape |
| `confirm:previous` | Up |
| `confirm:next` | Down |
| `confirm:nextField` | Tab |
| `confirm:previousField` | (unbound) |
| `confirm:cycleMode` | Shift+Tab |
| `confirm:toggleExplanation` | Ctrl+E |
| `permission:toggleDebug` | Ctrl+D |

#### Transcript

| Action | Default |
|--------|---------|
| `transcript:toggleShowAll` | Ctrl+E |
| `transcript:exit` | Ctrl+C, Escape |

#### History Search

| Action | Default |
|--------|---------|
| `historySearch:next` | Ctrl+R |
| `historySearch:accept` | Escape, Tab |
| `historySearch:cancel` | Ctrl+C |
| `historySearch:execute` | Enter |

#### Task

| Action | Default |
|--------|---------|
| `task:background` | Ctrl+B |

#### Other Contexts

| Context | Action | Default |
|---------|--------|---------|
| ThemePicker | `theme:toggleSyntaxHighlighting` | Ctrl+T |
| Help | `help:dismiss` | Escape |
| Tabs | `tabs:next` / `tabs:previous` | Tab, Right / Shift+Tab, Left |
| Attachments | `attachments:next` / `previous` / `remove` / `exit` | Right / Left / Backspace / Down |
| Footer | `footer:next` / `previous` / `openSelected` / `clearSelection` | Right / Left / Enter / Escape |
| MessageSelector | `up` / `down` / `top` / `bottom` / `select` | Up,K / Down,J / Ctrl+Up / Ctrl+Down / Enter |
| DiffDialog | `dismiss` / `previousSource` / `nextSource` / `previousFile` / `nextFile` / `viewDetails` | Escape / Left / Right / Up / Down / Enter |
| ModelPicker | `decreaseEffort` / `increaseEffort` | Left / Right |
| Select | `next` / `previous` / `accept` / `cancel` | Down / Up / Enter / Escape |
| Plugin | `toggle` / `install` | Space / I |
| Settings | `search` / `retry` | / / R |

### Terminal Conflicts

- Ctrl+B — tmux prefix (press twice to send)
- Ctrl+A — GNU screen prefix
- Ctrl+Z — Unix process suspend

### Vim Mode

When vim mode is enabled (`/vim`): vim handles text-level input (cursor, modes, motions); keybindings handle component-level actions. Escape in NORMAL mode does NOT trigger `chat:cancel`. Most Ctrl+key shortcuts pass through to keybindings.

---

## agents/

User-level subagent definitions. Markdown files with YAML frontmatter.

### Frontmatter Schema

```yaml
---
name: agent-name                     # Required. Lowercase + hyphens, max 64 chars
description: When to invoke...       # Required. Used for automatic selection
tools: Read, Grep, Glob, Bash       # Allowed tools (omit = all). Comma-separated or array
disallowedTools: Write, Edit        # Denied tools (removed from allowed set)
model: sonnet|opus|haiku|inherit    # Model (default: inherit from parent)
permissionMode: default             # default|acceptEdits|dontAsk|bypassPermissions|plan
maxTurns: 20                        # Max agentic turns before stopping
skills:                             # Skills to preload into context
  - api-conventions
mcpServers:                         # MCP servers available to agent
  - server-name                     #   Reference by name (reuses session connection)
  - custom:                         #   Inline definition (scoped to agent)
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
memory: user|project|local          # Persistent memory scope
background: false                   # Always run as background task
effort: low|medium|high|max         # Effort level override
isolation: worktree                 # Run in isolated git worktree
hooks:                              # Agent-scoped hooks (only active while agent runs)
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./script.sh"
  Stop:                             # Converted to SubagentStop at runtime
    - hooks:
        - type: command
          command: "./cleanup.sh"
---

System prompt content in markdown...
```

### Memory Scopes

| Scope | Path | Shared |
|-------|------|--------|
| `user` | `~/.claude/agent-memory/<agent-name>/` | All projects, machine-local |
| `project` | `.claude/agent-memory/<agent-name>/` | Version-controlled |
| `local` | `.claude/agent-memory-local/<agent-name>/` | Gitignored |

When enabled: first 200 lines of `MEMORY.md` loaded; Read/Write/Edit auto-enabled for memory.

### Priority (name conflicts)

1. CLI `--agents` flag (session only, highest)
2. `.claude/agents/` (project)
3. `~/.claude/agents/` (user)
4. Plugin agents (lowest; hooks/mcpServers/permissionMode ignored for plugin agents)

### Built-in Agents

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| Explore | Haiku | Read-only | Fast codebase search/analysis |
| Plan | Inherit | Read-only | Research for plan mode |
| General-purpose | Inherit | All | Complex multi-step tasks |

### Invocation

- Natural language — name the agent in conversation
- `@agent-<name>` or `@"<name> (agent)"` mention
- `claude --agent code-reviewer` (session-wide via CLI)
- `{"agent": "code-reviewer"}` in settings.json (persistent)

---

## skills/

User-level custom skills. Each skill is a directory with a `SKILL.md`.

### Directory Structure

```
skills/
└── my-skill/
    ├── SKILL.md              # Required: frontmatter + instructions
    ├── references/           # Optional: supplementary docs
    │   └── api-spec.md
    ├── scripts/              # Optional: helper scripts
    │   └── validate.sh
    └── examples.md           # Optional: usage examples
```

### SKILL.md Frontmatter

```yaml
---
name: my-skill                       # Display name (kebab-case, max 64 chars). Default: dir name
description: What the skill does...  # When Claude should load it
argument-hint: "[issue-number]"      # Autocomplete hint
disable-model-invocation: false      # true = manual only, Claude cannot auto-invoke
user-invocable: true                 # false = only Claude can invoke (background knowledge)
allowed-tools: Read, Grep, Glob     # Tools allowed without permission prompts when active
model: sonnet|opus|haiku|inherit    # Model override
context: fork|inherit               # fork = isolated subagent, inherit = inline (default)
agent: Explore|Plan|general-purpose # Subagent type when context: fork
hooks:                              # Skill-scoped hooks (active while skill runs)
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./validate.sh"
          once: true                 # Skills only: run once then remove
---

Skill instructions in markdown...
```

### String Substitutions

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed to skill |
| `$ARGUMENTS[N]` | Nth argument (0-based) |
| `$N` | Shorthand for `$ARGUMENTS[N]` |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `${CLAUDE_SKILL_DIR}` | Absolute path to skill directory |

If `$ARGUMENTS` is not present in the skill, Claude Code appends `ARGUMENTS: <value>` automatically.

### Dynamic Context Injection

Use `` !`command` `` to run shell commands before the skill is sent to Claude:

```markdown
## PR Data
- Diff: !`gh pr diff`
- Comments: !`gh pr view --comments`

Summarize this PR...
```

Commands execute as preprocessing — output replaces the placeholder before Claude sees it.

### Discovery

- `~/.claude/skills/` — user-level (all projects)
- `.claude/skills/` — project-level
- Nested `.claude/skills/` in subdirectories — auto-discovered when editing files there
- `--add-dir` directories — auto-discovered with live change detection
- Plugin `skills/` — namespaced as `plugin-name:skill-name`

Precedence: Enterprise > Personal > Project > Plugin. If skill and command share a name, skill wins.

### Invocation Control

| Setting | User | Claude | Use case |
|---------|:----:|:------:|----------|
| (default) | Yes | Yes | Normal skill |
| `disable-model-invocation: true` | Yes | No | Manual-only |
| `user-invocable: false` | No | Yes | Background knowledge |

---

## rules/

User-level rules — modular, path-scoped instructions. All `.md` files discovered recursively.

### Frontmatter

```yaml
---
name: optional-display-name          # Optional
paths:                               # Optional: glob patterns for conditional loading
  - "src/api/**/*.ts"
  - "**/*.test.ts"
  - "src/**/*.{ts,tsx}"
---

Rule content in markdown...
```

### Loading Behavior

| Type | Has `paths`? | When Loaded |
|------|:---:|-------------|
| Unconditional | No | Session start |
| Conditional | Yes | When Claude reads files matching glob pattern |

### Discovery

- All `.md` files under `~/.claude/rules/` discovered recursively
- Subdirectory structure is organizational only (no effect on loading)
- Project rules (`.claude/rules/`) take precedence over user rules (`~/.claude/rules/`)
- Symlinks supported for shared rule sets

```
rules/
├── code-style.md
├── frontend/
│   ├── react.md
│   └── styling.md
└── backend/
    ├── api.md
    └── database.md
```

---

## commands/

Legacy slash commands. **Use `skills/` instead** — commands are maintained for backwards compatibility.

```
commands/
└── command-name.md       # Creates /command-name
```

Same frontmatter as skills. If both skill and command share a name, skill wins.

---

## Hooks

Lifecycle hooks configured in `settings.json` under the `hooks` key. Can also be defined in agent/skill frontmatter (scoped to that agent/skill).

### Configuration Format

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/validate.sh",
            "timeout": 600,
            "statusMessage": "Validating...",
            "once": false,
            "async": false
          }
        ]
      }
    ]
  }
}
```

### Hook Events

#### Session Lifecycle

| Event | Fires When | Matcher Values | Can Block |
|-------|-----------|----------------|:---------:|
| `SessionStart` | Session begins or resumes | `startup`, `resume`, `clear`, `compact` | No |
| `SessionEnd` | Session terminates | `clear`, `resume`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other` | No |
| `InstructionsLoaded` | CLAUDE.md or rule file loaded | `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact` | No |

#### User Input

| Event | Fires When | Matcher | Can Block |
|-------|-----------|---------|:---------:|
| `UserPromptSubmit` | Before processing user prompt | — | Yes |

#### Tool Execution

| Event | Fires When | Matcher | Can Block |
|-------|-----------|---------|:---------:|
| `PreToolUse` | Before tool executes | Tool name (regex) | Yes |
| `PostToolUse` | After tool succeeds | Tool name (regex) | Yes |
| `PostToolUseFailure` | After tool fails | Tool name (regex) | No |
| `PermissionRequest` | Permission dialog about to show | Tool name (regex) | Yes |

#### Agent Control

| Event | Fires When | Matcher | Can Block |
|-------|-----------|---------|:---------:|
| `SubagentStart` | Subagent spawned | Agent type name | No |
| `SubagentStop` | Subagent finishes | Agent type name | Yes |
| `Stop` | Main agent finishes responding | — | Yes |
| `StopFailure` | Turn ends due to API error | Error type | No |

#### Team & Tasks

| Event | Fires When | Matcher | Can Block |
|-------|-----------|---------|:---------:|
| `TeammateIdle` | Agent team teammate about to idle | — | Yes |
| `TaskCompleted` | Task marked complete | — | Yes |

#### Configuration

| Event | Fires When | Matcher | Can Block |
|-------|-----------|---------|:---------:|
| `ConfigChange` | Config file changed during session | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` | Yes |
| `PreCompact` | Before context compaction | `manual`, `auto` | No |
| `PostCompact` | After compaction completes | `manual`, `auto` | No |

#### Git Worktrees

| Event | Fires When | Matcher | Can Block |
|-------|-----------|---------|:---------:|
| `WorktreeCreate` | Worktree created | — | No |
| `WorktreeRemove` | Worktree removed | — | No |

#### MCP Integration

| Event | Fires When | Matcher | Can Block |
|-------|-----------|---------|:---------:|
| `Elicitation` | MCP server requests user input | MCP server name | No |
| `ElicitationResult` | User responds to MCP elicitation | MCP server name | No |

#### Notifications

| Event | Fires When | Matcher | Can Block |
|-------|-----------|---------|:---------:|
| `Notification` | Notification sent | `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` | No |

### Handler Types

#### Command

```json
{
  "type": "command",
  "command": "./scripts/validate.sh",
  "timeout": 600,
  "statusMessage": "Running validation...",
  "once": false,
  "async": false
}
```

Receives JSON on stdin. Exit codes: `0` = success (parse stdout JSON), `2` = block (stderr becomes error message), other = non-blocking error.

#### HTTP

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "headers": {"Authorization": "Bearer $MY_TOKEN"},
  "allowedEnvVars": ["MY_TOKEN"],
  "timeout": 30
}
```

POST with JSON body. Reads decisions from response body.

#### Prompt

```json
{
  "type": "prompt",
  "prompt": "Should this be allowed? $ARGUMENTS",
  "model": "fast",
  "timeout": 30
}
```

Single-turn LLM evaluation. Returns `{"ok": true/false, "reason": "..."}`.

#### Agent

```json
{
  "type": "agent",
  "prompt": "Verify this meets requirements: $ARGUMENTS",
  "timeout": 60
}
```

Spawns subagent with tool access for complex verification.

### Common Input Fields (all hooks receive)

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/working/directory",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "agent_id": "optional",
  "agent_type": "optional"
}
```

### Environment Variables Available in Hooks

| Variable | Description | Availability |
|----------|-------------|-------------|
| `$CLAUDE_PROJECT_DIR` | Project root | All hooks |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin installation directory | Plugin hooks |
| `${CLAUDE_PLUGIN_DATA}` | Plugin persistent data directory | Plugin hooks |
| `$CLAUDE_ENV_FILE` | File to persist env vars | SessionStart only |
| `$CLAUDE_CODE_REMOTE` | `"true"` in remote environments | All hooks |

### Scope Precedence

Hooks from all scopes are merged. Precedence for same event:
1. Managed settings
2. Plugin hooks (if allowed)
3. User settings
4. Project settings
5. Local settings
6. Agent/skill frontmatter (scoped to that agent/skill only)

---

## MCP Servers

MCP server configuration lives in `~/.claude.json` (user/local scope) and `.mcp.json` (project scope), **not** in `settings.json`. Control over which servers are allowed is in `settings.json`.

### Configuration Locations

| Scope | File | Shared |
|-------|------|:------:|
| User | `~/.claude.json` (global mcpServers) | No |
| Local | `~/.claude.json` (per-project) | No |
| Project | `.mcp.json` (repo root) | Yes |
| Managed | `/etc/claude-code/managed-mcp.json` | Yes |

Precedence: Local > Project > User. Managed takes exclusive control when present.

### Transport Types

#### stdio

```json
{
  "type": "stdio",
  "command": "/path/to/executable",
  "args": ["--arg1", "value"],
  "env": {"VAR_NAME": "value"},
  "cwd": "/working/directory"
}
```

#### http

```json
{
  "type": "http",
  "url": "https://api.example.com/mcp",
  "headers": {"Authorization": "Bearer ${TOKEN}"}
}
```

#### sse (deprecated — use http)

```json
{
  "type": "sse",
  "url": "https://api.example.com/sse"
}
```

#### ws (WebSocket)

```json
{
  "type": "ws",
  "url": "ws://api.example.com/mcp"
}
```

### Environment Variable Expansion

- `${VAR}` or `$VAR` — expands to env var value
- `${VAR:-default}` — fallback if unset
- Supported in: command args, env, url, headers

### OAuth

```json
{
  "mcpServers": {
    "my-server": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "oauth": {
        "clientId": "your-client-id",
        "callbackPort": 8080,
        "authServerMetadataUrl": "https://auth.example.com/.well-known/openid-configuration"
      }
    }
  }
}
```

---

## projects/

Per-project state. Project ID derived from git repo root (all worktrees share one). Gitignored — machine-local.

```
projects/<project-id>/
├── memory/                          # Auto memory
│   ├── MEMORY.md                    # Index (first 200 lines loaded per session)
│   └── <topic>.md                   # Topic-specific memory files
├── agent-memory/                    # Per-agent persistent memory (user scope)
│   └── <agent-name>/
│       └── MEMORY.md
├── agent-memory-local/              # Per-agent local-only memory
│   └── <agent-name>/
│       └── MEMORY.md
└── <session-id>.jsonl               # Session transcripts (JSON Lines)
```

### Auto Memory

- First 200 lines of `MEMORY.md` loaded at session start
- Claude reads/writes memory files throughout the session
- Machine-local, not shared across machines
- Customizable location via `autoMemoryDirectory` setting
- Disable with `autoMemoryEnabled: false` or `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`

### Session Cleanup

Controlled by `cleanupPeriodDays` (default: 30). Sessions inactive longer than N days deleted at startup. Set to `0` to disable persistence entirely.

---

## backups/

Auto-created when configuration files are modified. Retains the 5 most recent timestamped backups.

Naming: `<filename>.<timestamp>.bak`

Files backed up: `settings.json`, `.claude.json`, `.mcp.json`, `keybindings.json`.

---

## Sources

- Settings: https://code.claude.com/docs/en/settings
- Permissions: https://code.claude.com/docs/en/permissions
- Sandboxing: https://code.claude.com/docs/en/sandboxing
- Memory: https://code.claude.com/docs/en/memory
- Hooks: https://code.claude.com/docs/en/hooks
- Skills: https://code.claude.com/docs/en/skills
- Subagents: https://code.claude.com/docs/en/sub-agents
- MCP: https://code.claude.com/docs/en/mcp
- Keybindings: https://code.claude.com/docs/en/keybindings
- Plugins: https://code.claude.com/docs/en/plugins-reference