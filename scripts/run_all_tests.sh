#!/usr/bin/env bash
# Runs the RTL test suite via the project Makefile and saves the log.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/verification/results"
cd "$ROOT/verification/scripts"
make test 2>&1 | tee "$ROOT/verification/results/make_test_$(date +%Y%m%d_%H%M%S).log"
