#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 tools/validate_data.py
python3 tools/pxl_build.py assets_src assets || true
echo "Assets checked. Open project.godot in Godot 4.4+."
