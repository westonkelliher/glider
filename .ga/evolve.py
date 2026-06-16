#!/usr/bin/env python3
"""Evolutionary weight search for the ai_brain glider AI (mu=10 -> lambda=20).

Genome = a flat list of 589 floats laid out exactly as the brain's net contract:
  W1: 408 (= IN 34 * HID 12), index = h*34 + i
  b1: 12
  W2: 156 (= HID 12 * OUT 13), index = o*12 + h
  b2: 13
to_json(genome) slices the flat list into those four named arrays and writes
{"W1":[...],"b1":[...],"W2":[...],"b2":[...]} (row-major). A zero genome is the
deterministic baseline (the brain treats missing/wrong-length arrays as zeros).

Evaluation is done by a single long-lived batch harness process per population
(tests/ga_batch.gd): it loads a manifest of genome-JSON files and re-weights one
brain per candidate, printing `[ga] idx=<i> success=<n>` (binary `success` mode)
or `[ga] idx=<i> reward=<float>` (continuous `dot` mode).

Fitness on the TRAINING set drives selection; the held-out TEST set is scored
only on the champion (overfitting check).
"""
import json, os, re, subprocess, random
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "godot")
TMP = os.path.join(ROOT, ".ga", "tmp")
os.makedirs(TMP, exist_ok=True)

# Parallelism: each godot batch process is single-threaded (~1 core), so we shard
# the population across WORKERS concurrent processes. Default: leave a couple
# cores free (and headroom for an open editor). Override with WORKERS=<n>.
WORKERS = int(os.environ.get("WORKERS", "0")) or min(16, max(1, (os.cpu_count() or 4) - 2))

# ---- Net topology (MUST mirror ai_brain.gd) -------------------------------
IN_N = 34
HID_N = 12
OUT_N = 13
W1_N = IN_N * HID_N   # 408
B1_N = HID_N          # 12
W2_N = HID_N * OUT_N  # 156
B2_N = OUT_N          # 13
N = W1_N + B1_N + W2_N + B2_N   # 589 = total genome length
assert N == 589, N

# ---- Genome <-> JSON -------------------------------------------------------
def to_json(genome):
    """Slice the flat 589-float genome into the brain's 4 named flat arrays."""
    assert len(genome) == N, "genome length %d != %d" % (len(genome), N)
    i0 = 0
    W1 = genome[i0:i0 + W1_N]; i0 += W1_N
    b1 = genome[i0:i0 + B1_N]; i0 += B1_N
    W2 = genome[i0:i0 + W2_N]; i0 += W2_N
    b2 = genome[i0:i0 + B2_N]; i0 += B2_N
    return {
        "W1": [round(w, 6) for w in W1],
        "b1": [round(w, 6) for w in b1],
        "W2": [round(w, 6) for w in W2],
        "b2": [round(w, 6) for w in b2],
    }

# ---- Batched evaluation via tests/ga_batch.gd ------------------------------
SUCC = re.compile(r"\[ga\] idx=(\d+) success=(\d+)")
RWRD = re.compile(r"\[ga\] idx=(\d+) reward=(-?[\d.]+)")


def _run_batch(chunk_paths, scen_set, reps, seedstr, reward, dot_frames, tag,
               difficulty, jitter):
    """Launch ONE godot batch process over `chunk_paths` (a list of genome-JSON
    files). Returns its stdout. The harness prints idx LOCAL to this manifest."""
    man = os.path.join(TMP, "%s_manifest.txt" % tag)
    with open(man, "w") as fh:
        fh.write("\n".join(chunk_paths) + "\n")
    args = [GODOT, "--headless", "--path", ROOT, "--fixed-fps", "60",
            "res://tests/ga_batch.tscn", "--",
            "manifest=%s" % man, "set=%s" % scen_set, "reps=%d" % reps,
            "seeds=%s" % seedstr, "reward=%s" % reward,
            "dot_frames=%d" % dot_frames,
            "difficulty=%.4f" % difficulty, "jitter=%.4f" % jitter]
    return subprocess.run(args, capture_output=True, text=True,
                          timeout=int(os.environ.get("EVAL_TIMEOUT", "1800"))).stdout


