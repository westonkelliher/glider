# How to build the composite AI (lesson learned)

**Don't graft everything onto a full FSM at once.** We tried that with `super`
(fsm spine + goalside + center + handbrake) and couldn't tell which states/
features helped — too many interacting knobs, and tuning was guesswork. The one
real win only appeared by accident (brake/slow were *fighting* the goalside arc;
gating them off during the arc moved super from 4th to 1st).

## The discipline instead: one state at a time

1. Start from the proven base striker (just COMMIT/line-up behavior).
2. Add **one** new state (or one feature hook). Nothing else.
3. Tune *that state alone* against the field with `tournament.sh` + `rank.py`
   until it's a clear, stable win (enough seeds that it beats noise).
4. Lock it in. Only then add the next state, and re-tune just the new piece +
   its interactions with the locked ones.
5. Ease into the full FSM gradually — each state earns its place by measured GD,
   not by theory.

Rule of thumb: if a change can't be isolated and measured, it isn't ready to
merge. Watch for features that conflict (e.g. brake vs. arc) — suppress one in
the other's regime rather than letting both fire.
