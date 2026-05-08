#!/usr/bin/env bash
# Usage: bash install.sh [kit] [target_dir]
#   kit:        java (default) | base | all
#   target_dir: defaults to current directory

KIT="${1:-java}"
TARGET="${2:-.}"

REPO="https://github.com/dabaicai123/developer-kit.git"
TMP=$(mktemp -d)

git clone --depth 1 "$REPO" "$TMP"

install_kit() {
  local src="$TMP/kits/$1"
  mkdir -p "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/.claude/commands" "$TARGET/.claude/rules"
  [ -d "$src/skills" ]   && cp -rf "$src/skills/"*   "$TARGET/.claude/skills/"
  [ -d "$src/agents" ]   && cp -f  "$src/agents/"*.md  "$TARGET/.claude/agents/"
  [ -d "$src/commands" ] && cp -f  "$src/commands/"*.md "$TARGET/.claude/commands/"
  [ -d "$src/rules" ]    && cp -f  "$src/rules/"*.md    "$TARGET/.claude/rules/"
  echo "Installed $1 -> $TARGET/.claude/"
}

case "$KIT" in
  all)  install_kit java; install_kit base ;;
  *)    install_kit "$KIT" ;;
esac

rm -rf "$TMP"
