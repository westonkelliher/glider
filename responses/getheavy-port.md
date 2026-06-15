# GetHeavy → Glider port (branch `getheavy-features`)

**Heavy dive** — Space (was air-brake) is now GetHeavy's heavy mechanic, merged with the brake since both tuck the wings: hold to shrink + dive with 2.4–2.6× gravity feeding the pot-energy model (speed cap 30 → ~50 while heavy), release for the Tiny-Wings boost + upward lift, with a 1.2 s grace window so the launch carries instead of snapping back to cruise speed. New constants in `FlightTuning` (TEST/PLAY both tuned). HUD shows `>> HEAVY <<`.

**Infinite hill terrain** — flat floor replaced with GetHeavy's chunked sine-hill terrain, rescaled for flight (±50 m relief, ~500 m mega-hills with 80 m swoop ripples). `GroundMath` (analytic height/normal) is the single source of truth for collision, visuals, and flight physics. Chunks stream 11×11 around the glider, nearest-first, capped 3/frame (no hitches); checker-green flat-shaded mesh + deterministic per-chunk trees/rocks. Distance fog hides the streaming edge.

**Terrain skimming** — ground contact deflects velocity along the slope preserving speed (the valley swoop), with mild time-based friction.

**Verified** via headless sims driving real input: dive 23 → 52 m/s, release pops 52 → 55 and carries, heavy ground-swoop holds ~51 m/s, climbing trades speed for height honestly, 200+ chunks streamed, zero errors. Two bugs my sim caught and fixed: the old speed cap ate the release boost in 0.3 s, and skim friction was per-frame (−91%/s).

Decisions you may want to revisit: Ctrl boost kept as-is alongside the dive; `environment/world.gd`/`floor.tscn` left on disk unused; terrain relief ±50 m (tune `GroundMath.AMPLITUDE`/`H_SCALE`).
