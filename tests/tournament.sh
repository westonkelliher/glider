#!/usr/bin/env bash
# Round-robin AI-vs-AI tournament for the glider-soccer match harness.
#
# Auto-discovers variants from scripts/ai_variants/ai_*.gd (always includes
# `base`), runs every ORDERED pair (A != B) for each seed, and writes results
# to tests/results.csv (overwritten fresh each run).
#
# Config via env vars OR positional args (positional overrides env):
#   SEEDS  (arg 1)  default "1 2 3"   space-separated seed list
#   FRAMES (arg 2)  default 18000
#   GOALS  (arg 3)  default 20
#
# Examples:
#   bash tests/tournament.sh
#   SEEDS="1 2 3 4 5" bash tests/tournament.sh
#   bash tests/tournament.sh "1 2" 12000 12
set -euo pipefail

# --- resolve project root (worktree root = parent of this script's dir) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- config: positional args override env vars override defaults ---
SEEDS="${1:-${SEEDS:-1 2 3}}"
FRAMES="${2:-${FRAMES:-18000}}"
GOALS="${3:-${GOALS:-20}}"

GODOT="${GODOT:-godot}"
CSV="$ROOT/tests/results.csv"
HEADER="seed,blue_variant,orange_variant,blue_goals,orange_goals,frames,blue_third,orange_third,blue_press,orange_press,sum_z"

# --- discover variants (always include base) ---
VARIANTS=()
for f in "$ROOT"/scripts/ai_variants/ai_*.gd; do
  [ -e "$f" ] || continue
  name="$(basename "$f")"
  name="${name#ai_}"
  name="${name%.gd}"
  VARIANTS+=("$name")
done
# ensure base present
case " ${VARIANTS[*]} " in
  *" base "*) ;;
  *) VARIANTS+=("base") ;;
esac
# de-dup, sort
mapfile -t VARIANTS < <(printf '%s\n' "${VARIANTS[@]}" | sort -u)

echo "[tournament] variants: ${VARIANTS[*]}" >&2
echo "[tournament] seeds: $SEEDS  frames: $FRAMES  goals: $GOALS" >&2

# --- count ordered pairs * seeds for progress ---
read -r -a SEED_ARR <<< "$SEEDS"
n_var=${#VARIANTS[@]}
n_pairs=$(( n_var * (n_var - 1) ))
total=$(( n_pairs * ${#SEED_ARR[@]} ))
if [ "$total" -eq 0 ]; then
  echo "[tournament] WARNING: no ordered pairs (need >=2 variants). Nothing to run." >&2
fi

# --- fresh CSV with header ---
echo "$HEADER" > "$CSV"

n=0
for A in "${VARIANTS[@]}"; do
  for B in "${VARIANTS[@]}"; do
    [ "$A" = "$B" ] && continue
    for S in "${SEED_ARR[@]}"; do
      n=$(( n + 1 ))
      echo "[tournament] running $A vs $B seed $S [$n/$total]" >&2
      out="$(timeout 90 "$GODOT" --headless --path "$ROOT" --fixed-fps 60 \
        res://tests/match.tscn -- \
        "blue=$A" "orange=$B" "seed=$S" "frames=$FRAMES" "goals=$GOALS" 2>/dev/null || true)"

      line="$(printf '%s\n' "$out" | grep -m1 '\[match\] TALLY' || true)"
      if [ -z "$line" ]; then
        echo "[tournament] WARNING: no TALLY for $A vs $B seed $S (crash/timeout); skipping" >&2
        continue
      fi

      # Parse key=value tokens from the TALLY line.
      bg=""; og=""; fr=""; bt=""; ot=""; bp=""; op=""; sz=""
      for tok in $line; do
        case "$tok" in
          blue=*)        bg="${tok#blue=}" ;;
          orange=*)      og="${tok#orange=}" ;;
          frames=*)      fr="${tok#frames=}" ;;
          blue_third=*)  bt="${tok#blue_third=}" ;;
          orange_third=*) ot="${tok#orange_third=}" ;;
          blue_press=*)  bp="${tok#blue_press=}" ;;
          orange_press=*) op="${tok#orange_press=}" ;;
          sum_z=*)       sz="${tok#sum_z=}" ;;
        esac
      done

      if [ -z "$bg" ] || [ -z "$og" ] || [ -z "$fr" ]; then
        echo "[tournament] WARNING: malformed TALLY for $A vs $B seed $S; skipping" >&2
        continue
      fi

      echo "$S,$A,$B,$bg,$og,$fr,$bt,$ot,$bp,$op,$sz" >> "$CSV"
    done
  done
done

echo "[tournament] done -> $CSV" >&2
