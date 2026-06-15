# Rocket League physics reference (for tuning the glider game)

> **NOTE:** Glider-game values below are a snapshot and have almost certainly
> changed since this was written. Re-derive them from the code; the RL column
> and the *method* are the durable part.

## Unit convention

All lengths expressed in **G ≡ gravity·s²** (a length). Speeds in **G/s** (= gravity·1s).
This normalizes by the Froude relation `v²/(g·L)` so two games at different scales
are comparable on feel.

- Rocket League: `G = 650 uu` (gravity = 650 uu/s²; 1 uu ≈ 1 cm)
- Glider game:   `G = 9.8 units` (gravity = 9.8)

To convert a glider value to G: `value / 9.8`. A speed: `(units/s) / 9.8`.

## Comparison (glider column = snapshot, will drift)

| Feel dimension          | Rocket League            | Glider (snapshot)        |
|-------------------------|--------------------------|--------------------------|
| Gravity                 | 1 G/s²                   | 1 G/s²                   |
| Ball diameter           | 0.28 G                   | 0.41 G (r=2)             |
| Character size          | 0.18 G len, 0.13 wide    | ~0.25 G wingspan         |
| Ball ÷ character        | ~1.5× car                | ~1.6× wingspan           |
| Max character speed     | 3.5 G/s (supersonic 2300)| 3.1 G/s (cap 30)         |
| Max ball speed          | 9.2 G/s (6000 uu/s)      | ~4 G/s (impact-limited)  |
| Turn radius @ top speed | ~1.75 G (yaw, ground)    | ~0.7 G (pitch loop, est) |
| Min turn radius (slow)  | 0.22 G                   | tighter (v/ω)            |
| Camera distance         | 0.42 G (default 270 uu)  | 0.74 G (~7.3 units back) |
| Camera FOV              | 110°                     | 75° (Godot default)      |
| Camera height           | 0.15 G                   | 0.20 G                   |
| Arena                   | 15.8 × 12.6 G, ceil 3.1 G| open plane, no walls     |

## Raw Rocket League constants (durable)

- Gravity: 650 uu/s²
- Max car speed: 2300 uu/s (supersonic ~2200; no-boost drive ~1410)
- Max ball speed: 6000 uu/s
- Ball radius: ~91.25 uu (diameter ~182.5)
- Octane hitbox: 118.0 long × 84.2 wide × 36.2 tall
- Arena: ~8192 wide × 10240 goal-to-goal × 2044 ceiling
- Default camera: distance 270, height 100, angle ~-3°, FOV 110°
- Turn radius vs speed (uu): ~145 @ 0 → 426 @ 1000 → 909 @ 1750 → ~1136 @ 2300

## Biggest feel gaps noted at snapshot time

1. Camera too far + too narrow (0.74 G @ 75° vs RL 0.42 G @ 110°). Wide close
   camera is most of RL's speed sensation — raising FOV to ~100-110° is highest impact.
2. Ball ~2.3× slower than RL in G terms — feels dead off hits (lower ball mass / raise restitution).
3. Ball large (0.41 G, bigger than wingspan) — plays beach-ball. r≈1.4 (~0.29 G) matches RL.
4. No arena — RL's walls/ceiling define the game; glider is open space.
