# Roadmap — yae-dlss5 as tier R of the NR program (2026-10-07)

> **Status: approved on 2026-10-08.** The user read the research report
> (`reports/Нейрорендеринг и трассировка пути для YAE.md`, with its notes in `research_notes/`) and
> agreed with it in general. The program decisions P1–P12 and the milestones M0–M5 live in the program
> document `project-empty/docs/NR_PT_Program.md` (the workspace's starter repository); the user
> took them on 2026-10-08 — P5 and P6 explicitly (modified DLLs only as an opt-in; v2 — yes), the rest as
> recommended. Hardware (2026-10-08): Linux and Windows with the game are one PC with an RTX 5090; an
> RTX 3060 Laptop 6 GB gives the first RTX 30 numbers in D1.8. Each phase gets its own plan by the engine's method
> (reconnaissance → items with their source → subphases with an acceptance number → "Done" with the
> numbers before and after) **at the moment it starts**; D1 and D2 have theirs now. This file holds the
> order, the boundaries, the gates and the dependencies, so that phases do not compete for the same
> items.

## Principle

**What the repository is today.** A one-command installer of the "v1 chain" for the original 32-bit
OpenGL game: `YOU_ARE_EMPTY.exe` → ReShade x86 → DLSS5-Feeder 1.16.0-beta.6 (protocol v10) → a 64-bit
D3D12 helper → OptiScaler DLSS-NR 0.2.0 → `nvngx_dlssnr.dll` 310.8.0 through NGX
([README.md](../README.md) lines 8–17, [VERSIONS.txt](../VERSIONS.txt) lines 7–14). It is tested on one
GPU, an RTX 5090 with driver 616.92, and needs an RTX 50 for the neural pass. What the model receives is
a coarse approximation: the colour is the finished frame with the HUD in it
(`payload/reshade-shaders/Shaders/DLSS5_Feed.fx` lines 72–76, 183–184), the motion vectors are
LumeniteFX optical flow at 1/8 resolution (same file, lines 16–33), there is no jitter, and only the NR
DLL is pinned by hash (`Setup-YAE-DLSS5.ps1` lines 16–20).

**What it becomes.** Tier R — "raster + NR" — of the three graphics tiers of the original game (P1):
the original renderer (native OpenGL, DS2's own fixed-function and ARB shader paths, normal maps, and
DS2's HDR renderer where DS2 allows it — see below) with NR on top, on **the widest set of GPUs**:
everything that runs a `yae-neural` backend, with no RT cores needed. Its v2 replaces the borrowed
chain with our own two parts (P6): **glhook**, a DS2-aware x86 `opengl32.dll` proxy that captures the
frame *before the HUD* with depth, camera motion vectors, masks and optional jitter, and
**`yae-nr-host64.exe`**, a 64-bit host that runs an optional AA stage and then NR through the shared
runtime `yae-neural` (P2). The two talk over the YNB bridge protocol ([Spec_BridgeProtocol.md](Spec_BridgeProtocol.md),
contract C3 of the program). The v1 chain stays as the "legacy" install profile until v2 reaches
parity with it.

**Does NR inside RTX Remix (yae-QindieGL, tier P) absorb this repository? No.** The two become tiers
that share code and serve different GPUs and different looks:

- **Different GPUs.** Tier P needs a GPU that path-traces *and* runs NR on top of it. NR alone costs
  5.6–15 ms per 1080p frame on RDNA4/RDNA3 and about 8 ms per 4K frame on an RTX 5090 (research notes,
  `nr_cross_vendor.md` §1, `dlss5_nr_nvidia.md` §3), so PT + NR is a high-end feature. Tier R is the only
  route to NR on RTX 20/30, RDNA2/3, Intel and GPUs without RT units.
- **A different look.** Tier R keeps DS2's own renderer. QindieGL's D3D9 path — the road into Remix —
  runs with DS2's shader path, HDR and normal maps off; its Phase F (the ARB shader path) is deferred
  (`yae-QindieGL/STATUS.md` lines 621–627).
- **A different NR route today.** NR inside Remix is NVIDIA's NGX call, i.e. RTX 50 only, until the
  planned fork routes it to `yae-neural` (QindieGL Phase J).
- **The lightest integration.** The game's own frame is cheap: through QindieGL's D3D9 path it was
  measured CPU-bound at 4.5 ms per frame on average with `Present` below 0.6 ms
  (`yae-QindieGL/STATUS.md` lines 788–798); the native OpenGL frame has not been measured (D1.0 does
  it). Almost the whole GPU budget goes to NR, and nothing else moves when a backend changes. So
  **yae-dlss5 is the proving ground of `yae-neural`**: every new backend is validated here first.
- **Shared code instead of absorption:** `yae-neural` (all three tiers), the DS2 view knowledge
  (camera split, projection classes, the HUD boundary — contract C5, documented in
  `yae-QindieGL/docs/DS2View.md` from QindieGL's code and tests, reused by glhook), and the PBR
  materials (`yae-materials`, tiers P and N).

**DS2's HDR is NVIDIA-only.** DS2's HDR renderer (float pbuffer, tone mapping, bloom, eye adaptation)
requires `GL_VENDOR` to contain "NVIDIA": it is forced off silently on ATI/AMD and with a message on
other vendors (`yae-research/notes/console_variables.md`, `scr_hdr`); the retail configuration has
`hdr 0`. On AMD and Intel tier R runs DS2's LDR frame, which is
what NR consumes anyway (an LDR proxy).

**The installer of every tier, and the name (open).** Over time yae-dlss5 may become the single
installer/launcher of the original game's tiers R, P and P+NR (P6) — decided at D4, not before. Once v2
runs vendor-neutral NR, the name "dlss5" describes neither the runtime nor the tiers; whether to rename
the repository is an open question for the user, taken together with the installer role at D4.

**Rules that hold in every phase.** Measure, then change (every phase hands in numbers before and
after; every estimate is labelled as one). NR is opt-in, with an instant A/B toggle, an intensity
control, masks and a dark-scene check (P3). NVIDIA's weights and DLLs never enter git, CI or a release
(P4). Modified NVIDIA DLLs only as an explicit opt-in pinned by the SHA-256 of a vetted build (P5).

## Order

| # | Phase | What | Size | Gate (handed in with a number) | Plan |
|---|---|---|---|---|---|
| D1 | **v1 chain hardening** — runs **now, in parallel with D2** | Feeder 1.17/1.18 with both halves together (protocol v10 → v11); the OptiScaler line of wilsjo2 ≥ v0.8.92 instead of Dagherbou's v0.2.0; SHA-256 for every download; conservative NR defaults (structure 0.7, tone 0.3, intensity below 1, `MaxRatio` kept); the host's CPU affinity and Large Address Aware; GPU profiles RTX 50 / RTX 40 / RTX 20-30 (P5); an interim, opt-in AMD profile; the measurement campaign and the tier-R test protocol; A/B and dark-scene checks (P3) | S–M | 0 downloads from a moving branch or without a SHA-256; the v11 pair + the new consumer produce the NR evidence lines on the RTX 5090 for 10 min on 3 levels; a numbers table per level and per GPU at hand — including at least one RTX 20 or 30 card, or the recorded absence of a tester; the A/B sheet and the dark-scene report | [Phase_D1_ChainHardening.md](Phase_D1_ChainHardening.md) — plan of 2026-10-07, D1.0–D1.10 |
| D2 | **glhook** — runs **now, in parallel with D1**; needs no `yae-neural` | the DS2-aware x86 `opengl32.dll` proxy: the frame model (camera, projection classes, sky, weapon, shadow pass), the capture point before the HUD, the HUD layer, depth, camera motion vectors, stencil masks, optional Halton jitter, the overlay, pass-through; the YNB client against a loopback host and a fault-injection host | L | through the loopback host: colour captured before the HUD in ≥ 99 % of gameplay frames and 100 % pass-through outside gameplay; motion-vector reprojection error on a synthetic turn: with < zero vectors < opposite sign; HUD pixels unchanged by the stand-in "NR"; 0 differing pixels in pass-through; the YNB conformance suite green | [Phase_D2_GLHook.md](Phase_D2_GLHook.md) — plan of 2026-10-07, D2.0–D2.9 |
| D3 | **`yae-nr-host64` on `yae-neural`** + YNB v1 + the AA stage — **waits on** `yae-neural` N1 (API 0.1 + the identity backend) for the plumbing and on N1/N2 kernels for NR | the host: YNB host side, allocation of the shared set, an optional AA stage (DLAA through NGX on RTX, FSR 3.1 native AA elsewhere, XeSS where it helps), NR through `yae-neural` submit mode (AUTO backend), composition, timings; the v1/v2 parity check | M–L | tier R on `yae-neural` on NVIDIA and AMD (Intel through the CPU-copy transport if its GL driver lacks the interop); YNB conformance green against the real host; per-stage milliseconds per GPU line at hand; the user's A/B verdict v1 vs v2 on the RTX 5090 | its own document at the start (`docs/Phase_D3_Host.md`) |
| D4 | **Installer v2** | tier selection R / P / P+NR, GPU detection → backend and profile, overlay defaults, the v1 legacy profile, a diagnostics bundle; the decision on the single-installer role and on the name (P6) | M | a clean install of each tier on every GPU line that has a lab report; restore returns the folder byte for byte; the diagnostics bundle collected in one step | at the start |
| D5 | **Student model rollout** — after `yae-neural` N5 | `yae-student-N` (our own network, open weights) on the low-end lines through `yae-neural` | S | per-GPU milliseconds from the lab and the user's verdict on an A/B sheet against `dlssnr-310.8.0` | at the start |

**Parallelism.** D1 and D2 are lanes B and C of the program and run at the same time: they share no
code (D1 touches the installer, the payload and its configs; D2 is new code under its own directory),
only the Windows game box — the measuring subphases are scheduled, code is written in parallel. D2 is
developed against a loopback host and a fault-injection host of its own, so it does not wait for
`yae-neural`. D3 is where lane C joins lane A (`yae-neural`): its plumbing can start as soon as N1 has
frozen API 0.1 with the identity backend (milestone M0), its NR as soon as N1's COOPMAT_FP8 kernels pass
their parity gate (M1), and its coverage of RTX 20/30, RDNA2/3 and Arc follows N2. D4 follows D3 (and
QindieGL Phase H for the P tiers it installs); D5 follows `yae-neural` N5.

---

## GPU coverage by phase

How each GPU line gets NR in tier R, and from which phase. "Measured" figures are the community ports'
published numbers (research notes, `nr_cross_vendor.md` §1–2); "estimate" marks arithmetic, not a
measurement.

| GPU line | Today (v1) | After D1 (v1 hardened) | After D3 (v2 on `yae-neural`) | After D5 |
|---|---|---|---|---|
| RTX 50 | NR through NGX, the signed `nvngx_dlssnr.dll` 310.8.0; tested on one RTX 5090 | the same, pinned end to end, conservative defaults, measured per level | NGX backend (N4) or COOPMAT_FP8 kernels (N1), chosen by AUTO from lab data; NR before the HUD with camera MVs | unchanged; student optional |
| RTX 40 | DLAA only: the signed DLL fails with `0xbad00001` | opt-in modified build pinned by SHA-256 (P5), e.g. ShortFuse's cross-generation 310.8 (Ada path) | COOPMAT_FP8 (Ada has FP8 tensor cores; OpenDLSS-NR measured 7.8 ms at 1080p on an RTX 4070 SUPER) | unchanged |
| RTX 20/30 | DLAA only | opt-in cross-generation build (FP16 path) at `WorkingScale` ≈ 0.5 — **the first public NR numbers for this line** (none exist anywhere) | COOPMAT_FP16E; estimate 17 ms (RTX 3080), 24 ms (RTX 2080), 40 ms (RTX 3060) at 1080p before model scale — so model scale 0.5 by default | the student network: the line's real answer |
| RDNA4 | nothing | interim opt-in profile through zmodelerlover's ReShade add-on: colour only, the HUD inside the frame, a block motion estimator on 32-bit games — if D1.9 takes it | COOPMAT_FP8; measured 5.6 ms (Linux) / 7.2 ms (Windows) at 1080p on an RX 9070 XT | unchanged |
| RDNA3 | nothing | the same interim profile (danielblnc's runtime) | COOPMAT_FP16E; measured 15 ms at 1080p on an RX 7900 XTX (Linux) | student at full scale |
| RDNA2 | nothing | the same interim profile (HIP SDK 7.2 needed on RX 6000) | SCALAR, reduced model scale (hundreds of ms at full scale today — community reports) | student |
| Arc B-series (Xe2) | nothing | nothing (no 32-bit GL route exists) | COOPMAT_FP16E (50–53 ms at 720p today; tuning needed); the CPU-copy transport if Intel's GL lacks the interop extensions | student |
| Arc A-series, iGPUs, GTX | nothing | nothing | SCALAR or FP16E at reduced scale; CPU copy if needed | student on SCALAR |

The rule of the program's hardware lab (P11) applies: no backend becomes AUTO's choice on a GPU line
without a lab report from that line. In hand on 2026-10-08: the RTX 5090 (one PC, Linux and Windows) and
an RTX 3060 Laptop 6 GB; every other cell is filled by testers.

## Cross-repository dependencies and milestones

| Needs | From | For | Status (2026-10-07) |
|---|---|---|---|
| C API 0.1 + identity backend (contract C1) | `yae-neural` N1 | D3 plumbing (D3 can integrate before kernels exist) | the repository does not exist yet; created at M0 |
| The frame contract (C2): colour encodings, an explicit image origin (`YN_ORIGIN_TOP_LEFT` / `YN_ORIGIN_BOTTOM_LEFT` for every input and the output), MVs in pixels current → previous in the image's own coordinates, history flag separate from the vector, depth, control mask, controls, model scale | `yae-neural/docs/Spec.md` | D2 (what glhook writes: bottom-left, nothing flipped), D3 | written in parallel; YNB v1 carries the origin per generation and per frame |
| COOPMAT_FP8 kernels ≥ 45 dB against the reference | `yae-neural` N1 | D3 NR on RTX 40/50, RDNA4 | planned (M1) |
| COOPMAT_FP16E, SCALAR, AUTO from lab data | `yae-neural` N2 | D3 NR on RTX 20/30, RDNA2/3, Arc | planned (M2) |
| Submit mode with Win32 imports and D3D12-fence/timeline sync, model scale, composition, masks | `yae-neural` N3 | D3 | planned (M3) |
| NGX backend, opt-in modified builds | `yae-neural` N4 | D3 parity with v1 on RTX 50; D1's P5 profile retires | planned |
| `.ynw` extraction from the user's own DLL (contract C4, P4) | `yae-neural` `yn-extract` | D3/D4 installers | planned (N1) |
| Student model, open weights | `yae-neural` N5 | D5 | 2027 |
| DS2 view classification: camera split, projection classes, HUD boundary, sky, weapon, the shadow pass (contract C5) | `yae-QindieGL/docs/DS2View.md` (QindieGL H.10), backed by QindieGL's code and tests (`yae_camera_split`, the camera census) | D2 | H.10 writes it now, without the game box; D2.0 accepts it or returns the gaps, closed before M2; D2.1 implements it as the `ds2view` module with tests |
| Contingency transport if glhook's GL interop fails on a vendor (the non-Remix D3D9 frame to this repository's host through D3D9Ex shared surfaces) | `yae-QindieGL` Phase K | D3 | contingency only |
| The YNB protocol v1 (contract C3) | **this repository** | glhook (D2), host (D3) | [Spec_BridgeProtocol.md](Spec_BridgeProtocol.md): draft at M0, frozen at the start of D3 |
| The tier-R test protocol (levels, frame-time capture, logs) for the hardware lab | **this repository**, D1.0 | `yae-neural/reports/hw/` (P11) | defined in D1 |

| Milestone | What yae-dlss5 delivers | What it needs |
|---|---|---|
| **M0** (week 0–1, estimate) | YNB v1 **draft** frozen for implementation (this repository owns C3); the user's decisions P1, P3–P6, P11, P12 as they concern tier R | `yae-neural` created; C API 0.1 frozen with the identity backend |
| **M1** (weeks 1–3) | **D1 done**: the hardened v1 with a numbers table on every GPU at hand, the first RTX 30 numbers on the RTX 3060 Laptop 6 GB (in hand since 2026-10-08), RTX 20 if a tester exists | the RTX 3060 Laptop; testers with RTX 20/40 and AMD (P11) |
| **M2** (weeks 3–8) | **D2 done**: glhook gives colour before the HUD, camera MVs (with < without < opposite sign) and masks through the loopback host | C5 — `yae-QindieGL/docs/DS2View.md` (QindieGL H.10), accepted by D2.0 with its gaps closed |
| **M3** (weeks 8–14) | **D3 done**: tier R on `yae-neural` on NVIDIA and AMD; Intel through the CPU copy if needed; YNB v1 frozen at the start of D3 | `yae-neural` N1–N3 (N4 for RTX 50 parity) |
| **M4** (after the engine's Release 1) | nothing new required; D4 under way | — |
| **M5** (2027) | **D4** installer with tiers; **D5** the student network on the low-end lines | `yae-neural` N5; QindieGL Phase H/J for the P tiers |

The weeks are the program's estimates, not commitments.

## Risks

| Risk | Effect | Mitigation |
|---|---|---|
| The whole NR ecosystem pins one leaked DLL, 310.8.0 (SHA-256 `E16BCF15…1FC8E`); NVIDIA announced model updates "later this fall" | a new official runtime breaks hash-pinned installs or is not extractable | pin 310.8.0 (D1.1); the NGX backend takes new official DLLs as they come; the student network (D5) ends the dependency |
| Modified NVIDIA DLLs circulate on Discord and mirrors; look-alike repositories are documented by the Feeder's author | a user installs malware believing it is a DLSS build | P5: opt-in only, SHA-256 of a vetted build, never fetched from unknown mirrors (D1.7) |
| The two halves of the Feeder must come from one release (v10 and v11 do not talk) | a partial update silently disables NR | D1.2 replaces both halves together, the verifier compares them, the installer refuses a mixed pair |
| The helper inherits DS2's CPU-0 pin (`ds2kernel.dll` calls `SetProcessAffinityMask(…, 1)`; child processes inherit affinity) | the helper's threads compete with the game's render thread on one CPU; with Remix's bridge this froze the game | D1.5 measures it and widens the helper's mask; YNB makes the client start the host suspended with the system mask (Spec §2) |
| 32-bit address space: the retail EXE is not Large Address Aware; QindieGL ran out of address space in multi-location sessions | allocation failures or crashes in long sessions with ReShade, LumeniteFX and the feeder (v1) or glhook's GPU interop (v2) in the process | D1.5 measures the largest free block; the LAA patch stays the user's decision (Q4 of D1) |
| DS2's frame shape differs between levels and states (shadow silhouette pass first, the sky first, the weapon's own projection, screen filters, films, menus, the HDR pbuffer path) | the capture point lands in the wrong place: NR on the HUD, or no NR | D2.0 records the frame patterns on the native driver before any capture code; the HUD layer keeps the composite exact even when the capture is early (D2 design) |
| `glWaitSemaphoreEXT` has no timeout; a wait that is never satisfied wedges the game's GPU queue until the driver resets it (seen by the Feeder as a system-wide freeze) | a crashed or hung host freezes the game | YNB rule: no GPU wait on a value not first observed on the CPU (Spec §5); the host releases every fence on exit |
| Frames that alternate between NR and no NR strobe (measured by dlss5-neural-amd: ~189 fps presented, ~64 distinct images/s) | an unwatchable picture when the host runs late | YNB pacing with hysteresis; never show a stale result (Spec §8) |
| Intel's Windows OpenGL driver may lack `GL_EXT_memory_object_win32` / `GL_EXT_semaphore_win32`; AMD faults when an imported NT handle is closed (3 of 8 runs) | no zero-copy transport on Intel; random driver crashes on AMD | the CPU-copy transport; the never-close rule; QindieGL Phase K as the contingency |
| Hardware: only an RTX 5090 is recorded as available | coverage claims stay unmeasured | the hardware lab (P11); every unmeasured cell is marked as such |
| Reception: NR seen as an "AI filter", worst in a dark horror game | backlash against the project | P3 in every profile: opt-in, A/B, intensity, masks, a dark-scene histogram check; publish A/B comparisons |

---

## D1 — v1 chain hardening

**Goal.** The v1 chain stays the working tier-R profile until v2 reaches parity, so it must be
reproducible, current, conservative and measured — and it is the only place where NR numbers for RTX
20/30 can be produced before `yae-neural` exists.

**Scope.** A baseline measurement and the tier-R test protocol (levels, saves, frame-time capture,
logs) before any change; SHA-256 for every download and every shipped binary, with pinned URLs (tags
and commits instead of `main`/`mainline`), and pre-placed files held to the same hashes; DLSS5-Feeder
1.17.0 (or 1.18.x once stable) with both halves, the effect and the verifier from one release (protocol
v11); OptiScaler from wilsjo2's line at v0.8.92 or later, which fixes the flicker below 100 % model
scale, instead of Dagherbou's v0.2.0 (dormant since 2026-09-04); conservative NR defaults after
NVIDIA's own in Remix (structure 0.7, tone 0.3) with intensity below 1 and the `MaxRatio` highlight
guard kept, plus a bound A/B key; the helper's CPU affinity (measure, then widen) and the game's Large
Address Aware state (measure, report, offer); GPU profiles RTX 50 / RTX 40 / RTX 20-30, the last two
through an opted-in, hash-pinned modified build (P5) with `WorkingScale` ≈ 0.5 on RTX 20/30; an interim,
opt-in AMD profile through zmodelerlover's add-on if a tester exists; the measurement campaign (ms per
stage, per level, per GPU) and the A/B and dark-scene histogram checks (P3).

**Gate.** As in the order table. **Not included:** any change to the architecture of the chain
(capture before the HUD, real motion vectors — that is D2/D3); bundling NVIDIA or modified DLLs.

## D2 — glhook

**Goal.** Give NR honest inputs on the original game: the colour before the HUD, camera motion vectors
from depth and the camera matrices, masks for what camera motion cannot explain, and optional jitter
for a temporal AA stage — and composite the HUD back on top, unchanged.

**Scope.** An x86 `opengl32.dll` proxy that forwards every call to the system OpenGL; a shadow of the
state glhook needs (matrix stacks, projection classes, the camera taken at modelview stack depth 0,
blend/depth state, viewports, contexts, display lists); the capture point (the first draw after the
world with an affine projection and depth testing off, or the first read of the back buffer after the
world, or the swap); the HUD layer (a premultiplied colour/alpha target and a multiply target with
per-target blending, which reproduces DS2's `blend`, `add` and `modulate` HUD materials exactly);
depth into R32F and camera MVs in pixels, current → previous; masks through the stencil buffer, which
DS2 never uses; Halton jitter on the world and weapon projections when the host's AA stage asks for it;
an ImGui overlay (A/B, intensity, status); pass-through outside gameplay; logging; the YNB client with a
loopback host and a fault-injection host.

**Gate.** As in the order table. **Not included:** per-object motion vectors for moving actors (masked
in v1), DS2's HDR pbuffer path (decided in D2's Q5), the NR itself (D3).

## D3 — `yae-nr-host64` on `yae-neural`

**Goal.** Replace the v1 helper and OptiScaler with our own host on the shared runtime, on every GPU
line `yae-neural` covers.

**Scope.** The host side of YNB v1 (launch rules, allocation of the shared set as D3D12 resources and
fences on the game's adapter, imports into the runtime's Vulkan device, the watchdog); an optional AA
stage — DLAA through NGX on RTX, FSR 3.1 native AA on Vulkan elsewhere, XeSS where it measures better —
fed with glhook's jitter; NR through `yae-neural` submit mode with the AUTO backend and model scale;
composition (the runtime's `ratio`/`replace` with the control mask); controls from the overlay; per-stage
GPU timings in the control block; the model `dlssnr-310.8.0` extracted from the user's own DLL at install
(P4); A/B parity against the v1 chain on the RTX 5090 and the decision whether v1 stays a legacy
profile. Subphases sketched: host skeleton against the identity backend → AA stage → NR on FP8 lines →
NGX parity → FP16E/SCALAR lines and the CPU-copy transport → parity and decision.

**Gate.** As in the order table. **Depends on** `yae-neural` N1 (identity: plumbing; FP8: NR on RTX
40/50 and RDNA4), N2 (RTX 20/30, RDNA2/3, Arc), N3 (submit mode imports), N4 (NGX parity).

## D4 — installer v2

**Goal.** One installer for the original game's graphics tiers. **Scope:** tier selection (R, P, P+NR —
the P tiers install QindieGL and the pinned Remix build of QindieGL Phase H), GPU detection → backend
and profile from the lab's data, overlay defaults with NR off until chosen (P3), the v1 legacy profile,
a diagnostics bundle (logs, configs, system info), restore. The single-installer role and the
repository's name are decided here (P6). **Gate:** as in the order table.

## D5 — student model rollout

**Goal.** NR on the lines the original network cannot serve in real time (RTX 20/30 at full scale,
RDNA2, Arc, iGPUs) with our own network and open weights (P10). **Scope:** `yae-student-N` through
`yae-neural` N5, profiles per GPU line, the A/B sheet against `dlssnr-310.8.0`. **Gate:** as in the
order table.

---

## Dependencies outside this repository

- `yae-neural` (new, P2): N1 for D3's plumbing and the FP8 lines, N2 for the FP16E/SCALAR lines, N3 for
  submit mode, N4 for NGX parity, N5 for D5. The repository pins it by commit.
- `yae-QindieGL`: contract C5 — `docs/DS2View.md` from its subphase H.10 (the DS2 view knowledge glhook
  ports), Phase K as the transport
  contingency, Phase H/J for the P tiers D4 installs.
- The program document (`project-empty/docs/NR_PT_Program.md`): the decisions P1–P12, the milestones,
  the lanes, the hardware lab.
- External, pinned by version and hash: DLSS5-Feeder (MIT), OptiScaler DLSS-NR forks (GPL-3.0), ReShade
  (BSD-3-Clause), LumeniteFX, NVIDIA's NGX runtimes (downloaded at install, never stored), zmodelerlover's
  AMD add-on (MIT, D1.9 only).
- The user: the decisions of D1 and D2 (their tables), the game box, and the A/B verdicts.
