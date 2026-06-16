#!/usr/bin/env bash
# MEDIUM training run (~3-6 min): a real-ish champion without the full ~40-gen
# cost. Between quick.sh (smoke test) and `python3 train.py` (full run).
#
# Override any knob inline, e.g.:  GENS=24 .ga/medium.sh
set -e
cd "$(dirname "$0")"
GENS="${GENS:-16}" \
DIFF_STAGES="${DIFF_STAGES:-3}" \
LAMBDA="${LAMBDA:-16}" \
MU="${MU:-8}" \
DOT_REPS="${DOT_REPS:-4}" \
SUCC_REPS="${SUCC_REPS:-6}" \
DOT_SEEDS="${DOT_SEEDS:-1,2}" \
SUCC_SEEDS="${SUCC_SEEDS:-1,2,3}" \
DOT_FRAMES="${DOT_FRAMES:-200}" \
VAL_REPS="${VAL_REPS:-24}" \
VAL_SEEDS="${VAL_SEEDS:-1,2,3}" \
TRAIN_JITTER="${TRAIN_JITTER:-1.3}" \
python3 train.py "$@"
