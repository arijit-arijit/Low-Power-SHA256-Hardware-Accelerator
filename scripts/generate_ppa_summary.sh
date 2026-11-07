#!/usr/bin/env bash
# Prints key post-route metrics for each run from OpenLane final/metrics.csv ("Metric,Value").
# usage: generate_ppa_summary.sh <run_dir> [<run_dir> ...]   (each containing final/metrics.csv)
set -euo pipefail
printf 'run,setup_ws_ns,hold_ws_ns,area_um2,antenna_nets,magic_drc,klayout_drc,lvs_errors\n'
for d in "$@"; do
  f="$d/final/metrics.csv"; [ -f "$f" ] || { echo "missing $f" >&2; continue; }
  g(){ awk -F, -v k="$1" '$1==k{print $2; exit}' "$f"; }
  printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$(basename "$d")" "$(g timing__setup__ws)" "$(g timing__hold__ws)" \
    "$(g design__instance__area__stdcell)" "$(g antenna__violating__nets)" "$(g magic__drc_error__count)" \
    "$(g klayout__drc_error__count)" "$(g design__lvs_error__count)"
done
