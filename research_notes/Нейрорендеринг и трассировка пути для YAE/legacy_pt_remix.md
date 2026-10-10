# Path tracing for the original (closed-source, 32-bit OpenGL) *You Are Empty*: RTX Remix, OpenGL→D3D9 wrappers, alternatives, and PT + DLSS 5 Neural Rendering — state as of 2026-10-07

Legend for evidence quality: **[code]** = read directly in `NVIDIAGameWorks/dxvk-remix` `main` (sparse clone made 2026-10-07, HEAD `0e18e55`, last commit 2026-10-06) or in another named repo; **[primary]** = vendor release notes / blog / official repo README / official issue reply; **[press]** = secondary press; **[forum]** = community / forum / single-user claim, not independently verified. Every bullet carries the date of the underlying release, commit, post or article. "Main" means unreleased code on the default branch, not in any tagged release.

## 1. RTX Remix in 2026: versions, features, DLSS 5 NR status, open source, community

### Takeaway
The latest *tagged* Remix release is **remix-1.5.2 (2026-06-16)**. Since then, `dxvk-remix` main has added a lot of unreleased work: DLSS SR/RR 4.5 (2026-08-24), MFG up to 6 interpolated frames, "Sparse Rendering" (which requires DLSS-RR), Windows-on-Arm builds and, on **2026-09-18, an integrated, experimental DLSS 5 Neural Rendering pass** called "DLSS 3D-Guided Neural Generation". The code has no RTX Mega Geometry and no Neural Texture Compression. The runtime (zlib), the Toolkit (Apache-2.0) and the bridge (now inside `dxvk-remix`; the separate `bridge-remix` repo is archived) are open source. NVIDIA staff write the vast majority of commits. Community contributions are real but small in number: XeSS 2.1, the UI rework, the AMD TraceRay default and various fixes.

