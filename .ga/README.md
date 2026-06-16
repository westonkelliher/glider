# ai_brain — evolutionary training

`ai_brain` (`scripts/ai_variants/ai_brain.gd`) is a glider AI = a hand-coded
**deterministic baseline policy** + a small **MLP residual** on top. The MLP
weights are trained by an evolution strategy (μ=10 → λ=20). Zero weights ⇒ pure
baseline (the trainer's floor).

## Architecture / genome contract (MUST stay in sync with ai_brain.gd)
- Net: **IN 34 → hidden 12 (tanh) → OUT 13 (linear)**. Outputs are residuals:
  0–6 = decision residuals (added to det decisions, clamped, fed to the aim
  blend); 7–12 = control residuals for pitch,roll,yaw,boost,slow,brake.
- Genome = **flat 589 floats** → JSON `{"W1":408,"b1":12,"W2":156,"b2":13}`
  (row-major; W1 idx `h*34+i`, W2 idx `o*12+h`). Missing/wrong-length ⇒ zeros.
- Brain loads weights from env `BRAIN_WEIGHTS=<json>`, else falls back to
  `scripts/ai_variants/ai_brain_weights.json` (the **F5 default**).

## Files
- `evolve.py` — GA core: genome↔JSON, batched eval, `evolve_phase()`. Also a
  solo debug entry: `SET=train REWARD=success GENS=30 python3 .ga/evolve.py`.
- `train.py` — the real **two-phase curriculum** (below). Run this.
- `../tests/ga_batch.gd` — batched evaluator: one long-lived process scores a
  whole manifest of genomes (`apply_weights` per candidate). Modes:
  `reward=success` (binary) | `reward=dot` (continuous: ball-vel · dir(goal−ball)
  at end of `dot_frames`). Kinds: `shot`/`keep`/`position`.
- `../tests/scenarios.gd` — shared scenario defs (`scenario_set(which)`):
  `basics` (12, dot-reward, phase 1), `train` (16, binary, selection),
  `test` (14, held-out, overfitting check). Also the standalone tuning harness.

## Train
```bash
cd <project root>
P1_GENS=15 P2_GENS=30 LAMBDA=20 MU=10 P1_REPS=4 P2_REPS=8 \
P1_SEEDS=1,2 P2_SEEDS=1,2,3 DOT_FRAMES=240 SIGMA=0.06 P2_SIGMA=0.04 \
VAL_REPS=40 VAL_SEEDS=1,2,3 python3 .ga/train.py 2>&1 | tee .ga/run.log
```
Phase 1 = `basics`+dot (flight control); Phase 2 = `train`+success, **carrying
phase-1's population forward**. At the end it validates on `test` and
**auto-promotes** `champion.json` → `ai_brain_weights.json` (so F5 uses it).

## Evaluate any genome (e.g. compare champion vs baseline)
```bash
printf '%s\n%s\n' "$PWD/.ga/champion.json" "$PWD/.ga/tmp/zero.json" > /tmp/m.txt  # zero.json = {}
godot --headless --path . --fixed-fps 60 res://tests/ga_batch.tscn -- \
  manifest=/tmp/m.txt set=test reps=10 seeds=1,2,3 reward=success   # prints idx= success=
```
Max success = `10 * |set| * |seeds|`. Baseline floor ≈ 0.58 train / 0.46 test.

## Scenario-design principles (when editing the sets)
Span a WIDE situation space (ball anywhere/any velocity incl. drifting the wrong
way; glider in any pose). Tune difficulty by **slowing** (lower speed / longer
budget), NOT by re-angling into a near-duplicate. A few near-0% scenarios are
fine. Keep `train` and `test` geometrically distinct.

## Caveats
- Pre-existing log spam: `SCRIPT ERROR … GliderControls.braked / Nil targets`
  reproduces on untouched variants (e.g. `hbgs`) — not from the brain. Harmless
  to eval, but worth fixing (a controller returning null `GliderControls`).
- F5 opponent is set in `scenes/main.tscn` (`AIGlider.ai_variant = "brain"`).
