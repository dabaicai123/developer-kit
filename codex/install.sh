#!/usr/bin/env bash
# Usage: bash codex/install.sh <path-to-kit> <project/.codex>

set -e

KIT_PATH="${1:?Kit path is required}"
TARGET_PATH="${2:?Target path is required}"

if [ ! -d "$KIT_PATH" ]; then
  echo "Kit path does not exist: $KIT_PATH" >&2
  exit 1
fi
mkdir -p "$TARGET_PATH/skills" "$TARGET_PATH/agents" "$TARGET_PATH/commands" "$TARGET_PATH/rules"

[ -d "$KIT_PATH/skills" ] && cp -rf "$KIT_PATH/skills/"* "$TARGET_PATH/skills/" 2>/dev/null || true
[ -d "$KIT_PATH/commands" ] && cp -f "$KIT_PATH/commands/"*.md "$TARGET_PATH/commands/" 2>/dev/null || true
if [ -d "$KIT_PATH/rules" ]; then
  for rule in "$KIT_PATH/rules/"*.md "$KIT_PATH/rules/"*.mdc; do
    [ -e "$rule" ] && cp -f "$rule" "$TARGET_PATH/rules/"
  done
fi

if [ -d "$KIT_PATH/agents" ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to convert Claude agent markdown into Codex agent TOML." >&2
    exit 1
  fi

  python3 - "$KIT_PATH/agents" "$TARGET_PATH/agents" <<'PY'
import json
import re
import sys
from pathlib import Path


def clean(value):
    return value.strip().strip('"').strip("'")


def parse_list(frontmatter, key):
    items = []
    in_list = False
    for line in frontmatter:
        inline = re.match(rf"^{re.escape(key)}:\s*\[(.*)\]\s*$", line)
        if inline:
            return [clean(item) for item in inline.group(1).split(",") if clean(item)]
        if re.match(rf"^{re.escape(key)}:\s*$", line):
            in_list = True
            continue
        if in_list:
            item = re.match(r"^\s*-\s*(.+)$", line)
            if item:
                items.append(clean(item.group(1)))
            elif re.match(r"^\S", line):
                in_list = False
    return items


def parse_agent(path):
    text = path.read_text(encoding="utf-8")
    match = re.match(r"\A---\n(.*?)\n---\n?(.*)\Z", text, re.S)
    if match:
        frontmatter = match.group(1).splitlines()
        body = match.group(2).rstrip()
    else:
        frontmatter = []
        body = text.rstrip()

    fields = {}
    for line in frontmatter:
        scalar = re.match(r"^([A-Za-z0-9_-]+):\s*(.+)$", line)
        if scalar:
            fields[scalar.group(1)] = clean(scalar.group(2))

    skills = parse_list(frontmatter, "skills")
    tools = parse_list(frontmatter, "tools")
    instructions = body
    if skills:
        instructions += "\n\n## Skills\n\nUse these Codex skills when relevant:\n"
        instructions += "\n".join(f"- ${skill}" for skill in skills)
    if tools:
        instructions += "\n\n## Tools\n\n"
        instructions += (
            "The original Claude tool list was: "
            + ", ".join(tools)
            + ". Treat this as guidance, not a Codex permission boundary."
        )

    name = fields.get("name") or path.stem
    description = fields.get("description") or "Migrated developer-kit agent."
    return "\n".join(
        [
            f"name = {json.dumps(name)}",
            f"description = {json.dumps(description)}",
            f"developer_instructions = {json.dumps(instructions)}",
            "",
        ]
    )


source_root = Path(sys.argv[1])
target_root = Path(sys.argv[2])
target_root.mkdir(parents=True, exist_ok=True)
for source_file in sorted(source_root.glob("*.md")):
    target_file = target_root / f"{source_file.stem}.toml"
    target_file.write_text(parse_agent(source_file), encoding="utf-8")
PY
fi
