#!/usr/bin/env bash
# Usage: bash claude/install.sh <path-to-kit> <project/.claude>

set -e

KIT_PATH="${1:?Kit path is required}"
TARGET_PATH="${2:?Target path is required}"

if [ ! -d "$KIT_PATH" ]; then
  echo "Kit path does not exist: $KIT_PATH" >&2
  exit 1
fi

mkdir -p "$TARGET_PATH/skills" "$TARGET_PATH/agents" "$TARGET_PATH/commands" "$TARGET_PATH/rules"

[ -d "$KIT_PATH/skills" ] && cp -rf "$KIT_PATH/skills/"* "$TARGET_PATH/skills/" 2>/dev/null || true
[ -d "$KIT_PATH/agents" ] && cp -f "$KIT_PATH/agents/"*.md "$TARGET_PATH/agents/" 2>/dev/null || true
[ -d "$KIT_PATH/commands" ] && cp -f "$KIT_PATH/commands/"*.md "$TARGET_PATH/commands/" 2>/dev/null || true
[ -d "$KIT_PATH/rules" ] && cp -f "$KIT_PATH/rules/"*.md "$TARGET_PATH/rules/" 2>/dev/null || true
