#!/usr/bin/env bash
# QUICK training run (<90s): tiny population + few generations. Use this to smoke-
# test the pipeline after game/physics changes and get a rough champion fast.
# For a real run: `python3 train.py` (full GENS/reps/seeds defaults).
#
# Any knob can still be overridden, e.g.:  GENS=8 .ga/quick.sh
set -e
cd "$(dirname "$0")"
GENS="${GENS:-5}" \
DIFF_STAGES="${DIFF_STAGES:-2}" \
LAMBDA="${LAMBDA:-8}" \
MU="${MU:-4}" \
DOT_REPS="${DOT_REPS:-2}" \
SUCC_REPS="${SUCC_REPS:-2}" \
DOT_SEEDS="${DOT_SEEDS:-1}" \
SUCC_SEEDS="${SUCC_SEEDS:-1,2}" \
DOT_FRAMES="${DOT_FRAMES:-160}" \
VAL_REPS="${VAL_REPS:-6}" \
VAL_SEEDS="${VAL_SEEDS:-1,2}" \
TRAIN_JITTER="${TRAIN_JITTER:-1.3}" \
python3 train.py "$@"
