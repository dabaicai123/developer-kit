#!/usr/bin/env bash
# Usage: bash install.sh [kit] [target_dir] [platform]
#   kit:        java (default) | frontend | base | agent | all
#   target_dir: defaults to current directory
#   platform:   both (default) | claude | codex

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

REPO="https://github.com/dabaicai123/developer-kit.git"
TMP=$(mktemp -d)

if ! git clone --depth 1 "$REPO" "$TMP"; then
  rm -rf "$TMP"
  exit 1
fi

copy_kit_files() {
  local src="$TMP/kits/$1"
  local dst="$2"

  if [ ! -d "$src" ]; then
    echo "Unknown kit: $1 (expected: java | frontend | base | agent | all)" >&2
    rm -rf "$TMP"
    exit 1
  fi

  mkdir -p "$dst/skills" "$dst/agents" "$dst/commands" "$dst/rules"
  [ -d "$src/skills" ]   && cp -rf "$src/skills/"*    "$dst/skills/"
  [ -d "$src/agents" ]   && cp -f  "$src/agents/"*.md "$dst/agents/" 2>/dev/null || true
  [ -d "$src/commands" ] && cp -f  "$src/commands/"*.md "$dst/commands/" 2>/dev/null || true
  [ -d "$src/rules" ]    && cp -f  "$src/rules/"*.md "$dst/rules/" 2>/dev/null || true
}

install_kit_for_platform() {
  local name="$1"
  local platform="$2"

  case "$platform" in
    claude)
      copy_kit_files "$name" "$TARGET/.claude"
      echo "Installed $name -> $TARGET/.claude/"
      ;;
    codex)
      copy_kit_files "$name" "$TARGET/.codex"
      echo "Installed $name -> $TARGET/.codex/"
      ;;
    *)
      echo "Unknown platform: $platform (expected: both | claude | codex)" >&2
      rm -rf "$TMP"
      exit 1
      ;;
  esac
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
    *)
      echo "Unknown platform: $PLATFORM (expected: both | claude | codex)" >&2
      rm -rf "$TMP"
      exit 1
      ;;
  esac
}

case "$KIT" in
  all)  install_kit java; install_kit frontend; install_kit base; install_kit agent ;;
  *)    install_kit "$KIT" ;;
esac

rm -rf "$TMP"

if [ "$PLATFORM" = "codex" ] || [ "$PLATFORM" = "both" ]; then
  echo "Codex note: restart Codex after installing so new skills are discovered."
fi
