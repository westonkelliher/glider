#!/usr/bin/env bash
# Run the scenario harness for one or more variants and print their summaries.
# Same `seed` => identical jittered setups across variants => fair A/B.
#
# Usage:
#   bash tests/scenarios.sh                       # default set, reps=40 seed=1
#   bash tests/scenarios.sh hbgs handbrake        # specific variants
#   REPS=80 SEED=3 bash tests/scenarios.sh hbgs   # override reps/seed
#   DETAIL=1 bash tests/scenarios.sh hbgs         # also print per-scenario lines
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT:-godot}"
REPS="${REPS:-40}"
SEED="${SEED:-1}"

VARIANTS=("$@")
if [ ${#VARIANTS[@]} -eq 0 ]; then
  VARIANTS=(hbgs handbrake goalside base)
fi

for V in "${VARIANTS[@]}"; do
  out="$("$GODOT" --headless --path "$ROOT" --fixed-fps 60 res://tests/scenarios.tscn -- \
    "variant=$V" "reps=$REPS" "seed=$SEED" 2>/dev/null)"
  if [ "${DETAIL:-0}" = "1" ]; then
    printf '%s\n' "$out" | grep -E '\[scn\] s='
  fi
  printf '%s\n' "$out" | grep SUMMARY
done