### Cited Findings
**Release timeline (tagged releases)**
- `remix-1.0.0`, tagged 2025-03-13 and announced 2025-03-18 ("RTX Remix officially released"). Shipped with DLSS 4 Multi Frame Generation, the transformer model for Ray Reconstruction, the RTX Neural Radiance Cache ("first publicly released neural shader"), RTX Skin (ray-traced SSS from the RTX Character Rendering SDK) and RTX Volumetrics. NVIDIA claimed "over 30,000 modders" and "over 1 million gamers" — [primary] [NVIDIA news 2025-03-18](https://www.nvidia.com/en-us/geforce/news/rtx-remix-half-life-2-rtx-demo-launching-march-18/); [primary] [release remix-1.0.0](https://github.com/NVIDIAGameWorks/rtx-remix/releases/tag/remix-1.0.0)
- `remix-1.1.0` (2025-07-18): RtxOptions refactor and fixes only — [primary] [release](https://github.com/NVIDIAGameWorks/rtx-remix/releases/tag/remix-1.1.0)
- `remix-1.2.4` (2025-09-09): path-traced particle system; settings clamping; "SPIR-V directly from Slang, enabling … cooperative vector intrinsics for neural shading"; order-independent transparency; better vertex-capture precision; community option `rtx.ignoreAllVertexColorBakedLighting` (@watbulb, dxvk-remix#99) — [primary] [release](https://github.com/NVIDIAGameWorks/rtx-remix/releases/tag/remix-1.2.4)
- `remix-1.3.6` (2026-01-27):
  - **Remix Logic** (Toolkit graph editor; the runtime layers `rtx.conf`, `user.conf` and `new.conf` files and blends between them on detected game state).
  - Overlay-based input system; pathtracer robustness fixes; MFG stability fixes; precision fix for vertex-shader games; heuristic that treats vertex colour as baked lighting.
  - Community: runtime UI rework by @xoxor4d (PR 105) and the **XeSS 2.1 SR upscaler by @sambow23 (PR 100)**.
  - [primary] [release](https://github.com/NVIDIAGameWorks/rtx-remix/releases/tag/remix-1.3.6)
- `remix-1.4.2` (2026-04-21): Particle VFX 2.0; eye shaders; "RTX Skin or Subsurface Scattering (SSS) is now up to 55% faster"; texture hot-reload; RtxOption layers (user changes go to `user.conf`, mod defaults stay in `rtx.conf`) — [primary] [release](https://github.com/NVIDIAGameWorks/rtx-remix/releases/tag/remix-1.4.2)
- `remix-1.5.2` (2026-06-16), the **latest GitHub release as of 2026-10-07**:
  - Toolkit: RTX IO texture packing and compression, override flattening, auto-save.
  - Runtime: GPU/CPU **smooth normals** for D3D9 geometry (opt-in through texture tagging); 32-bit index buffers; PointInstancer GPU culling ("~2 million objects"); translucent transmission in volumetrics; NRC "Boost Emissives" on by default; Unity upside-down fix; UTF-8 metadata ("Cyrillic and CJK"); DebugView statistics 42 ms → 1 ms at 4K.
  - [primary] [release list](https://github.com/NVIDIAGameWorks/rtx-remix/releases), [remix-1.5.2](https://github.com/NVIDIAGameWorks/rtx-remix/releases/tag/remix-1.5.2)
- NVIDIA's 1.5 article (2026-06-16):
  - **"Remix Skills"** are "text-based instruction files that provide specific functional context to AI coding agents".
  - Agents helped start work on *Dark Souls*, *Dragon Age: Origins* and *Titanfall 2*; "converting these to a fixed-function pipeline is a difficult, time-consuming process".
  - RTX IO results: Portal with RTX 25 → 17 GB; HL2 RTX 80 → 50 GB.
  - [primary] [NVIDIA news 2026-06-16](https://www.nvidia.com/en-us/geforce/news/rtx-remix-agent-skills-update/); [press] [Tom's Hardware, "up to 37 percent"](https://www.tomshardware.com/pc-components/gpus/nvidia-releases-rtx-remix-1-5-with-new-rtx-io-compression-reducing-mod-file-sizes-by-up-to-37-percent-update-also-adds-smooth-normals-and-rtx-remix-skills-agents); [primary] [docs: AI-Assisted Development](https://docs.omniverse.nvidia.com/kit/docs/rtx_remix/latest/docs_dev/tools/ai-agents.html)

**Unreleased work on `dxvk-remix` main after 1.5.2 (June–October 2026)** [code]
- DLSS SR and RR updated to **4.5 (310.7.128)** on 2026-08-24 — [commit 7294f68](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/7294f685670287183591feede5a3983d54caf0c6). Also "Remove NRD secondary preprocessing and RR transparency layer" (2026-08-28) — [commit list](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main)
- `rtx.dlfg.maxInterpolatedFrames` (range 1–6, default 2) is documented as "For DLSS 4.5 frame generation". A fix for "multi-frame generation above 2x" landed 2026-08-05 — [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md); [commits](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main)
- **DLSS 3D-Guided Neural Generation (DLSS-NR)**, 2026-09-18 — [commit ecf646d](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/ecf646d3ea97b1e81e450993f414a2ae31b71d3b). Details in Q5.
- **Sparse Rendering** (REMIX-4964, August–October 2026): `rtx.sparseRendering.enableSparseRendering` (default False) "applies a constant per-pixel sampling rate across the screen. **DLSS Ray Reconstruction is required**"; `rtx.sparseRendering.samplingRate` defaults to 0.2 (range 0.0625–1); "Compact GBuffer" landed 2026-10-06 — [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md); [commit ca4d79c](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/ca4d79caca88af66acfdcd2b64eb7b0e35025af2)
- NRC SDK 0.15 raised the **minimum driver to 610.47** (2026-07-29); NRC "training path seeding" (2026-09-11) — [commits](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main)
- Indirect ray dispatch support (2026-09-09) — [commit e7cb9d2](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/e7cb9d2a0a4d3207edd2741e1f3db365e200c70d)
- Windows-on-Arm support with an automatic x64→arm64ec shim (2026-06-29) — [commit 4dd8b30](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/4dd8b30f67aa96589884b06e27e39218e59fea5f). DLSS-NR was first excluded from WoA ("no arm64 package yet") and then enabled there on 2026-09-29 — [commit 5229c04](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/5229c042a13a4daa63a4575894c27dc5cd705334)
- Other main-branch changes, all at [commits](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main):
  - "Implement preserving instances across frames for static draw calls" (REMIX-5428, 2026-06-04).
  - "Invalidate texture hash on write lock" (REMIX-5631, 2026-06-25).
  - "Fix broken menus/UI for games using pre-transformed vertices" (REMIX-2244, 2026-06-30).
  - "Prefer RT-capable GPUs in adapter ranking for multi-GPU systems" (2026-08-03).
  - Sentry crash reporting and usage tracking (2026-07-28).
  - Integrated Nsight Graphics capture (2026-09-15).
  - Public unified DLSS SDK as a git submodule, NVAPI R615 and Aftermath 2026.3 (2026-09-10).
- **Not present in code (grep of main, 2026-10-07):** RTX Mega Geometry / cluster acceleration structures, and Neural Texture Compression. **Present:** NRC, RTXDI, ReSTIR GI, NEE cache, Opacity Micromaps (`rtx.opacityMicromap.enable`), Shader Execution Reordering (`rtx.isShaderExecutionReorderingSupported`), DLSS SR/RR/FG, Reflex, XeSS, NIS, TAA-U, DLSS-NR — [code] [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md), [src/dxvk/rtx_render](https://github.com/NVIDIAGameWorks/dxvk-remix/tree/main/src/dxvk/rtx_render)

**APIs (scripting / plugins / REST)**
- Remix SDK/API: a plain C header (`remix_c.h`) plus an optional C++ wrapper. It is implemented inside `d3d9.dll` and documented as "under development and may be subject to changes". The bridge "converts D3D9 calls from 32-bit to 64-bit … the Remix renderer operates exclusively in a 64-bit environment" — [code] [RemixSDK.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/documentation/RemixSDK.md)
- Remix API changelog **0.6.5** adds per-material `enableDlssControlMask`, `dlssControlMaskIntensity`, `dlssControlMaskToneStrength` and `dlssControlMaskStructuralStrength` — [code] [RemixApiChangelog.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/documentation/RemixApiChangelog.md)
- Remix Logic: graphs of C++ "components" that read game state and apply visual changes; custom components are written in C++ — [code] [RemixLogic.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/documentation/RemixLogic.md)
- Toolkit REST API: connects RTX Remix to Blender, ComfyUI, ChaiNNer and other apps (bulk texture export and AI upscaling/PBR) — [primary] [NVIDIA: "RTX Remix Creator Toolkit Open Source Available Now"](https://www.nvidia.com/en-us/geforce/news/rtx-remix-rest-api-comfyui-app-connectors/)

**Open source and community activity**
- Repos and licences, as of 2026-10-07:
  - `rtx-remix`: umbrella repo and issue tracker, MIT.
  - `dxvk-remix`: zlib, pushed 2026-10-06. It now contains the `bridge/` folder ("required for enabling a 32-bit game to interact with the 64-bit Remix Runtime dll").
  - `toolkit-remix`: Apache-2.0, created 2024-07-02, pushed 2026-10-06.
  - `bridge-remix`: MIT, **archived**, last push 2025-05-02.
  - [code] `gh repo view`; [bridge/README.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/bridge/README.md); [bridge-remix](https://github.com/NVIDIAGameWorks/bridge-remix)
- Activity: about **664 commits (including merges) on dxvk-remix main between 2025-10-07 and 2026-10-06**. Most are by NVIDIA engineers (top author: 198 commits). Identifiable community-attributed merges include:
  - xoxor4d: "[PR 155] fix preservePath regression" (2026-09-08), particle serialization fix (1.4.2), UI rework (1.3.6).
  - KingVulpes: "Default to TraceRay on AMD Windows drivers" (authored 2026-05-29, merged 2026-07-22 as `pkristof/pr146`).
  - Kim2091 and Kralich: smaller items.
  - Four commits authored as "CLAUDE_DXVK_TOKEN" (AI-agent-authored).
  - [code] `git log` / [commits](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main); [commit 0557867](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/0557867a82eec4898fe44a5928480ad4329b16f9)
- On 2026-10-07 the GitHub API reported "Pull requests are disabled for this repository" for `dxvk-remix`. Community patches still arrive as internal merge branches (`pr/146`, `pr/155`) — [code] `gh pr view` (2026-10-07); [commits](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main)
- The `rtx-remix` issue tracker holds about 1,100 issues and PRs by 2026-10; NVIDIA staff (e.g., NV-LL) triage and file internal REMIX-xxxx tickets — [primary] [issues](https://github.com/NVIDIAGameWorks/rtx-remix/issues)
- Notable runtime forks: softsoundd/dxvk-remix-mirrorsedge (181★, UE3 focus), NightSightProductions "RTX Remix Community Edition" (FSR 3.1 draft, see Q6), lunks/dxvk-remix-plus-dlssnr (DLSS-NR before NVIDIA's, see Q5), sambow23 (Garry's Mod x64), i4pptem (Silent Hill 3), TheGreatHMMMM (Halo) — [code] [forks](https://github.com/NVIDIAGameWorks/dxvk-remix/forks)

### Inferences
- For planning, treat "Remix" as two products. **1.5.2** is stable, with no NR, DLSS 4-era SR/RR and no Sparse Rendering. **Main** has NR, DLSS 4.5 and Sparse Rendering and is moving quickly. A YAE "PT + NR" prototype will have to build or pin a main snapshot until NVIDIA tags the next release; that next release is likely, but not confirmed, to carry DLSS-NR.
- Development is NVIDIA-driven and changes fast, at roughly 13 commits per week. Expect behaviour changes in camera, hashing and preserve-path logic between snapshots, so pin exact commits and re-test.
- Do not plan on RTX Mega Geometry or Neural Texture Compression arriving through Remix. Neither is in the code, and no announcement was found.

### Gaps
- No official NVIDIA blog or news item announcing DLSS-NR in Remix was found; the only evidence is the commit. No date for the next tagged release (1.6 or otherwise) was found.
- Exact publication date of the NVIDIA "Toolkit Open Source / REST API" article was not captured; the repo creation date is 2024-07-02.
- No Remix roadmap for Mega Geometry or NTC was found. The GitHub wiki roadmap is stale (see Q3).

## 2. Remix on AMD (RDNA2/3/4) and Intel Arc; upscaler/denoiser options; Linux/Proton; real-mod performance

### Takeaway
`dxvk-remix` does run on AMD RDNA2–4 through standard Vulkan RT, and the code contains AMD- and RADV-specific defaults. But every NVIDIA "multiplier" is vendor-locked: DLSS SR, RR, FG and NR, NRC, and Sparse Rendering (which needs RR). Non-NVIDIA cards are left with NRD, ReSTIR GI, RTXDI and XeSS 2.1 / TAA-U / NIS, with no native FSR. Big official mods (Portal RTX, HL2 RTX) run poorly on AMD, and RDNA2 has had regressions. Intel Arc is unreliable: PCGH reported on **2026-06-15** that HL2 RTX "does not run on Arc graphics cards with the current software version". The community route to FSR is OptiScaler hooking Remix's Vulkan DLSS calls, which works for SR but crashes with frame generation. Linux/Proton works on both vendors, with open sync bugs.

### Cited Findings
**What the runtime does per vendor** [code]
- Upscaler enum: `None, DLSS, NIS, TAAU, XeSS` — **no FSR** — [rtx_options.h](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_options.h)
- Indirect lighting modes: `ImportanceSampled`, `ReSTIRGI`, `NeuralRadianceCache` (default `rtx.integrateIndirectMode=2`, i.e., NRC) — [rtx_options.h](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_options.h), [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md)
- NRC is disabled when `vendorID != Nvidia`, and the code checks for driver ≥ 565.90 ("CUDA runtime in NRC SDK") — [rtx_nrc_context.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_nrc_context.cpp)
- The automatic graphics preset picks by vendor and architecture:
  - Any non-NVIDIA GPU → **Low** ("Default to low if we don't know the hardware").
  - NVIDIA pre-Turing → Low ("without HW RTX support"); Turing → Low; Ampere → Medium; Ada → High; Blackwell → Ultra.
  - [rtx_options.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_options.cpp)
- The automatic ray-trace mode follows the driver: NVIDIA, **RADV** and **AMD proprietary** get TraceRay for indirect integration with RayQuery for GBuffer and direct lighting; other vendors (e.g., Intel) get RayQuery for everything. This default came from a community commit, "Default to TraceRay on AMD Windows drivers" (KingVulpes, authored 2026-05-29, merged 2026-07-22) — [rtx_options.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_options.cpp); [commit 0557867](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/0557867a82eec4898fe44a5928480ad4329b16f9)
- Shader prewarming is force-disabled on AMD ("caused a deadlock on AMD in the past"). XeSS takes an "optimized" path on Intel (vendor 0x8086) and a "generic" path elsewhere. NIS selects AMD- or Intel-generic architectures — [rtx_initializer.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_initializer.cpp), [rtx_xess.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_xess.cpp), [rtx_nis.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_nis.cpp)
- `upscalerType` defaults to DLSS (1); `resetUpscaler()` sets DLSS and Reflex LowLatency. Sparse Rendering requires DLSS-RR (see Q1) — [rtx_options.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_options.cpp), [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md)

**Issue-tracker evidence (AMD / Intel / Linux)** [primary unless noted]
- #503 (2024-05-08): "Poor performance on RDNA 2 (Windows) with Remix 0.4 and newer … reduced by approximately 2-3x" (RX 6700); downgrading to 0.3 restored it. NVIDIA replied that newer features raise cost — [issue #503](https://github.com/NVIDIAGameWorks/rtx-remix/issues/503)
- #765 (2025-03-18): "HL2: RTX Poor AMD performance" (RX 9070 XT). The reply cites DSOGaming: the 9070 XT is "matching a 7900 XTX in performance without upscaling" — [issue #765](https://github.com/NVIDIAGameWorks/rtx-remix/issues/765)
- #914 (2025-09-21, **still open**): "Artifacts and heavy slowdown on RDNA 2 GPUs when running Remix 1.2.4". On an RX 6700 XT, the frame rate fell below 10 fps once replacement assets loaded — [issue #914](https://github.com/NVIDIAGameWorks/rtx-remix/issues/914)
- #582 "Portal RTX memory crash on AMD" (2024); #814 "Driver timeout on AMD" (2025-04); #791 "RTX IO poor performance on AMD GPUs" (2025-03); #549 Sonic Adventure DX RTX graphical issue on 7900 XTX (2024, open) — [issues](https://github.com/NVIDIAGameWorks/rtx-remix/issues?q=AMD)
- #651 (opened 2024-10-13, closed 2026-05-28): a user asks NVIDIA to add AMD equivalents to the Portal RTX requirements. The post quotes the official list as min RTX 3060 / recommended RTX 3080 / ultra RTX 4080 and proposes RX 7700 XT (min) and RX 7900 XTX (recommended) — [issue #651](https://github.com/NVIDIAGameWorks/rtx-remix/issues/651) [forum-level proposal]
- #964 (2026-01-20) "add FSR 3.1 Upscaler" ("i only saw 4 upscalers 'DLSS, NIS, TAA-U, XESS'"). Closed 2026-04-06 with state "completed" and no comment, yet main still has no FSR (code check 2026-10-07) — [issue #964](https://github.com/NVIDIAGameWorks/rtx-remix/issues/964)
- Linux:
  - #1101 (2026-09-30, open): Portal with RTX on Linux with GE-Proton 11-7 and an RTX 5080. With HAGS reported, DLSS-FG hangs at startup because "WDDM binary semaphores behave like monitored fences" but Linux binary waits consume signals. Also, "Reflex sleep causes a 500 ms stall per frame via dxvk-nvapi". NVIDIA filed REMIX-6202 on 2026-10-05 — [issue #1101](https://github.com/NVIDIAGameWorks/rtx-remix/issues/1101)
  - #1029 (2026-04-27 → closed 2026-07-06): RX 7900 XTX on Linux crashes with the P2-RTX compatibility fork. NVIDIA: HL2 and Portal "are working fine with Remix on main"; the P2-RTX fork does not support Linux — [issue #1029](https://github.com/NVIDIAGameWorks/rtx-remix/issues/1029)
  - #885 (2025-08-05, open): HL2 RTX and Portal RTX hang on Linux or crash on Windows at start. #696 (2025-01): Steam Deck performance regression — [issue #885](https://github.com/NVIDIAGameWorks/rtx-remix/issues/885), [issue #696](https://github.com/NVIDIAGameWorks/rtx-remix/issues/696)
  - Phoronix (December 2022): "RADV Vulkan Driver Making Progress On Portal RTX Support" — [press] [Phoronix](https://www.phoronix.com/news/RADV-Portal-RTX-Progress)

**Performance and compatibility of real mods**
- HL2 RTX demo (DSOGaming, 2025-03-18; 7950X3D; RX 6900 XT / 7900 XTX / 9070 XT; RTX 2080 Ti / 3080 / 4090 / 5080 / 5090): "to play at native 1080p, you'll need an NVIDIA RTX 5090". HL2 RTX "supports DLSS 4, but there is no support for AMD FSR 3.0 or Intel XeSS" (XeSS reached Remix later, in 1.3.6). Per-GPU numbers were in charts and not extracted — [press] [DSOGaming](https://www.dsogaming.com/pc-performance-analyses/half-life-2-rtx-demo-path-tracing-dlss-4-benchmarks/)
- NVIDIA (2025-03-18): HL2 RTX at 4K Ultra on an RTX 5090 reaches 265 fps with DLSS 4 MFG ("10.2X on average"); NRC "runs up to 15% faster" — [primary] [NVIDIA](https://www.nvidia.com/en-us/geforce/news/rtx-remix-half-life-2-rtx-demo-launching-march-18/)
- GameGPU HL2 RTX test (March 2025): AMD was run with **TAA-U**, and "FSR is not supported in the game". Per-GPU numbers sit in dynamic charts and were not extracted — [press] [GameGPU](https://en.gamegpu.com/action-/-fps-/-tps/half-life-2-rtx-test-gpu-cpu)
- **PCGH, 2026-06-15:** "Half-Life 2 RTX does not run on Arc graphics cards with the current software version, so we have excluded the game from this test." — [press] [PCGH "Building an Arc B780"](https://www.pcgameshardware.de/Arc-Pro-B70-Grafikkarte-284242/Tests/Building-an-Arc-B780-Can-We-Beat-the-RTX-5070-and-RX-9070-1545269/4/)
- PCGH's path-tracing index (2025-03-05) includes Portal RTX, Half-Life: Ray Traced and Quake 2 RTX among the PT titles. Numbers were not extracted — [press] [PCGH](https://www.pcgameshardware.de/Radeon-RX-9070-XT-Grafikkarte-281023/Tests/Preis-Test-kaufen-Release-Specs-Benchmark-1467270/5/)
- [forum] Steam, 2025-03-21: on an Arc B580, HL2 RTX "gets stuck after processing exactly 720 meshes"; an Arc A750 user says it "loads and runs at about 17fps or so"; OptiScaler is suggested — [Steam thread](https://steamcommunity.com/app/2477290/discussions/0/600773581355412586/)
- [forum] A search snippet attributed to HL2 RTX Steam discussions reports "50-80fps on a 9070XT on Linux without frame generation, using alternative upscalers", plus a patch that stopped the game loading on AMD. The exact thread was not verified — [Steam discussions](https://steamcommunity.com/app/2477290/discussions/0/569248085326218960)
- HL2 RTX minimum GPU is reported as an RTX 3060 Ti — [press] [TheFPSReview 2025-03-18](https://www.thefpsreview.com/2025/03/18/half-life-2-rtx-remix-demo-releases-to-mixed-reviews-with-praise-for-its-visual-upgrades-but-yet-another-remix-that-requires-a-high-end-gpu/)

**Community upscaler route for AMD/Intel (OptiScaler on Remix's Vulkan DLSS)**
- [forum] Steam guide, 2025-05-10, for HL2 RTX on AMD:
  - Put OptiScaler as `winmm.dll` in `bin\.trex`, with "use DLSS inputs" = Yes.
  - Set `VulkanUpscaler=fsr31` (XeSS is the alternative) and `[Spoofing] VulkanExtensionSpoofing=true`.
  - The OptiScaler overlay does not show.
  - [Steam guide](https://steamcommunity.com/app/2477290/discussions/0/600778161129549839/)
- OptiScaler wiki, "RTX Remix Games" page (last edited 2026-09-25): Portal Prelude RTX on an **RX 9070 XT**; upscaler inputs "DLSS, XeSS (Update RTX Remix)"; frame generation "Crashes when attempting to Enable"; "FSR 4 VK w/DX12 seems to run fine with little overhead"; menu overlay does not show — [community wiki] [OptiScaler wiki](https://github.com/optiscaler/OptiScaler/wiki/RTX-Remix-Games)
- OptiScaler FSR4 list: "FSR4 doesn't officially support Vulkan or DX11 yet" — so FSR4 in Vulkan Remix runs through OptiScaler's DX12 interop — [community wiki] [FSR4 Compatibility List](https://github.com/optiscaler/OptiScaler/wiki/FSR4-Compatibility-List)

### Inferences
- On AMD and Intel, Remix costs the full raw path-tracing price. It has no RR (whose denoising also allows lower sample counts), no NRC (shorter paths), no Sparse Rendering and no frame generation. That is why heavy official mods are borderline even on an RX 9070 XT.
- YAE with its *original* 2006 assets — low poly counts, few emissive sources, no 4K PBR replacements — should be far lighter than HL2 RTX. Expect resolution and bounce count to dominate the cost. This is unmeasured.
- RDNA2 is risky: there is a 2–3× regression since 0.4 and an open artifact/slowdown bug on 1.2.4. RDNA3 and RDNA4 look viable, especially with the TraceRay default from 2026-07.
- Intel Arc should be treated as "may not start" until tested on the exact runtime snapshot. The Arc-specific failures are a hang at mesh processing (2025) and a non-start reported by PCGH (2026-06).
- The OptiScaler route gives FSR 3.1, FSR4 (through DX12 interop) or XeSS 2 on AMD. It is not a substitute for DLSS-RR, so NRD stays the denoiser, and FG through OptiScaler currently crashes in Remix.

### Gaps
- No reliable published per-GPU FPS numbers (RTX 3060, RX 7800 XT, RX 9070, Arc B580) were found for any Remix title in 2026. The press tables found keep their numbers in non-extractable charts (GameGPU, PCGH, DSOGaming, hwcooling.net April 2024).
- No measured gain from the 2026-07 AMD TraceRay default.
- No official NVIDIA statement on AMD or Intel support for Remix runtime 1.x was found.
- No FSR in official Remix, and the reason issue #964 was closed is unknown.

## 3. OpenGL games under Remix: wrappers, notable projects, what they solved, blockers

### Takeaway
Remix accepts only D3D9 (plus D3D8 through d3d8to9), so OpenGL games need a GL→fixed-function-D3D9 wrapper. In practice that means **QindieGL**: XaeroX's 2016 rev5, carried forward mainly by **whisperglen's RTX-Remix fork** (v1.2.2, 2026-09-27), from which `yae-QindieGL` descends. The hard problems are engine-specific:
- separating camera, view and model matrices so Remix gets a stable world-space camera;
- stable geometry hashes for immediate-mode and streamed geometry;
- UI and orthographic classification;
- normals;
- converting lights.

NVIDIA explicitly rejected building GL support (for example through Zink) into Remix in February 2026. The other proven routes are engine-side: writing a D3D9 renderer, or calling the Remix API directly.

### Cited Findings
**NVIDIA's position**
- "RTX Remix functions as a replacement for DirectX 9 and doesn't directly support OpenGL or older DirectX versions." "Wrapper libraries can translate older OpenGL or DirectX 8 games to fixed function DirectX 9." "A list of available wrappers is maintained in the following Discord thread." — [primary] [docs: Game Compatibility](https://docs.omniverse.nvidia.com/kit/docs/rtx_remix/latest/docs/introduction/intro-compatibility.html)
- The wiki says wrappers "have been effectively used to get Remix working with several games"; NVIDIA is "not currently aware of any wrapper libraries for DirectX 7 to fixed function DirectX 9"; D3D8 is supported through d3d8to9 — [primary] [wiki Compatibility](https://github.com/NVIDIAGameWorks/rtx-remix/wiki/Compatibility), [wiki Runtime User Guide](https://github.com/NVIDIAGameWorks/rtx-remix/wiki/runtime-user-guide)
- **Superseded:** the GitHub wiki Roadmap (written in the 2023 era; wiki last committed 2025-10-07) lists "OpenGL Support: Looking for a preferred OpenGL wrapper, and to then add support for some OpenGL game specific idioms like DrawPrimitiveUP vertex batching" — [wiki Roadmap](https://github.com/NVIDIAGameWorks/rtx-remix/wiki/Roadmap). This is contradicted by issue #978 (2026-02-09): a request to integrate Mesa's **Zink** for OpenGL was closed by NVIDIA as "outside of the scope of the Remix project; Zink support would require rewriting effectively all of the Remix code." — [primary] [issue #978](https://github.com/NVIDIAGameWorks/rtx-remix/issues/978)

**QindieGL lineage and what the Remix fork solves**
- QindieGL is an OpenGL→D3D9 emulator for GL up to about 1.4 ("no shaders, vertex buffer objects" in the original), by XaeroX (rev5, 2016) — [code] [whisperglen/QindieGL README](https://github.com/whisperglen/QindieGL)
- whisperglen's fork ("with a focus on RTX-Remix Compatibility"; 19★; pushed 2026-09-30):
  - **idTech3 camera hack:** RTCW keeps the camera and the modelview in two globals, so "the model matrix can be obtained by multiplying modelview * camera-inverse".
  - **idTech2:** the game builds the camera with glRotate/glTranslate and then reads it back, so the readback "(getvalue)" is used as the trigger that marks the camera matrix.
  - "Stabilising geometry hashes for remix is integrated as a beta for FAKK2, and partially for CoD, Alice."
  - Tested with Alice, CoD 2003, FAKK2, EF2, OpenJK, Quake2 and Heretic2.
  - "RTSS interferes … add NvRemixBridge.exe to the exception list".
  - The game may not load a local `opengl32.dll` "due to GPU driver app interference: Rename the executable".
  - [code] [README](https://github.com/whisperglen/QindieGL)
- Fork history, 2025-01 → 2026-09: idTech2 matrix detection and an S3TC fix (2025-02-16); surface sorting for stable hashes in idTech3 (2025-02-16); homogeneous vertex coordinates (2025-03-11); texture transforms for Doom3 and a "NormalPointer hack" (2025-04-07); "use vertexbuffers for GL immediate mode" (2025-04-30); Heretic2 hash stabilisation, model normals and "add remix lights" (2025-07/08) — [code] [commit history](https://github.com/whisperglen/QindieGL/commits)
- Releases v1.1.6 (2025-04-07) → **v1.2.2 (2026-09-27)**. v1.2.2 "Contains changes used by the Alice1 HD Remix mod": ImGui visualisation of camera detection, a clip-plane fix under camera detection, per-game preferred camera addresses and engine config pointers, fallback light direction, and precompiled ortho shaders — [primary] [release v1.2.2](https://github.com/whisperglen/QindieGL/releases/tag/v1.2.2)
- whisperglen's other Remix routes are mostly engine-side, needing source or deep RE:
  - "RTCW-SP: An attempt to add DirectX9 renderer"; "FTEQW for DX9"; "Quake3e … modified for RTX Remix"; "Quake-2: Mod idtech2 for better RTX-Remix compatibility".
  - **"D3D9DrvRTX: Unreal Engine 1 RTX Remix Render Device"**; "WhiteRabbit-renderer" (the AMG Alice HD renderer as a DLL); "remix-comp-wolf2009".
  - [code] [whisperglen repositories](https://github.com/whisperglen?tab=repositories)
- Forks of whisperglen/QindieGL: OpenYAE/yae-QindieGL (pushed 2026-10-05), zakklotz, michaelabilliot — [code] [forks](https://github.com/whisperglen/QindieGL/forks)

**Other notable OpenGL / non-D3D9 → Remix cases**
- KOTOR (OpenGL) through QindieGL 1.0 rev5 (2023-12-30): Remix loaded only once; NVIDIA fixed this in Bridge main (REMIX-2550, 2024-01-30) — [primary] [issue #289](https://github.com/NVIDIAGameWorks/rtx-remix/issues/289); [forum] [Deadly Stream thread](https://deadlystream.com/topic/10953-kotor-rtx-remix/)
- Hitman: Codename 47 (GOG, OpenGL) access violation in `dxso.cpp` (2023-06) — [primary] [issue #209](https://github.com/NVIDIAGameWorks/rtx-remix/issues/209)
- GTA 2: modder gebdag built a **custom Direct3D 9 renderer** bridging the game to Remix (full PT and dynamic time-of-day) — [press] [Tom's Hardware](https://www.tomshardware.com/video-games/pc-gaming/27-year-old-gta-2-gets-full-path-tracing-and-60-fps-frame-generation-via-rtx-remix-custom-direct3d-9-wrapper-modernizes-classic-with-custom-direct3d-9-bridge-unlocks-dynamic-lighting) (article body not retrievable; the details come from the headline and search summary)
- Doom 3 (OpenGL): no Remix route; Remix "Doom 3 (2004) Black screen with UI" (issue #191). The community instead built a dhewm3 fork with an OpenGL 3.3 core and a Vulkan 1.4 hardware-RT backend (2026-08-21) — [primary] [issue #191](https://github.com/NVIDIAGameWorks/rtx-remix/issues/191); [press] [iXBT](https://ixbt.games/en/news/2026/08/21/vysel-fanatskii-rtx-remaster-doom-3-s-vulkan-i-ulucsennoi-grafikoi.html)
- Compatibility-mod template for shader-based D3D9 games: xoxor4d's `remix-comp-base` offers "a hooked D3D9 interface, with every function detoured", drawcall-modification logic and an ImGui menu. It is "not a generic fix". The same author ships GTA IV (779★), Portal 2, L4D2, NFS Carbon and CoD4/WaW compatibility mods — [code] [remix-comp-base](https://github.com/xoxor4d/remix-comp-base), [xoxor4d repos](https://github.com/xoxor4d?tab=repositories)

**Remix-side knobs and fixes that matter for wrapped GL games** [code] [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md)
- UI classification:
  - `rtx.orthographicIsUI` (default True): orthographic draw calls are treated as UI.
  - `rtx.uiTextures`: screen-space UI "rasterized on top of the ray traced scene".
  - `rtx.worldSpaceUiTextures`.
  - The 2026-06-30 fix for pre-transformed-vertex UI.
- Camera and transforms:
  - `rtx.fusedWorldViewMode`: "Set if game uses a fused World-View transform matrix".
  - `rtx.useWorldMatricesForShaders`.
  - `rtx.useVertexCapture` (captures VS-output positions) and `rtx.useVertexCapturedNormals`.
  - `rtx.useVertexCapturedTexcoords` (added 2026-07-16).
- Instance and hash stability:
  - `rtx.enableAlwaysCalculateAABB` ("may improve instance tracking across frames for skinned and vertex shaded calls").
  - Preserved static draw calls (2026-06).
  - Texture-hash invalidation on write lock (2026-06).
- Geometry and lighting quality:
  - Smooth normals for geometry without normals (1.5).
  - Vertex colour as baked lighting heuristic (1.3.6) and `rtx.ignoreAllVertexColorBakedLighting` (1.2.4).
  - `rtx.ignoreTextures` to drop draws.

### Inferences
- YAE's fork already tackles the canonical OpenGL-under-Remix problems: camera/view split exposed as `D3DTS_VIEW`, a camera census, ProjectionFix, lights, exposure, and the bridge's CPU affinity. It is in line with the community state of the art (whisperglen); there is no better off-the-shelf GL wrapper.
- The remaining classic blockers for a DS2-like engine are the following (inferred from the knobs above and the QindieGL notes):
  1. Draws that go through ARB vertex programs (for example GPU skinning). They depend on Remix vertex capture, and hashes change with animation.
  2. Streamed or dynamic geometry and render-to-texture, which destabilise hashes for asset replacement.
  3. Multi-pass lighting and lightmap passes, which Remix should ignore or tag.
  4. Stencil/projected shadows and post effects, which must be dropped.
- A higher-effort but more controllable alternative is to hook `ds2render.dll` and drive the **Remix API** directly through the bridge (camera, meshes, lights, per-material NR masks), skipping GL→D3D9 translation for the 3D world. The SDK is "under development", so pin versions.

### Gaps
- The Discord-maintained wrapper list could not be read; no other actively maintained GL→D3D9 wrapper for Remix was identified besides QindieGL forks.
- No public postmortem was found on specific RE-only (no-source) OpenGL titles brought to Remix, beyond the QindieGL fork notes and KOTOR/Hitman issue reports.

## 4. Alternatives to Remix without engine source (and source-port RT for comparison)

### Takeaway
Without engine source there are only two practical families.
1. **Remix-style API interception** — RTX Remix itself through QindieGL.
2. **Screen-space "ray tracing" post effects in ReShade** — iMMERSE Pro RTGI, LumeniteFX RTAO/SSSR and similar. These are cross-vendor and cheap, and they work on the existing ReShade x86 chain. But they only see the depth buffer and the final image: no off-screen geometry, no real light transport.

All real path-tracing ports — RTGL1 (Serious Sam TFE RT, Half-Life RT, PrBoom RT, vkQuake RT), Quake II RTX, the Doom 3 dhewm3 RT fork — require engine source. RTGL1 has been dormant since 2023, and Q2RTX had its "final official release" on 2025-12-11. No maintained generic Vulkan-layer or DXVK-based RT injector for non-D3D9 games was found.

### Cited Findings
**ReShade-based (no source needed)**
- iMMERSE Pro: RTGI (Pascal Gilcher / "Marty McFly") is a ray-traced GI shader for "diffuse global illumination and ambient occlusion", with an "RTGI Specular" companion for glossy reflections. iMMERSE is free on GitHub; iMMERSE Pro is Patreon-only. The site says the RTGI shader was "adopted by NVIDIA … added to the NVIDIA driver" — [primary] [Marty's Mods guide: RTGI Diffuse](https://guides.martysmods.com/shaders/immersepro/rtgidiffuse/), [RTGI Specular](https://guides.martysmods.com/shaders/immersepro/rtgispecular/), [martysmods.com](https://www.martysmods.com/)
- LumeniteFX (umar-afzaal; 155★; pushed 2026-10-05):
  - "Kernel" pre-pass for "Reconstructed Normals, Motion vectors".
  - "RTAO/LSAO — Screen-space ray traced Ambient Occlusion"; "SSSR — Stochastic Screen Space Reflections".
  - "LumaFlow — Dense Real-time Motion Estimation" (motion vectors "for TAA, frame generation, temporal reprojection").
  - No GI path tracer is listed.
  - [code] [LumeniteFX README](https://github.com/umar-afzaal/LumeniteFX)
- The YAE DLSS 5 package already runs `Lumenite_Kernel` before `DLSS5_Feed` in ReShade x86 (pinned ReShade 6.8.0.2156) — [code] [yae-dlss5 ReShadePreset.ini](https://github.com/OpenYAE/yae-dlss5/blob/main/payload/ReShadePreset.ini), [VERSIONS.txt](https://github.com/OpenYAE/yae-dlss5/blob/main/VERSIONS.txt)

**Source-port RT (engine source required; for comparison)**
- sultim-t's RayTracedGL1 (MIT): last release v2.0.1 (2022-10-01), `hl1-dev` pre-release (2023-02-05), repo last pushed 2023-12-02. Ports:
  - Serious-Engine-RT (GPL-2.0): "Serious Sam TFE: Ray Traced. Update 1.5: AMD" (2022-04-20).
  - prboom-plus-rt: 1.0.6 (2022-04-21) and 1.0.7 pre-release (2022-04-26).
  - xash-rt (Half-Life, 1180★): pushed 2023-08-26.
  - vkquake-rt (GPL-2.0): pushed 2023-02-24.
  - [code] [sultim-t repositories](https://github.com/sultim-t?tab=repositories), [Serious-Engine-RT releases](https://github.com/sultim-t/Serious-Engine-RT/releases)
- Half-Life: Ray Traced "hasn't been tested on AMD GPUs" (at release) — [press] [80.lv](https://80.lv/articles/sultim-t-releases-a-ray-traced-version-of-the-first-half-life)
- RTGL1's author Sultim Tsyrendashiev now appears as a regular dxvk-remix committer (e.g., "Update USD to 25.11", 2026-07-29; "Allow view model flag to be passed through RemixAPI", 2026-07-24) — [code] [commits](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main)
- Quake II RTX: v1.8.0 (2025-03-26, maintenance) and **v1.8.1 (2025-12-11): "This is the final official release of Quake II RTX."** — [primary] [Q2RTX releases](https://github.com/NVIDIA/Q2RTX/releases)
- Doom 3 fan RT remaster: a dhewm3 fork with "OpenGL 3.3 core and Vulkan (1.4, with hardware ray tracing where available)" (2026-08-21) — [press] [iXBT](https://ixbt.games/en/news/2026/08/21/vysel-fanatskii-rtx-remaster-doom-3-s-vulkan-i-ulucsennoi-grafikoi.html)

**API coverage of Remix-like interception**
- Remix is D3D9 only. Zink/OpenGL was refused (2026-02-09). D3D11 titles such as Titanfall 2 are being made compatible only by "converting these to a fixed-function pipeline", which NVIDIA calls "a difficult, time-consuming process" (2026-06-16) — [primary] [issue #978](https://github.com/NVIDIAGameWorks/rtx-remix/issues/978), [NVIDIA 1.5 article](https://www.nvidia.com/en-us/geforce/news/rtx-remix-agent-skills-update/)

### Inferences
Pros and cons for a closed-source game with only RE notes:
- **Remix (via QindieGL).** The only route here to real world-space path tracing, PBR asset replacement and DLSS-RR/NR integration. Costs: per-engine wrapper work (camera, hashes, UI); RT hardware needed; strongly NVIDIA-tilted on performance; an extra x86→x64 bridge process.
- **ReShade screen-space GI/AO/SSR.**
  - For: works today on every vendor; reuses the existing ReShade x86 + depth setup of the DLSS 5 package; minimal RE effort.
  - Against: limited to screen space, so lighting changes as objects leave the view, nothing appears behind the camera, and actual light sources are not modelled.
  - Best seen as a "lite" tier, or a complement on non-RT GPUs.
- **Source-port style RT** (RTGL1, Q2RTX-like) is not available without source. For YAE that path effectively *is* the project's own YAE Engine reimplementation, which another researcher covers. RTGL1 itself is dormant, so it is a design reference rather than a dependency.
- Since Remix's renderer can be driven through its C API, the "YAE Engine + Remix API" idea is a hybrid worth noting: a source-available renderer could submit to Remix instead of writing its own PT. That is outside this brief's original-game scope.

### Gaps
- No currently maintained generic geometry-capture or Vulkan-layer RT injector for OpenGL or D3D11 games was found. Searches surfaced only ReShade screen-space shaders and engine ports.
- The current iMMERSE Pro RTGI version, its cost figures and its 2026 changes were not found.

## 5. Combining path tracing and DLSS 5 Neural Rendering on the original game

### Takeaway
The best answer is now **inside Remix itself**. Since 2026-09-18, `dxvk-remix` main runs DLSS 5 NR ("DLSS 3D-Guided Neural Generation [Experimental]") as a native pass with these properties:
- **It runs after Remix's own denoise and upscale and before bloom, tone mapping and the game's rasterized UI**, so the HUD is never processed.
- It is fed **Remix's own motion vectors and depth** (the RR guide buffers when DLSS-RR is active).
- It exposes NVIDIA's controls: model A/B/C, intensity, structure and tone strengths, auto mask, and a per-material control mask in MDL and Remix API 0.6.5.

A community fork (lunks, 2026-08-29) and a Portal RTX demo report (2026-08-30) preceded it. GPU coverage is governed by NGX:
- officially RTX 50 since 2026-09-03, with RTX 40 "later this fall";
- unofficially RTX 40 (patched leaked DLL) and RTX 20/30 (FP16 fallback, slow, artifacts).

AMD has only community re-implementations: ReShade/OptiScaler add-ons running a port of the network through HIP or Vulkan. These could in principle be swapped into Remix's NR call site, but nobody has reported doing it. The project's current external chain (ReShade x86 → DLSS5-Feeder → host64 → OptiScaler_DLSSNR) cannot see Remix's pixels, because Remix renders in the 64-bit bridge server.

### Cited Findings
**Native DLSS-NR in dxvk-remix main** [code] [commit ecf646d, 2026-09-18](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/ecf646d3ea97b1e81e450993f414a2ae31b71d3b)
- New options:
  - `rtx.dlssNeuralRendering.enable` (default False).
  - `intensity` (1.0), `structuralStrength` (0.7), `toneStrength` (0.3).
  - `model` ("three … model variants … 0: Model A, 1: Model B, 2: Model C").
  - `useAutoMask` ("automatic character mask instead of the material control mask") and `skinStructureStrength` (0.5).
  - `enableHighlightRecovery` ("Recover highlights compressed by … LDR-domain processing") and `enableVolumetricControlMask` (fog, volumetrics and alpha-blended transmittance modulate the mask).
  - The ImGui section reads "DLSS 3D-Guided Neural Generation [Experimental]" and is shown only if NGX reports support.
  - [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md)
- Pass order in `RtxContext::injectRTX`: demodulate → **denoise** (NRD or RR) → composite → upscaler (DLSS / DLSS-RR / XeSS / NIS / TAA-U) → dust particles → **`dispatchDlssNR`** → bloom → motion blur ("still in linear HDR") → tone mapping → lens effects → sRGB/dither → debug view → **DLFG** → blit to the game target — [rtx_context.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_context.cpp)
- "DLSS-NR operates in SDR space; inverse tone mapping restores HDR for downstream post-processing": a fast tone-map runs before NR and an inverse tone-map after it. When DLSS-RR is the active upscaler, the pass uses the RR guide buffers for motion vectors and depth (`useRayReconstructionGuides`), with "motionVectorScale 1,1" in render-pixel units — [commit ecf646d](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/ecf646d3ea97b1e81e450993f414a2ae31b71d3b)
- Per-material control:
  - The MDL `AperturePBR_Opacity.mdl` gains `enable_dlss_control_mask`, `dlss_control_mask_intensity` and tone/structure strengths.
  - Material data packs a "cachedDLSSControlMask".
  - The composite pass writes a `COMPOSITE_DLSS_NR_CONTROL_MASK_OUTPUT`.
  - Remix API 0.6.5 exposes the same fields.
  - [commit ecf646d](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/ecf646d3ea97b1e81e450993f414a2ae31b71d3b), [RemixApiChangelog.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/documentation/RemixApiChangelog.md)
- Build and runtime:
  - The NR headers (`nvsdk_ngx_defs_dlssnr.h`, `nvsdk_ngx_helpers_dlssnr_vk.h`, i.e., a **Vulkan** NGX helper) come from a packman package `rtx-remix-ngx_sdk_dlnr`.
  - Support is probed through NGX; failures call `disableAfterFailure(...)`.
  - An exported `remixinternal_GetDlssNeuralRenderingStatus()` reports −1/0/1.
  - x64 only at first; arm64 enabled 2026-09-29.
  - [commit ecf646d](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/ecf646d3ea97b1e81e450993f414a2ae31b71d3b), [commit 5229c04](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/5229c042a13a4daa63a4575894c27dc5cd705334)
- The UI is outside the NR pass by construction: draws classified as UI (orthographic with `rtx.orthographicIsUI`, or textures in `rtx.uiTextures`) are `RtxGeometryStatus::Rasterized`, and "UI rendering detected ⇒ trigger RTX injection". The path-traced and NR-processed frame is therefore composited into the render target *before* the UI is rasterized on top — [d3d9_rtx.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/d3d9/d3d9_rtx.cpp), [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md)
- Remix can also render its ImGui GUI to separate output buffers for external presenters (2025-11-13; option added 2026-07-15) — [commit 357c6ff](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/357c6ff1e7d952131cf5c11d99f37012bfa15a65), [commit 4498eba](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/4498eba0065206fe03810c711fc7a876bfa0ce36)

**DLSS 5 official context**
- DLSS 5 ("3D-Guided Neural Rendering") shipped **2026-09-03 in NBA 2K27** for GeForce RTX 50 desktop and laptop GPUs and GeForce NOW — [press] [Club386](https://www.club386.com/nvidia-dlss-5-release-date/)
- Per NVIDIA, RTX 40 support comes after RTX 50 tuning: "Once RTX 50 Series performance is more fully tuned, NVIDIA plans to work on expanding official support to the GeForce RTX 40 Series" (2026-09-04) — [press] [DSOGaming](https://www.dsogaming.com/news/nvidia-promises-dlss-5-support-for-rtx-40-series-gpus-in-the-future/)
- NVIDIA developer blog (2026-09-22): DLSS 5 is "a final neural-rendering stage" on "a strict one-frame-in, one-frame-out model with game-engine motion vectors", running "locally on a single GeForce RTX 50 Series GPU at up to 4K". Controls: model selection, Structure and Tone Intensity, "semantic AI masking", and engine-level masking — [primary] [NVIDIA Developer blog](https://developer.nvidia.com/blog/whats-new-for-game-developers-dlss-5-with-3d-guided-neural-rendering-nvidia-ace-updates-and-new-rtx-kit-capabilities/)

**Community DLSS 5 + Remix, and GPU coverage**
- Fork `lunks/dxvk-remix-plus-dlssnr`, branch `dlssnr`: "Add DLSS-NR (NGX feature 18) neural rendering pass" (2026-08-29), on top of Kim2091's fork — [code] [branch dlssnr](https://github.com/lunks/dxvk-remix-plus-dlssnr/tree/dlssnr)
- GameGPU (2026-08-30), "Modders have enabled DLSS 5 technology in Portal RTX using the RTX Remix utility":
  - Method: "transfer the prepared DLL files to … .trex", plus a Python script to patch DLLs; enable it under "post-processing and neural rendering".
  - Works on Ada; RTX 20/30 "lack … hardware support for FP8 … sharp drop in frame rate and … visual artifacts".
  - [press] [GameGPU](https://en.gamegpu.com/news/igry/moddery-zapustili-tekhnologiyu-dlss-5-v-portal-rtx-s-pomoshchyu-utility-rtx-remix)
- Leaked `nvngx_dlssnr.dll` from the NBA 2K27 early-access build was patched for Ada by "RTX Remix modder Uncle Burrito", who replaced Blackwell-only CUDA binaries. Reported cost: RTX 4090 at 135 → 82 fps — [press] [Tom's Hardware (exclusive)](https://www.tomshardware.com/pc-components/gpus/exclusive-dlss-5-has-already-been-ported-to-work-on-rtx-4000-series-graphics-cards-incompatible-cuda-instructions-get-patched-to-work-on-previous-gen-hardware), [VideoCardz](https://videocardz.com/newz/leaked-dlss-5-already-working-with-rtx-40-series). Article bodies were not retrievable; details come from search summaries.
- `dev-camo/dlssnr-patcher` (created 2026-08-29) patches a user's own `nvngx_dlssnr.dll` for RTX 20/30/40 using CUDA Toolkit 13.3 (`ptxas`, `fatbinary`, `cuobjdump`) and warns that it "invalidates its NVIDIA digital signature" — [code] [README](https://github.com/dev-camo/dlssnr-patcher)
- DLSS5oneclick README (2026-10): "the DLSS 5 model is FP8 with RTX-50-only kernels; the `310.8.SF` build … adds patched binaries for RTX 40 and an FP16 path for RTX 20/30". Tiers: "RTX 50 full speed · RTX 40 moderate cost · RTX 20/30 heavy cost". It also notes that for Vulkan games "ReShade reaches Vulkan through a registered layer", and "the OptiScaler engine does cover Vulkan, for games that ship their own DLSS" — [forum/tool README] [faisalkindi/DLSS5oneclick](https://github.com/faisalkindi/DLSS5oneclick)
- Note: many GitHub repos found with names like "AMD-NR-DLSS5", "OptiScaler-DLSS-5 … Official free download" use lure-style descriptions and should be treated as untrustworthy — [code] `gh search repos dlss5` (2026-10-06)

**External (post-process) NR chains and Remix**
- The OptiScaler DLSS-NR fork bundled by yae-dlss5 says it runs "Immediately after the game's upscaler, on the same command list, before the interface is drawn"; it reads the depth and motion vectors "the game already hands to DLSS"; "Native Vulkan is supported too"; it needs "An RTX 50 series card" with the unpatched model — [code] [yae-dlss5 payload README](https://github.com/OpenYAE/yae-dlss5/blob/main/payload/host64/READ%20ME%20-%20DLSS%20Neural%20Rendering.txt)
- The current YAE NR chain: ReShade x86 6.8.0.2156 → DLSS5-Feeder 1.16.0-beta.6 (protocol v10) → host64/D3D12 → OptiScaler DLSS-NR 0.2.0 with `nvngx_dlssnr.dll` 310.8.0.0, tested on an RTX 5090 with driver 616.92 — [code] [yae-dlss5 VERSIONS.txt](https://github.com/OpenYAE/yae-dlss5/blob/main/VERSIONS.txt), [README](https://github.com/OpenYAE/yae-dlss5/blob/main/README.md)
- Remix bridge architecture: "the client side d3d9 … intercepting all the DirectX9 API calls from the 32-bit game/app, and the server side NvRemixBridge.exe receives those calls and executes them in 64-bit process" — [primary] [bridge-remix README](https://github.com/NVIDIAGameWorks/bridge-remix), [bridge/README.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/bridge/README.md)
- ReShade attaches to Remix titles through the **Vulkan implicit layer**. A Portal RTX crash with ReShade 6.3–6.4 on an RTX 5090 was fixed by ReShade commit `eb08468` ("I can confirm that is in fact fixed") in a thread from about mid-2025 — [forum] [ReShade forum](https://reshade.me/forum/troubleshooting/9993-solved-portal-rtx-crashes-when-reshade-is-enabled)
- OptiScaler loads inside Remix titles as `winmm.dll` in `.trex` and hooks the DLSS inputs on Vulkan (HL2 RTX 2025-05; Portal Prelude RTX 2026-09) — [forum] [Steam guide](https://steamcommunity.com/app/2477290/discussions/0/600778161129549839/), [OptiScaler wiki](https://github.com/optiscaler/OptiScaler/wiki/RTX-Remix-Games)
- Post-UI NR shows HUD problems: "DLSS 5 Swapper Improves Half-Life 2 Lighting, Adds HUD Artifacts" (headline; body not retrievable) — [press] [WindowsForum](https://windowsforum.com/news/dlss-5-swapper-improves-half-life-2-lighting-adds-hud-artifacts.446057/)

**AMD neural-rendering add-ons (not NVIDIA)**
- `zmodelerlover/dlss5-neural-amd` (created 2026-09-09; 104★):
  - A ReShade add-on that "drives the AMD port of the same network" (danielblnc's DLSS-NR-on-AMD).
  - GPUs: RDNA2/3/4 with the HIP 7 runtime; RX 6000 needs the HIP SDK 7.2. "Does nothing on NVIDIA or Intel."
  - APIs: "Direct3D 11 works best … Direct3D 10, Vulkan and OpenGL are experimental. 32-bit games are experimental: Direct3D 8, 9, 10 and 11, and OpenGL." "On D3D10, Vulkan and OpenGL, and on 32-bit D3D9 games, it only receives the final image" (it estimates motion by optical flow).
  - Alternative runtime: mochizuki0323's Vulkan port, which uses RDNA4 FP8. Measured on an RX 9070 XT at 960×540: "6.8 ms for one pass, 11.7 ms for two, 17.3 ms for three".
  - [forum/tool README] [dlss5-neural-amd](https://github.com/zmodelerlover/dlss5-neural-amd)
- `lmxxf/dlss5-on-amd-9070xt-porting`: "A from-scratch re-implementation of NVIDIA's DLSS 5 neural renderer ('DLSSNR', the 71-block Swin/ViT network …) for AMD RDNA 4" as 38 HIP modules. Weights are extracted from the user's own DLL. Release 0.41 (2026-10-05). About 1.2 GB VRAM at 900p; output quality quoted as "44.26 → 47.55 dB" versus NVIDIA's reference output. Pipeline: low-res render → network → FSR upscaling — [forum/tool README] [lmxxf repo](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)

### Inferences
- **Recommended PT + NR architecture for the original game:** QindieGL (YAE fork) → Remix bridge → `dxvk-remix` main with `rtx.dlssNeuralRendering.enable=True`. This supersedes the external Feeder chain *for the Remix route*:
  - NR sees correct path-traced HDR→SDR content, Remix's exact motion vectors and depth (RR guides), and per-material masks.
  - It never touches the HUD.
  - It costs one evaluation per rendered frame, since FG runs after it.
  - The x86 ReShade/Feeder chain stays useful for the *non-Remix* (raster) mode.
- Applying the existing external chain to Remix output would need ReShade or OptiScaler inside `NvRemixBridge.exe` (x64, Vulkan). The OptiScaler_DLSSNR fork "supports native Vulkan" and hooks DLSS inputs, so it could plausibly ride Remix's DLSS SR/RR call and run before Remix's UI composite. Untested: no report found, and with FG it may crash as OptiScaler's FG does. A ReShade-layer route would process the HUD and lack proper guides.
- Since NVIDIA has done the integration, "modify Remix to insert an NR pass" reduces to: build main (or wait for the next tag), and make sure `nvngx_dlssnr.dll` is discoverable in the `.trex` feature path. NGX uses `env::getDllDirectory()` as the feature search path (from the commit).
- For **AMD**, the cleanest technically consistent option would be to replace the NGX call in `rtx_dlss_neural_rendering.cpp` with a Vulkan-native port of the network (e.g., mochizuki's DLSSNR-AMD, which is Vulkan and RDNA4 FP8), so it can share Remix's command buffers, motion vectors and depth. This is speculative, unverified and RDNA4-only for FP8; licensing is out of scope.
- Budget: NR on top of PT stacks two heavy workloads. DLSS 5 alone showed 40–60 % drops on RTX 50 in NBA 2K27 per Digital Foundry (via search summary), and RTX 4090 135 → 82 fps with the patched DLL. Combined with Remix PT, NR is realistically an RTX 50 (or high-end RTX 40, unofficially) feature.

### Gaps
- No community report was found of OptiScaler_DLSSNR, RenoDX or DLSS5-Feeder applied specifically to a Remix title, and none of Remix + RenoDX HDR.
- Not verified: whether the `rtx-remix-ngx_sdk_dlnr` packman package resolves for public self-builds; which DLSS-NR DLL version NVIDIA's integration expects; whether the patched RTX 40/30/20 DLLs initialise under Remix's NGX Vulkan path.
- No frame-time measurements of NR inside Remix exist yet.
- The Digital Foundry 40–60 % figure comes from a search summary (heldgames.com/dlss5 aggregators), not the original video.

## 6. Widest-GPU-coverage denoiser/upscaler stack in Remix, and settings/forks that lower the bar

### Takeaway
For maximum coverage (NVIDIA RTX 20–50, AMD RDNA2–4, Intel Arc) the portable baseline inside official Remix is:
- **NRD denoising + ReSTIR GI** for indirect lighting (NRC is NVIDIA-only);
- **RTXDI** on;
- **XeSS 2.1** (DP4a on non-Intel, XMX on Arc) or **TAA-U** / NIS for upscaling;
- no frame generation;
- a Low/Medium preset with fewer bounces and a lower `resolutionScale`.

NVIDIA cards then add vendor-locked tiers:
- DLSS-RR (4.5) + DLSS SR + NRC (+ Sparse Rendering) on all RTX;
- FG on RTX 40;
- MFG and native NR on RTX 50 (RTX 40 NR officially "later", unofficially now).

FSR has two community paths: a draft FSR 3.1 + FSR-FG in the NightSight "Community Edition" fork (2026-03-20), or OptiScaler spoofing (FSR 3.1/FSR4/XeSS; FG crashes).

### Cited Findings
**Component availability** [code]
- Upscalers: `None, DLSS, NIS, TAAU, XeSS` (no FSR). XeSS 2.1 was added in 1.3.6 (2026-01-27, @sambow23). XeSS options: `rtx.xess.preset` (default 2), `useOptimizedJitter`, `useRecommendedJitterSequenceLength` ("XeSS 2.1 recommended jitter sequence"), `responsivePixelMaskClampValue` 0.8 — [rtx_options.h](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_options.h), [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md), [release 1.3.6](https://github.com/NVIDIAGameWorks/rtx-remix/releases/tag/remix-1.3.6)
- Denoising and RR:
  - `rtx.enableRayReconstruction` (default True), "an AI-based denoiser"; RR presets (`rtx.rayreconstruction.preset`: 0 = auto, D/E/F).
  - NRD settings exist (`rtx_nrd_settings.*`, `rtx.denoiserMode`, `rtx.denoiseDirectAndIndirectLightingSeparately`).
  - RR history invalidation for animated water became opt-in on 2026-07-20.
  - [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md), [src/dxvk/rtx_render](https://github.com/NVIDIAGameWorks/dxvk-remix/tree/main/src/dxvk/rtx_render), [commits](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main)
- Vendor-locked features in code:
  - NRC: NVIDIA vendor ID plus driver check; minimum driver 610.47 since 2026-07-29.
  - Sparse Rendering: "DLSS Ray Reconstruction is required".
  - DLSS-NR: NGX support probe.
  - SER and OMM: hardware-dependent toggles.
  - [rtx_nrc_context.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_nrc_context.cpp), [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md)
- Auto presets (graphics: non-NVIDIA Low, Turing Low, Ampere Medium, Ada High, Blackwell Ultra; ray-trace mode by driver) — see Q2 — [rtx_options.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_options.cpp)
- DLSS feature tiers by GPU: Super Resolution, DLAA and Ray Reconstruction on all RTX GPUs; Frame Generation on RTX 40/50; Multi Frame Generation on RTX 50 — [primary] [NVIDIA DLSS technology page](https://www.nvidia.com/en-us/geforce/technologies/dlss/)

**Performance knobs a mod can ship in `rtx.conf`** (names and defaults from [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md), main 2026-10) [code]
- `rtx.graphicsPreset` (Auto plus Ultra/High/Medium/Low/Custom) and `rtx.resolutionScale` (default 0.75).
- Upscaler choice: `rtx.upscalerType` (0 None, 1 DLSS, 2 NIS, 3 TAAU, 4 XeSS per the enum order), `rtx.qualityDLSS`, `rtx.taauPreset`, `rtx.nisPreset`, `rtx.xess.preset`.
- Path length: `rtx.pathMaxBounces` (default 4, range 0–15), `rtx.pathMinBounces` (1), `rtx.enableSecondaryBounces`.
- Lighting: `rtx.integrateIndirectMode` (0 Importance Sampled, 1 ReSTIR GI, 2 NRC), `rtx.useRTXDI`, `rtx.neeCache.enable`.
- Effects and denoise cost: `rtx.volumetrics.enable` ("disabling falls back to cheaper depth based fog"), `rtx.denoiseDirectAndIndirectLightingSeparately`, `rtx.bloom.enable`, `rtx.postfx.enable`.
- Frame generation and latency: `rtx.dlfg.enable`, `rtx.dlfg.maxInterpolatedFrames` (1–6), `rtx.reflexMode`.
- Since 1.4.2, user choices live in `user.conf` while mod defaults live in `rtx.conf` — [release 1.4.2](https://github.com/NVIDIAGameWorks/rtx-remix/releases/tag/remix-1.4.2)

**Forks and tools that widen coverage**
- NightSightProductions "RTX-Remix-Community-Edition": "FSR 3.1 Draft #1" by KingVulpes (2026-03-20, merged as PR #22). It adds `rtx_fsr.cpp/.h`, `rtx_fsr_framegen.cpp/.h` and `rtx_rcas.cpp` (FSR 3.1 upscaler, FSR frame generation and RCAS sharpening). Status: draft, fork-only — [code] [commit a2ec0f4](https://github.com/NightSightProductions/RTX-Remix-Community-Edition/commit/a2ec0f42c592e6783948b09717ac5a97ba2d3c94)
- The same author's AMD TraceRay default was upstreamed (2026-07-22) — [code] [commit 0557867](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/0557867a82eec4898fe44a5928480ad4329b16f9)
- OptiScaler on Remix's Vulkan DLSS path (`VulkanUpscaler=fsr31`, `VulkanExtensionSpoofing=true`, DLSS inputs). FSR4 works through Vulkan→DX12 interop on an RX 9070 XT; FG crashes — [forum] [Steam guide](https://steamcommunity.com/app/2477290/discussions/0/600778161129549839/), [OptiScaler wiki](https://github.com/optiscaler/OptiScaler/wiki/RTX-Remix-Games)
- AMD NR substitutes (ReShade add-on or HIP/Vulkan ports) — see Q5 — [dlss5-neural-amd](https://github.com/zmodelerlover/dlss5-neural-amd), [lmxxf port](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)

### Inferences
Suggested tiering for a YAE Remix mod (inference, to be validated by profiling on real hardware):

| Tier | GPUs | Indirect | Denoiser | Upscaler | FG | NR |
|---|---|---|---|---|---|---|
| Portable | RDNA2/3/4, Arc A/B, RTX 20/30 fallback | ReSTIR GI, `pathMaxBounces` 1–2 | NRD | XeSS 2.1 (or TAA-U) at `resolutionScale` 0.5–0.67 | off | off (AMD: optional community add-on, experimental) |
| RTX 20/30 | Turing/Ampere | NRC | DLSS-RR | DLSS SR (RR+SR) | off | off (patched FP16 = impractical) |
| RTX 40 | Ada | NRC | DLSS-RR | DLSS SR | DLSS FG 2× | unofficial (patched DLL) / official "later this fall" |
| RTX 50 | Blackwell | NRC (+ Sparse Rendering) | DLSS-RR 4.5 | DLSS SR 4.5 | MFG up to 6× | **native Remix DLSS-NR** |

- Because official Remix auto-drops non-NVIDIA cards to "Low", a YAE mod should ship explicit per-tier `rtx.conf` / preset files rather than relying on Auto.
- Adding FSR 3.1 natively, by cherry-picking the NightSight draft into a pinned main snapshot, is the main code-level lever for AMD image quality. Otherwise document the OptiScaler route.
- Keep Intel Arc as "best effort" until a Remix snapshot is verified to boot on Arc. PCGH (2026-06-15) still could not run HL2 RTX on Arc.

### Gaps
- No measured comparison of NRD versus DLSS-RR cost and quality in current Remix was found, and no XeSS 2.1 versus TAA-U comparison on AMD or Intel.
- Whether NVIDIA plans native FSR in Remix is unknown: issue #964 was closed as "completed" without comment, while the code still lacks FSR.
- No data on whether Remix starts and runs on Arc B580 with 1.5.x or main in 2026, beyond PCGH's HL2 RTX exclusion and the March 2025 forum reports.
