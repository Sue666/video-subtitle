#!/bin/bash
set -e

DEST="$HOME/.claude/commands"
mkdir -p "$DEST"

curl -fsSL "https://raw.githubusercontent.com/Sue666/video-subtitle/main/.claude/commands/video-subtitle.md" \
  -o "$DEST/video-subtitle.md"

echo "✅ Installed! Use /video-subtitle in Claude Code."
