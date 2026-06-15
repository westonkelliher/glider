#!/usr/bin/env python3
"""Evolutionary weight search for the ai_brain glider AI (mu=10 -> lambda=20).

Genome = dense additive weights over the brain's two matrices (Tier-1 decisions
and Tier-2 controls). Fitness = total scenario successes on the TRAINING set.
The held-out TEST set is scored only on the champion (overfitting check).
"""
import json, os, re, subprocess, sys, random, concurrent.futures as cf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = "godot"
TMP = os.path.join(ROOT, ".ga", "tmp")
os.makedirs(TMP, exist_ok=True)

# ---- Feature / output schema (must mirror ai_brain.gd) --------------------
BASE = [
    "bias", "to_ball_x", "to_ball_y", "to_ball_z", "dist_n",
    "to_own_goal_x", "to_own_goal_y", "to_own_goal_z",
    "to_other_goal_x", "to_other_goal_y", "to_other_goal_z",
    "to_opp_x", "to_opp_y", "to_opp_z",
    "ball_vel_x", "ball_vel_y", "ball_vel_z", "ball_speed_n",
    "behind", "near", "align", "speed_n", "alt_n", "energy_n",
    "ball_wide", "ball_depth", "ball_closing",
]
DECISIONS = ["attack", "commit", "center", "defend", "climb", "recover", "intercept"]
DFEATS = ["d_" + d for d in DECISIONS]
TIER2_FEATS = BASE + DFEATS + ["turn_n"]
CONTROLS = ["pitch", "roll", "yaw", "boost", "slow", "brake"]

# Genes: (row_name, feature). Tier-1 rows read BASE; Tier-2 rows read TIER2_FEATS.
GENES = []
for d in DECISIONS:
    for f in BASE:
        GENES.append(("w_" + d, f))
for c in CONTROLS:
    for f in TIER2_FEATS:
        GENES.append(("w_" + c, f))
N = len(GENES)

# ---- Evaluation -----------------------------------------------------------
def to_json(genome):
    rows = {}
    for (row, feat), w in zip(GENES, genome):
        if abs(w) < 1e-6:
            continue
        rows.setdefault(row, {})[feat] = round(w, 5)
    return rows

SCN = re.compile(r"\[scn\] s=\S+ .* success=(\d+)")

def evaluate(genome, scen_set="train", reps=12, seeds=(1,), tag="g"):
    path = os.path.join(TMP, f"{tag}.json")
    with open(path, "w") as fh:
        json.dump(to_json(genome), fh)
    env = dict(os.environ, BRAIN_WEIGHTS=path)
    total = 0
    for seed in seeds:
        out = subprocess.run(
            [GODOT, "--headless", "--path", ROOT, "--fixed-fps", "60",
             "res://tests/scenarios.tscn", "--",
             "variant=brain", f"set={scen_set}", f"reps={reps}", f"seed={seed}"],
            capture_output=True, text=True, env=env, timeout=180).stdout
        total += sum(int(m) for m in SCN.findall(out))
    return total  # max = 10 * reps * len(seeds)

def eval_pop(pop, **kw):
    with cf.ThreadPoolExecutor(max_workers=WORKERS) as ex:
        futs = {ex.submit(evaluate, g, tag=f"w{i}", **kw): i for i, g in enumerate(pop)}
        res = [0] * len(pop)
        for fut in cf.as_completed(futs):
            res[futs[fut]] = fut.result()
    return res

# ---- GA operators ---------------------------------------------------------
def gauss(sigma):
    return [random.gauss(0, sigma) for _ in range(N)]

def crossover(a, b):
    return [a[i] if random.random() < 0.5 else b[i] for i in range(N)]

def mutate(g, sigma, rate=0.25):
    return [g[i] + (random.gauss(0, sigma) if random.random() < rate else 0.0)
            for i in range(N)]

# ---- Main loop ------------------------------------------------------------
WORKERS = int(os.environ.get("WORKERS", "6"))
GENS = int(os.environ.get("GENS", "30"))
LAMBDA = int(os.environ.get("LAMBDA", "20"))
MU = int(os.environ.get("MU", "10"))
REPS = int(os.environ.get("REPS", "12"))
SEEDS = tuple(int(s) for s in os.environ.get("SEEDS", "1").split(","))

def main():
    random.seed(42)
    # Small per-gene deltas: the zero genome is already a working deterministic
    # AI, so offspring must NUDGE it (and improve), not scramble all ~400 genes.
    init_sigma = float(os.environ.get("SIGMA", "0.06"))
    zero = [0.0] * N
    maxfit = 10 * REPS * len(SEEDS)
    base_fit = evaluate(zero, "train", REPS, SEEDS, tag="base")
    print(f"[ga] baseline (zero weights) = {base_fit}/{maxfit}", flush=True)
    # Gen 0: zero baseline (anchor) + (LAMBDA-1) gently-perturbed genomes.
    pop = [zero] + [gauss(init_sigma) for _ in range(LAMBDA - 1)]
    fits = eval_pop(pop, scen_set="train", reps=REPS, seeds=SEEDS)
    parents = sorted(zip(fits, pop), key=lambda x: -x[0])[:MU]
    print(f"[ga] gen 0  best={parents[0][0]}/{maxfit}  "
          f"top={[p[0] for p in parents]}", flush=True)

    sigma = init_sigma
    for gen in range(1, GENS + 1):
        pfits = [p[0] for p in parents]
        pgen = [p[1] for p in parents]
        # Breed LAMBDA offspring from the MU parents.
        kids = []
        for _ in range(LAMBDA):
            a, b = random.sample(pgen, 2)
            kids.append(mutate(crossover(a, b), sigma))
        kfits = eval_pop(kids, scen_set="train", reps=REPS, seeds=SEEDS)
        # Elitism: parents survive, compete with the new offspring.
        pool = list(zip(pfits, pgen)) + list(zip(kfits, kids))
        parents = sorted(pool, key=lambda x: -x[0])[:MU]
        sigma = max(0.02, sigma * 0.97)
        print(f"[ga] gen {gen}  best={parents[0][0]}/{maxfit}  sigma={sigma:.3f}  "
              f"top={[p[0] for p in parents]}", flush=True)
        with open(os.path.join(ROOT, ".ga", "champion.json"), "w") as fh:
            json.dump(to_json(parents[0][1]), fh, indent=1)

    champ = parents[0][1]
    print("\n[ga] === CHAMPION final validation (reps=40, seeds=1,2,3) ===", flush=True)
    tr = evaluate(champ, "train", 40, (1, 2, 3), tag="champ")
    te = evaluate(champ, "test", 40, (1, 2, 3), tag="champ")
    mx = 10 * 40 * 3
    print(f"[ga] TRAIN {tr}/{mx} = {tr/mx:.3f}")
    print(f"[ga] TEST  {te}/{mx} = {te/mx:.3f}   (gap = overfitting)")
    print(f"[ga] champion weights -> .ga/champion.json ({len(to_json(champ))} active rows)")

if __name__ == "__main__":
    main()
