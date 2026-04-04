#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=== MuxPod Icon Generation ==="

# Step 1: SVG to PNG conversion (foreground)
echo "[1/3] Generating foreground PNG..."
rsvg-convert -w 1024 -h 1024 \
  assets/icon/icon-foreground.svg \
  -o assets/icon/icon-foreground.png

# Step 2: Full icon PNG generation (with background)
echo "[2/3] Generating full icon PNG..."
rsvg-convert -w 1024 -h 1024 \
  docs/logo/logo.svg \
  -o assets/icon/icon.png

# Step 3: Run flutter_launcher_icons
echo "[3/3] Running flutter_launcher_icons..."
dart run flutter_launcher_icons

echo "=== Done ==="
