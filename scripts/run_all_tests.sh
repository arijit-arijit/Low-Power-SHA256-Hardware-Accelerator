#!/usr/bin/env bash
# Runs the RTL test suite. The original Makefile expects rtl/, tb/ and ref/ next to it, so this
# builds a throw-away workspace of links to the repository files and runs `make test` there.
# Needs: make gcc iverilog verilator
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
ln -s "$ROOT/rtl" "$W/rtl"; ln -s "$ROOT/verification/tb" "$W/tb"; ln -s "$ROOT/synthesis/scripts" "$W/synth"
mkdir "$W/ref"; cp "$ROOT/verification/reference_model/sha256_ref.c" "$W/ref/"
cp "$ROOT/verification/scripts/Makefile" "$W/Makefile"
mkdir -p "$ROOT/verification/results"
LOG="$ROOT/verification/results/make_test_$(date +%Y%m%d_%H%M%S).log"
( cd "$W" && make test ) 2>&1 | tee "$LOG"
echo "log: $LOG"
