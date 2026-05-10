#!/usr/bin/env python3
"""Generate INDEX.md and GRAPH.md from thread frontmatter.

Usage: python3 generate.py <threads-dir>

Reads all .md files in <threads-dir> (excluding INDEX.md, GRAPH.md, ROADMAP.md),
parses YAML frontmatter, and generates derived artifacts. Compare-before-write
prevents unnecessary file changes.

Decisions: D17-D32, D35 in project-management-design thread.
"""

import os
import sys
from datetime import datetime, timezone

try:
    import yaml
except ImportError:
    print(
        "ERROR: PyYAML is required. Install with: pip install --user pyyaml",
        file=sys.stderr,
    )
    sys.exit(1)

SKIP_FILES = {"INDEX.md", "GRAPH.md", "ROADMAP.md"}
REQUIRED_FIELDS = {"status", "summary", "description", "last_updated"}
STATUS_ORDER = ["active", "blocked", "parked", "closed"]
PRIORITY_RANK = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
# Top-level free-text fields that commonly contain colons (from skill-generated
# summaries like "Option A: extend ..."). YAML chokes on unquoted `: ` in values,
# so we quote these before parsing.
QUOTE_FIELDS = ("summary", "description")


def quote_frontmatter_fields(text):
    """Quote top-level free-text values that may contain bare colons."""
    lines = text.split("\n")
    result = []
    for line in lines:
        for field in QUOTE_FIELDS:
            prefix = f"{field}: "
            if line.startswith(prefix) and not line.startswith(f'{field}: "'):
                value = line[len(prefix):]
                value = value.replace("\\", "\\\\").replace('"', '\\"')
                line = f'{field}: "{value}"'
                break
        result.append(line)
    return "\n".join(result)


def parse_frontmatter(filepath):
    """Parse YAML frontmatter from a markdown file (D28)."""
    with open(filepath, "r") as f:
        content = f.read()
    if not content.startswith("---"):
        return None
    parts = content.split("---", 2)
    if len(parts) < 3:
        return None
    raw_yaml = quote_frontmatter_fields(parts[1])
    return yaml.safe_load(raw_yaml)


def validate_frontmatter(filename, fm):
    """Validate required fields exist (D19, D29)."""
    missing = REQUIRED_FIELDS - set(fm.keys())
    if missing:
        print(
            f"ERROR: {filename}: missing required fields: {', '.join(sorted(missing))}",
            file=sys.stderr,
        )
        sys.exit(1)


def truncate_to_date(last_updated):
    """Truncate last_updated to date for display (D27)."""
    return str(last_updated)[:10]


def sort_key(thread):
    """Sort by priority (P0 first), then alphabetically by name."""
    priority = thread["fm"].get("priority", "P2")
    return (PRIORITY_RANK.get(priority, 2), thread["name"])


def load_threads(threads_dir):
    """Load and parse all thread files."""
    threads = []
    for filename in sorted(os.listdir(threads_dir)):
        if not filename.endswith(".md") or filename in SKIP_FILES:
            continue
        filepath = os.path.join(threads_dir, filename)
        if not os.path.isfile(filepath):
            continue
        fm = parse_frontmatter(filepath)
        if fm is None:
            continue
        validate_frontmatter(filename, fm)
        threads.append({"name": filename[:-3], "filename": filename, "fm": fm})
    return threads


# ---------------------------------------------------------------------------
# INDEX.md generation
# ---------------------------------------------------------------------------

def generate_index(threads):
    """Generate INDEX.md body (without timestamp line)."""
    lines = ["# Conversation Threads"]
    grouped = {}
    for t in threads:
        grouped.setdefault(t["fm"]["status"], []).append(t)

    for status in STATUS_ORDER:
        group = grouped.get(status, [])
        if not group:
            continue
        group.sort(key=sort_key)
        lines += [
            "",
            f"## {status.capitalize()}",
            "",
            "| Thread | Priority | Description | Status | Updated |",
            "|--------|----------|-------------|--------|---------|",
        ]
        for t in group:
            fm = t["fm"]
            priority = fm.get("priority", "P2")
            updated = truncate_to_date(fm["last_updated"])
            desc = fm["description"].replace("|", "\\|")
            summary = fm["summary"].replace("|", "\\|")
            lines.append(
                f"| [{t['name']}]({t['filename']}) "
                f"| {priority} "
                f"| {desc} "
                f"| {status} — {summary} "
                f"| {updated} |"
            )
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# GRAPH.md generation
# ---------------------------------------------------------------------------

def name_to_id(name):
    """Convert thread name to Mermaid node ID."""
    return name.replace("-", "_")


def collect_edges(non_closed):
    """Collect and deduplicate all relationship edges.

    Dedup rules: emit parent/child from parent (child: entry), blocks from
    blocks side, supersedes from supersedes side, related when source < target.
    """
    non_closed_names = {t["name"] for t in non_closed}
    parent_child = set()
    blocks = set()
    supersedes = set()
    related = set()

    for t in non_closed:
        name = t["name"]
        for rel in t["fm"].get("related") or []:
            if not isinstance(rel, dict):
                continue
            for rel_type, target in rel.items():
                if target not in non_closed_names:
                    continue
                src = name_to_id(name)
                tgt = name_to_id(target)
                if rel_type == "child":
                    parent_child.add((src, tgt))
                elif rel_type == "blocks":
                    blocks.add((src, tgt))
                elif rel_type == "supersedes":
                    supersedes.add((src, tgt))
                elif rel_type == "related" and name < target:
                    related.add((src, tgt))
                # parent, blocked-by, superseded-by emitted from other side

    return sorted(parent_child), sorted(blocks), sorted(supersedes), sorted(related)


