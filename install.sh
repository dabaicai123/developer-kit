#!/usr/bin/env bash
# Usage: bash install.sh [kit] [target_dir] [platform]
#   kit:        java (default) | frontend | base | agent | all
#   target_dir: defaults to current directory
#   platform:   both (default) | claude | codex

set -e

KIT="${1:-java}"
TARGET="${2:-.}"
PLATFORM="${3:-both}"

if [ "$#" -eq 2 ]; then
  case "$2" in
    both|claude|codex)
      TARGET="."
      PLATFORM="$2"
      ;;
  esac
fi

case "$PLATFORM" in
  both|claude|codex) ;;
  *)
    echo "Unknown platform: $PLATFORM (expected: both | claude | codex)" >&2
    exit 1
    ;;
esac

REPO="https://github.com/dabaicai123/developer-kit.git"
TMP=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/kits" ]; then
  REPO_ROOT="$SCRIPT_DIR"
else
  TMP="$(mktemp -d)"
  if ! git clone --depth 1 "$REPO" "$TMP"; then
    rm -rf "$TMP"
    exit 1
  fi
  REPO_ROOT="$TMP"
fi

cleanup() {
  [ -n "$TMP" ] && rm -rf "$TMP"
}
trap cleanup EXIT

install_project_instructions() {
  local agents_source="$REPO_ROOT/AGENTS.md"
  local agents_target="$TARGET/AGENTS.md"
  local claude_target="$TARGET/CLAUDE.md"

  if [ -f "$agents_source" ] && [ ! -f "$agents_target" ]; then
    cp "$agents_source" "$agents_target"
    echo "Added AGENTS.md -> $agents_target"
  fi

  cat > "$claude_target" <<'EOF'
# CLAUDE.md

Project instructions live in [AGENTS.md](AGENTS.md).

Read and follow AGENTS.md before making changes in this repository.
EOF
  echo "Updated CLAUDE.md -> $claude_target"
}

install_kit_for_platform() {
  local name="$1"
  local platform="$2"
  local src="$REPO_ROOT/kits/$name"
  local installer="$REPO_ROOT/$platform/install.sh"
  local dst="$TARGET/.$platform"

  if [ ! -d "$src" ]; then
    echo "Unknown kit: $name (expected: java | frontend | base | agent | all)" >&2
    exit 1
  fi
  if [ ! -f "$installer" ]; then
    echo "Missing installer for platform: $platform" >&2
    exit 1
  fi

  bash "$installer" "$src" "$dst"
  echo "Installed $name -> $dst/"
}

install_kit() {
  local name="$1"

  case "$PLATFORM" in
    both)
      install_kit_for_platform "$name" claude
      install_kit_for_platform "$name" codex
      ;;
    claude|codex)
      install_kit_for_platform "$name" "$PLATFORM"
      ;;
  esac
}

case "$KIT" in
  all)
    install_kit java
    install_kit frontend
    install_kit base
    install_kit agent
    ;;
  *)
    install_kit "$KIT"
    ;;
esac

install_project_instructions

if [ "$PLATFORM" = "codex" ] || [ "$PLATFORM" = "both" ]; then
  echo "Codex note: restart Codex after installing so new skills and agents are discovered."
  echo "Codex note: Claude agents are converted to Codex subagents, for example devkit_java_feature."
  echo "Codex note: ensure ~/.codex/config.toml has [features] skills = true."
fi