def eval_pop(pop, scen_set="train", reps=12, seeds=(1,), reward="success",
             dot_frames=240, tag="gen", difficulty=1.0, jitter=1.0):
    """Evaluate a whole population, SHARDED across WORKERS parallel godot
    processes (each ~1 core). Returns a list of floats aligned to `pop`
    (success counts, or summed dot reward)."""
    if not pop:
        return []
    # Write one genome JSON per candidate.
    paths = []
    for i, g in enumerate(pop):
        p = os.path.join(TMP, "%s_%d.json" % (tag, i))
        with open(p, "w") as fh:
            json.dump(to_json(g), fh)
        paths.append(p)

    # Round-robin the genomes into <=WORKERS shards, remembering each genome's
    # GLOBAL index so we can map the per-shard local idx back.
    seedstr = ",".join(str(s) for s in seeds)
    k = min(WORKERS, len(pop))
    shards = [[] for _ in range(k)]
    for i, p in enumerate(paths):
        shards[i % k].append((i, p))  # (global_index, path)

    pat = RWRD if reward == "dot" else SUCC
    res = [None] * len(pop)
    with ThreadPoolExecutor(max_workers=k) as ex:
        fut2shard = {}
        for si, shard in enumerate(shards):
            if not shard:
                continue
            chunk = [p for _, p in shard]
            fut = ex.submit(_run_batch, chunk, scen_set, reps, seedstr, reward,
                            dot_frames, "%s_s%d" % (tag, si), difficulty, jitter)
            fut2shard[fut] = shard
        for fut in as_completed(fut2shard):
            shard = fut2shard[fut]
            out = fut.result()
            local = [None] * len(shard)
            for m in pat.finditer(out):
                li = int(m.group(1))
                if 0 <= li < len(shard):
                    local[li] = float(m.group(2))
            for (gi, _), val in zip(shard, local):
                res[gi] = val
            if any(v is None for v in local):
                print(out)
                raise RuntimeError("batch shard did not report all %d genomes"
                                   % len(shard))
    return res


# ---- GA operators ----------------------------------------------------------
def gauss(sigma):
    return [random.gauss(0, sigma) for _ in range(N)]


def crossover(a, b):
    return [a[i] if random.random() < 0.5 else b[i] for i in range(N)]


def mutate(g, sigma, rate=0.25):
    return [g[i] + (random.gauss(0, sigma) if random.random() < rate else 0.0)
            for i in range(N)]


# ---- One evolutionary phase ------------------------------------------------
def evolve_phase(seed_pop, gens, scen_set, reward, reps, seeds, dot_frames,
                 lam, mu, init_sigma, label="phase"):
    """Run `gens` generations of (mu+lambda) evolution starting from `seed_pop`
    (a list of parent genomes — carried forward across phases). Returns the
    final sorted parent list [(fit, genome), ...] best-first."""
    sigma = init_sigma
    # Seed gen 0 population: the carried-forward parents + perturbations up to lambda.
    pop = list(seed_pop)
    while len(pop) < lam:
        base = random.choice(seed_pop) if seed_pop else [0.0] * N
        pop.append(mutate(base, init_sigma, rate=0.5))
    pop = pop[:max(lam, len(seed_pop))]
    fits = eval_pop(pop, scen_set, reps, seeds, reward, dot_frames,
                    tag="%s_g0" % label)
    parents = sorted(zip(fits, pop), key=lambda x: -x[0])[:mu]
    print("[ga] %s gen 0  best=%.3f  top=%s"
          % (label, parents[0][0], [round(p[0], 2) for p in parents]), flush=True)

    for gen in range(1, gens + 1):
        pfits = [p[0] for p in parents]
        pgen = [p[1] for p in parents]
        kids = []
        for _ in range(lam):
            a, b = random.sample(pgen, 2) if len(pgen) >= 2 else (pgen[0], pgen[0])
            kids.append(mutate(crossover(a, b), sigma))
        kfits = eval_pop(kids, scen_set, reps, seeds, reward, dot_frames,
                         tag="%s_g%d" % (label, gen))
        pool = list(zip(pfits, pgen)) + list(zip(kfits, kids))
        parents = sorted(pool, key=lambda x: -x[0])[:mu]
        sigma = max(0.02, sigma * 0.97)
        print("[ga] %s gen %d  best=%.3f  sigma=%.3f  top=%s"
              % (label, gen, parents[0][0], sigma,
                 [round(p[0], 2) for p in parents]), flush=True)
        _save_champion(parents[0][1])
    return parents


