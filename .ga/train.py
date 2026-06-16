#!/usr/bin/env python3
"""Curriculum + alternating-metric trainer for the ai_brain glider AI.

Two ideas stack on top of the (mu+lambda) evolution:

  1. ALTERNATING METRIC — each generation flips between the continuous dot-reward
     (flight + knocking the ball goalward) and the binary success reward
     (real shots/keeps/positions). Both scenario types live in BOTH the train and
     test sets (tagged per-scenario); the harness filters by the run's metric.

  2. DIFFICULTY CURRICULUM — the run is split into DIFF_STAGES equal blocks of
     generations; difficulty ramps 0 -> 1 across them. EASY (0) = slow ball +
     generous time on the SAME diverse scenarios; HARD (1) = full speed. Tuning
     difficulty by SLOWING (not re-angling) keeps the situation space just as wide
     at every stage, so the policy learns control first, then speed.

Elites are re-scored every generation under that gen's metric+difficulty, so
selection never mixes the (incomparable) scales. After evolution the champion is
re-picked from the final survivors by a FULL-difficulty success eval, validated
on the held-out test set (vs the zero-net baseline), and the run is appended to
.ga/results.csv for cross-experiment comparison. The champion is promoted to the
brain's F5 default weights.

Config via env vars (defaults in brackets):
  GENS [40]                          total generations (alternating)
  DIFF_STAGES [4]                    curriculum blocks (1 = no curriculum)
  LAMBDA [24]   MU [12]              (mu+lambda) population sizes
  DOT_REPS [6]  SUCC_REPS [10]       reps per scenario, per metric
  DOT_SEEDS [1,2,3]  SUCC_SEEDS [1,2,3,4,5]   selection seeds (more => less overfit)
  TRAIN_JITTER [1.3]                 per-rep scatter multiplier during training
  DOT_FRAMES [240]                   fixed time budget for the dot reward
  SIGMA [0.06]  SIGMA_FLOOR [0.02]   gaussian mutation sigma + decay floor
  START_METRIC [dot]                 metric on gen 0 ("dot" or "success")
  SEED_FROM []                       optional champion JSON to warm-start from
  PYSEED [42]                        python RNG seed
  VAL_REPS [50] VAL_SEEDS [1,2,3,4,5]   final validation budget (full difficulty)
"""
import os, csv, json, shutil, random, datetime
import evolve as E

PLAY_WEIGHTS = os.path.join(E.ROOT, "scripts", "ai_variants", "ai_brain_weights.json")
RESULTS_CSV = os.path.join(E.ROOT, ".ga", "results.csv")


def _ints(name, default):
    return tuple(int(s) for s in os.environ.get(name, default).split(","))


def _load_genome(path):
    """Load a champion JSON ({W1,b1,W2,b2}) back into a flat genome, or None."""
    try:
        d = json.load(open(path))
    except Exception:
        return None
    g = []
    for key, n in (("W1", E.W1_N), ("b1", E.B1_N), ("W2", E.W2_N), ("b2", E.B2_N)):
        arr = d.get(key, [])
        if not isinstance(arr, list) or len(arr) != n:
            arr = [0.0] * n
        g.extend(float(x) for x in arr)
    return g if len(g) == E.N else None


def _minmax(xs):
    """Normalize a list to [0,1] across its own range; flat list -> all 0.5."""
    lo, hi = min(xs), max(xs)
    rng = hi - lo
    return [0.5 if rng == 0 else (x - lo) / rng for x in xs]


def _pick_champion(finalists, val_reps, val_seeds, dot_frames, dot_weight):
    """Pick the survivor that best balances SUCCESS and DOT at full difficulty.
    The two scales are incomparable, so min-max each across the survivor pool and
    take a weighted blend. dot_weight=0 reproduces the old success-only pick."""
    s = E.eval_pop(finalists, "train", val_reps, val_seeds, "success", dot_frames, tag="fin_s")
    d = E.eval_pop(finalists, "train", val_reps, val_seeds, "dot", dot_frames, tag="fin_d")
    ns, nd = _minmax(s), _minmax(d)
    blend = [(1.0 - dot_weight) * a + dot_weight * b for a, b in zip(ns, nd)]
    i = max(range(len(finalists)), key=lambda k: blend[k])
    print("[ga] champion pick: success=%.0f dot=%.0f (blend=%.2f, dot_w=%.2f, of %d survivors)"
          % (s[i], d[i], blend[i], dot_weight, len(finalists)), flush=True)
    return finalists[i]


def _log_result(row):
    new = not os.path.exists(RESULTS_CSV)
    with open(RESULTS_CSV, "a", newline="") as fh:
        w = csv.writer(fh)
        if new:
            w.writerow(["time", "gens", "stages", "lambda", "mu", "succ_seeds",
                        "jitter", "base_tr", "base_te", "champ_tr", "champ_te",
                        "gap", "champ_dot_tr", "champ_dot_te"])
        w.writerow(row)


