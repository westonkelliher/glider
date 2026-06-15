# Multiplayer Roadmap

**Architecture:** custom netcode over raw ENet. Clients authoritative on collisions
with their own glider; server authoritative on ball position & velocity. Clients send
stamped impulses + predict the ball locally; server sends authoritative ball state;
clients reconcile by replaying in-flight impulses. No reliance on Godot's high-level
multiplayer or default physics.

---

## Phase 0 — Pure step refactor (no net)
Extract ball physics into a pure `step(state, dt, impulses) -> state` so server, client
prediction, and replay all call the same code.
- [ ] Ball state as a plain struct (pos, vel) decoupled from the node
- [ ] `BallSim.step()` pure function; `_physics_process` becomes a thin caller
- [ ] Same for glider integration if feasible (lower priority)
- **Check:** single-player plays bit-for-bit as before. No behavior change.

## Phase 1 — Transport + clock
Raw ENet peer, host/join, fixed-tick shared clock.
- [ ] Server/client connect, exchange hello
- [ ] Global tick counter; client estimates server tick (+RTT/2), runs slightly ahead
- [ ] Packet (de)serialization helpers (tick-stamped messages)
- **Check:** client logs server tick; drift stays < 1 tick over 60s on localhost.

## Phase 2 — Glider ownership + input
Each player drives only their own glider; input sampled locally, glider state relayed.
- [ ] Spawn one glider per peer; tag local authority
- [ ] Decouple input sampling from sim (input can come from net later)
- [ ] Relay owned-glider transform/velocity to others (interpolated on remotes)
- **Check:** two clients, two gliders, each moves its own; remote glider looks smooth.

## Phase 3 — Server-authoritative ball (no prediction)
Server runs `BallSim.step`, broadcasts `(tick, pos, vel)` at ~25 Hz; clients interpolate.
- [ ] Server ball loop + snapshot broadcast
- [ ] Clients render interpolated snapshots (no local ball sim yet)
- **Check:** ball identical on both clients (floaty/laggy is fine here).

## Phase 4 — Client impulse send + glider-owned collision
Client resolves its glider↔ball collision locally, sends stamped impulse to server.
- [ ] Local collision → impulse on ball + reaction on own glider
- [ ] Send `(tick, impulse)` with sequence id; server applies on its ball
- **Check:** hitting the ball makes the server ball react; both clients see it (delayed).

## Phase 5 — Client ball prediction + reconciliation
Client predicts ball at full rate; ring-buffers state + sent impulses; on snapshot,
snap to authoritative state at its tick and replay impulses with `tick > snapshot`.
- [ ] Per-tick ring buffer (state + impulses)
- [ ] Reconcile: rewind to snapshot, replay in-flight impulses, re-integrate to now
- [ ] Discard acked/absorbed impulses (no double-apply)
- **Check:** local hits feel instant; with snapshots the predicted ball converges, no compounding.

## Phase 6 — Error smoothing
- [ ] Lerp visual ball mesh toward corrected state over a few frames
- [ ] Tune snapshot rate vs smoothing window under simulated latency (clumsy_throttle / tc netem)
- **Check:** at 80–150ms RTT no visible pops/teleports on correction.

## Phase 7 — Edge cases & polish
- [ ] Simultaneous hits (two impulses same tick) reconcile without teleport
- [ ] Glider↔glider authority decided (each sends reaction, or server arbitrates)
- [ ] Goal-zone detection (server-side, off the Area3D)
- [ ] Join/leave/disconnect handling; late-join state sync
- [ ] (Later) server clamps impulse magnitude as basic anti-cheat
- **Check:** 2-player match start→goal→reset works under latency; no desync over a full match.

---

**Critical path:** Phase 0 unblocks everything (shared sim code). Phases 4→5 are the
hard core (impulse bookkeeping + reconciliation). Phases 1–3 are plumbing you can land fast.