def stage_difficulty(gen, gens, n_stages):
    """CURRICULUM schedule: split the run into `n_stages` equal blocks of gens and
    ramp difficulty 0 -> 1 across them (0 = easy/slow, 1 = full speed). The first
    block trains on slow, forgiving versions of the SAME diverse scenarios, each
    later block speeds them up. n_stages<=1 disables the curriculum (full diff)."""
    if n_stages <= 1 or gens <= 1:
        return 1.0
    stage = min(n_stages - 1, gen * n_stages // gens)
    return stage / float(n_stages - 1)


def evolve_alternating(seed_pop, gens, scen_set, dot_frames, lam, mu, init_sigma,
                       reps_dot, seeds_dot, reps_succ, seeds_succ,
                       sigma_floor=0.02, start_metric="dot", label="alt",
                       n_stages=1, jitter=1.0):
    """(mu+lambda)-style evolution where the fitness metric ALTERNATES every
    generation (dot flight-reward <-> binary success) AND a difficulty CURRICULUM
    ramps the scenarios from slow/easy to full speed across `n_stages` blocks.
    Elites are carried forward but RE-SCORED under each gen's metric+difficulty,
    so selection never compares across the (incomparable) scales.

    `jitter` widens per-rep scatter during training (regularizer). Returns the
    final survivor list [(fit, genome), ...] (best-first under the LAST gen's
    metric); the caller picks the champion by a full-difficulty re-eval."""
    sigma = init_sigma
    pop = list(seed_pop)
    while len(pop) < lam:
        base = random.choice(seed_pop) if seed_pop else [0.0] * N
        pop.append(mutate(base, init_sigma, rate=0.5))
    pop = pop[:lam]

    parents = None
    for gen in range(gens):
        metric = start_metric if gen % 2 == 0 else (
            "success" if start_metric == "dot" else "dot")
        reps = reps_dot if metric == "dot" else reps_succ
        seeds = seeds_dot if metric == "dot" else seeds_succ
        diff = stage_difficulty(gen, gens, n_stages)
        fits = eval_pop(pop, scen_set, reps, seeds, metric, dot_frames,
                        tag="%s_g%d" % (label, gen), difficulty=diff, jitter=jitter)
        parents = sorted(zip(fits, pop), key=lambda x: -x[0])[:mu]
        print("[ga] %s gen %d  metric=%-7s diff=%.2f  best=%.3f  sigma=%.3f  top=%s"
              % (label, gen, metric, diff, parents[0][0], sigma,
                 [round(p[0], 2) for p in parents]), flush=True)
        _save_champion(parents[0][1])   # rolling snapshot (final champ re-picked below)
        # Next population = elites (re-scored next gen) + fresh kids.
        pgen = [g for _, g in parents]
        kids = []
        for _ in range(lam - mu):
            a, b = random.sample(pgen, 2) if len(pgen) >= 2 else (pgen[0], pgen[0])
            kids.append(mutate(crossover(a, b), sigma))
        pop = pgen + kids
        sigma = max(sigma_floor, sigma * 0.97)
    return parents


def _save_champion(genome):
    with open(os.path.join(ROOT, ".ga", "champion.json"), "w") as fh:
        json.dump(to_json(genome), fh, indent=1)


# ---- Single-set driver (legacy / debug entrypoint) -------------------------
def main():
    random.seed(int(os.environ.get("PYSEED", "42")))
    gens = int(os.environ.get("GENS", "30"))
    lam = int(os.environ.get("LAMBDA", "20"))
    mu = int(os.environ.get("MU", "10"))
    reps = int(os.environ.get("REPS", "12"))
    seeds = tuple(int(s) for s in os.environ.get("SEEDS", "1").split(","))
    scen_set = os.environ.get("SET", "train")
    reward = os.environ.get("REWARD", "success")
    dot_frames = int(os.environ.get("DOT_FRAMES", "240"))
    init_sigma = float(os.environ.get("SIGMA", "0.06"))

    zero = [0.0] * N
    base = eval_pop([zero], scen_set, reps, seeds, reward, dot_frames, tag="base")[0]
    print("[ga] baseline (zero genome) on %s = %.3f" % (scen_set, base), flush=True)

    parents = evolve_phase([zero], gens, scen_set, reward, reps, seeds,
                           dot_frames, lam, mu, init_sigma, label="solo")
    champ = parents[0][1]
    _save_champion(champ)
    print("\n[ga] === CHAMPION validation ===", flush=True)
    tr = eval_pop([champ], "train", 30, (1, 2, 3), "success", dot_frames, tag="ch")[0]
    te = eval_pop([champ], "test", 30, (1, 2, 3), "success", dot_frames, tag="ch")[0]
    print("[ga] TRAIN success=%.0f   TEST success=%.0f   (gap = overfitting)"
          % (tr, te))


if __name__ == "__main__":
    main()
