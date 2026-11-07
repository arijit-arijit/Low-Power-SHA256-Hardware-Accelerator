#!/usr/bin/env bash
# Copies the small per-run reports from an OpenLane runs directory into physical_design/reports/<run>/.
# usage: collect_reports.sh <runs_dir> <run_name>
set -euo pipefail
RUNS="$1"; RUN="$2"; ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/physical_design/reports/$RUN"; mkdir -p "$D"
cp "$RUNS/$RUN/final/metrics.csv" "$RUNS/$RUN/final/metrics.json" "$D/"
find "$RUNS/$RUN" -name 'lvs.netgen.rpt' -o -name 'manufacturability.rpt' -o -name 'irdrop.rpt' | xargs -r -I{} cp {} "$D/"
echo "collected into $D"