def collect_item_deps(threads):
    """Collect cross-thread item blocking pairs among non-closed threads."""
    item_to_thread = {}
    pairs = []
    closed = {t["name"] for t in threads if t["fm"]["status"] == "closed"}

    for t in threads:
        if t["fm"]["status"] == "closed":
            continue
        for item in t["fm"].get("items") or []:
            iid = item.get("id", "")
            if iid:
                item_to_thread[iid] = t["name"]
            blocked_by = item.get("blocked_by")
            if blocked_by and iid:
                pairs.append((blocked_by, iid))

    valid = []
    involved = set()
    for blocker, blocked in pairs:
        bt = item_to_thread.get(blocker)
        dt = item_to_thread.get(blocked)
        if bt and dt and bt not in closed and dt not in closed:
            valid.append((blocker, blocked))
            involved.update((blocker, blocked))

    return valid, involved, item_to_thread


def generate_graph(threads):
    """Generate GRAPH.md body (without timestamp line)."""
    non_closed = sorted(
        [t for t in threads if t["fm"]["status"] != "closed"],
        key=lambda t: t["name"],
    )

    lines = ["# Dependency Graph", "", "## Thread Relationships", "", "```mermaid", "graph TD"]

    # Nodes
    for t in non_closed:
        nid = name_to_id(t["name"])
        lines.append(f'  {nid}["{t["name"]}"]:::{t["fm"]["status"]}')

    # Edges
    parent_child, blocks_edges, supersedes_edges, related_edges = collect_edges(non_closed)

    if parent_child:
        lines += ["", "  %% parent/child (emit from parent)"]
        for src, tgt in sorted(parent_child):
            lines.append(f"  {src} -->|child| {tgt}")

    if blocks_edges:
        lines += ["", "  %% blocks (emit from blocks side)"]
        for src, tgt in sorted(blocks_edges):
            lines.append(f"  {src} -->|blocks| {tgt}")

    if supersedes_edges:
        lines += ["", "  %% supersedes (emit from supersedes side)"]
        for src, tgt in sorted(supersedes_edges):
            lines.append(f"  {src} -->|supersedes| {tgt}")

    if related_edges:
        lines += ["", "  %% related (emit when source < target alphabetically)"]
        for src, tgt in sorted(related_edges):
            lines.append(f"  {src} -.- {tgt}")

    lines += [
        "",
        "  classDef active fill:#4ade80,stroke:#166534",
        "  classDef blocked fill:#f87171,stroke:#991b1b",
        "  classDef parked fill:#fbbf24,stroke:#92400e",
        "```",
    ]

    # Item dependencies
    valid_pairs, involved, item_to_thread = collect_item_deps(threads)
    if valid_pairs:
        lines += ["", "## Item Dependencies", "", "```mermaid", "graph TD"]
        for iid in sorted(involved):
            node = iid.replace("-", "_")
            thread = item_to_thread.get(iid, "unknown")
            lines.append(f'  {node}["{iid} ({thread})"]')
        lines.append("")
        for blocker, blocked in sorted(valid_pairs):
            lines.append(f"  {blocker.replace('-', '_')} -->|blocks| {blocked.replace('-', '_')}")
        lines.append("```")

    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Compare-before-write (D17)
# ---------------------------------------------------------------------------

def strip_timestamp(content):
    """Strip leading <!-- generated: ... --> line if present."""
    if content.startswith("<!-- generated:"):
        nl = content.find("\n")
        return content[nl + 1:] if nl >= 0 else ""
    return content


def compare_and_write(filepath, body, timestamp):
    """Write only if substantive content changed (D17). Timestamp updates only on real changes."""
    full = f"<!-- generated: {timestamp} -->\n{body}"
    if os.path.exists(filepath):
        with open(filepath, "r") as f:
            existing = f.read()
        if strip_timestamp(existing) == body:
            return False
    with open(filepath, "w") as f:
        f.write(full)
    return True


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <threads-dir>", file=sys.stderr)
        sys.exit(1)

    threads_dir = sys.argv[1]
    if not os.path.isdir(threads_dir):
        print(f"ERROR: {threads_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    threads = load_threads(threads_dir)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    index_body = generate_index(threads)
    graph_body = generate_graph(threads)

    index_path = os.path.join(threads_dir, "INDEX.md")
    graph_path = os.path.join(threads_dir, "GRAPH.md")

    idx = compare_and_write(index_path, index_body, timestamp)
    grp = compare_and_write(graph_path, graph_body, timestamp)

    if idx:
        print(f"Updated {index_path}")
    if grp:
        print(f"Updated {graph_path}")
    if not idx and not grp:
        print("No changes needed")


if __name__ == "__main__":
    main()