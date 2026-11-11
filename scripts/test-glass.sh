#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$repo_dir/build/tests"
xcrun --sdk macosx clang -fobjc-arc -framework AppKit -framework QuartzCore \
  -I "$repo_dir/Itsycal/MoCode" -I "$repo_dir/Itsycal" \
  "$repo_dir/Itsycal/Itsycal.m" \
  "$repo_dir/Itsycal/GlassButtonGroup.m" \
  "$repo_dir/Itsycal/ItsycalWindow.m" \
  "$repo_dir/Itsycal/Themer.m" \
  "$repo_dir/tests/glass-button-tests.m" \
  -o "$repo_dir/build/tests/glass-button-tests"
"$repo_dir/build/tests/glass-button-tests"