def main():
    random.seed(int(os.environ.get("PYSEED", "42")))
    gens = int(os.environ.get("GENS", "40"))
    n_stages = int(os.environ.get("DIFF_STAGES", "4"))
    lam = int(os.environ.get("LAMBDA", "24"))
    mu = int(os.environ.get("MU", "12"))
    dot_frames = int(os.environ.get("DOT_FRAMES", "240"))
    sigma = float(os.environ.get("SIGMA", "0.06"))
    sigma_floor = float(os.environ.get("SIGMA_FLOOR", "0.02"))
    start_metric = os.environ.get("START_METRIC", "dot")
    train_jitter = float(os.environ.get("TRAIN_JITTER", "1.3"))

    dot_reps = int(os.environ.get("DOT_REPS", "6"))
    succ_reps = int(os.environ.get("SUCC_REPS", "10"))
    dot_seeds = _ints("DOT_SEEDS", "1,2,3")
    succ_seeds = _ints("SUCC_SEEDS", "1,2,3,4,5")

    val_reps = int(os.environ.get("VAL_REPS", "50"))
    val_seeds = _ints("VAL_SEEDS", "1,2,3,4,5")
    dot_weight = float(os.environ.get("DOT_WEIGHT", "0.4"))   # 0=success-only champ pick

    zero = [0.0] * E.N
    seed_from = os.environ.get("SEED_FROM", "")
    seed_pop = [zero]
    if seed_from:
        g = _load_genome(seed_from)
        if g:
            seed_pop = [g, zero]   # warm-start, keep zero as a hedge
            print("[ga] warm-start from %s (+zero hedge)" % seed_from, flush=True)
        else:
            print("[ga] WARN: could not load SEED_FROM=%s; starting from zero" % seed_from)

    # ---- Baselines: zero net at FULL difficulty (the honest floor) -----------
    b_tr = E.eval_pop([zero], "train", val_reps, val_seeds, "success", dot_frames, tag="b_tr")[0]
    b_te = E.eval_pop([zero], "test", val_reps, val_seeds, "success", dot_frames, tag="b_te")[0]
    print("[ga] baseline (zero) FULL-diff success: train=%.0f  test=%.0f" % (b_tr, b_te), flush=True)

    # ---- Curriculum + alternating evolution ---------------------------------
    parents = E.evolve_alternating(
        seed_pop, gens, "train", dot_frames, lam, mu, sigma,
        dot_reps, dot_seeds, succ_reps, succ_seeds,
        sigma_floor=sigma_floor, start_metric=start_metric, label="alt",
        n_stages=n_stages, jitter=train_jitter)

    # ---- Pick champion: survivor that best blends SUCCESS + DOT (full diff) ---
    finalists = [g for _, g in parents]
    champ = _pick_champion(finalists, val_reps, val_seeds, dot_frames, dot_weight)
    E._save_champion(champ)
    shutil.copyfile(os.path.join(E.ROOT, ".ga", "champion.json"), PLAY_WEIGHTS)
    print("[ga] promoted champion -> %s (F5 now uses it)" % PLAY_WEIGHTS, flush=True)

    # ---- Final held-out validation (both metrics, full difficulty) ----------
    print("\n[ga] === FINAL CHAMPION validation (reps=%d seeds=%s) ==="
          % (val_reps, str(val_seeds)), flush=True)
    tr_s = E.eval_pop([champ], "train", val_reps, val_seeds, "success", dot_frames, tag="vtrs")[0]
    te_s = E.eval_pop([champ], "test", val_reps, val_seeds, "success", dot_frames, tag="vtes")[0]
    tr_d = E.eval_pop([champ], "train", val_reps, val_seeds, "dot", dot_frames, tag="vtrd")[0]
    te_d = E.eval_pop([champ], "test", val_reps, val_seeds, "dot", dot_frames, tag="vted")[0]
    print("[ga] SUCCESS  baseline(tr=%.0f te=%.0f) -> champion(tr=%.0f te=%.0f)"
          % (b_tr, b_te, tr_s, te_s))
    print("[ga] SUCCESS  champion gain: train +%.0f  test +%.0f   (overfit gap=%.0f)"
          % (tr_s - b_tr, te_s - b_te, tr_s - te_s))
    print("[ga] DOT      champion: train=%.3f  test=%.3f" % (tr_d, te_d))

    _log_result([datetime.datetime.now().strftime("%Y-%m-%d %H:%M"), gens, n_stages,
                 lam, mu, ",".join(map(str, succ_seeds)), "%.2f" % train_jitter,
                 "%.0f" % b_tr, "%.0f" % b_te, "%.0f" % tr_s, "%.0f" % te_s,
                 "%.0f" % (tr_s - te_s), "%.3f" % tr_d, "%.3f" % te_d])
    print("[ga] logged -> .ga/results.csv   champion -> .ga/champion.json")


if __name__ == "__main__":
    main()
