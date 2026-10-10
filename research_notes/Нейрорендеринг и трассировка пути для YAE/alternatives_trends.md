# Alternatives to DLSS-5-style neural rendering and path tracing for remastering You Are Empty; where the community and the GPU industry are heading (as of 2026-10-07)

Conventions used in these notes:
- Every bullet is dated (event date or article date). Items older than 2026 are flagged **[older]**; superseded items are flagged **[superseded]**.
- **RUMOUR** marks leaks and unconfirmed reports. **OPINION** marks commentary. "(search excerpt)" means the claim was taken from a search-result excerpt because the page itself could not be fetched (HTTP 403/404 or an empty render). Treat those as less verified.
- GitHub and Hugging Face activity figures come from the GitHub REST API and the Hugging Face model API, queried on 2026-10-07. HF "downloads" is the API's trailing-30-day count.
- Licences are listed only as plain facts. Licence conflicts are out of scope.

## 1. Real-time generative restyling alternatives to DLSS 5 NR (video-to-video diffusion, world models): latency, resolution, temporal consistency and consumer-GPU feasibility in 2026

### Takeaway
As of October 2026, nothing besides DLSS 5 NR works as a local, in-frame generative filter for a playable game. The open real-time video-diffusion stacks run at about 15–40 fps at 512×512 or 480p. They add roughly 0.2–0.4 s of latency, need NVIDIA GPUs (often several, or 32–40 GB+ VRAM), and take no depth or G-buffer guidance. The ones that hit 30 fps at 1080p (Decart Lucy 2.5) are cloud services. World models (Genie 3, Odyssey-2, Mirage 2, HY-World 1.5) generate their own worlds and cannot restyle an existing game's frames.

### Cited Findings

#### Local and open real-time video diffusion
- **StreamDiffusion v1 [older, Dec 2023].** This is a per-frame image pipeline. It reached 91 fps image-to-image and 106 fps text-to-image (SD-Turbo, 512×512) on an RTX 4090 — [GIGAZINE, 2023-12-22](https://gigazine.net/gsc_news/en/20231222-streamdiffusion). The repo has 10.8k stars, but its last push was 2024-12-04, so it is effectively dormant; Apache-2.0 — [GitHub cumulo-autumn/StreamDiffusion](https://github.com/cumulo-autumn/StreamDiffusion).
- **StreamDiffusionV2** (UC Berkeley, MIT, Stanford, UT Austin and others). Public release 2025-10-06, checkpoints 2025-10-18, paper 2025-11-10, "initial support for NVIDIA Blackwell GPUs" added 2026-05-17. It needs Linux and an NVIDIA CUDA GPU. 568 stars, last push 2026-09-14, Apache-2.0 — [GitHub chenfengxu714/StreamDiffusionV2](https://github.com/chenfengxu714/StreamDiffusionV2). It is a true video-to-video model: its checkpoints are the Wan-based "wan_causal_dmd_v2v" (1.3B) and "…_14b" — same source.
  - Throughput on 4× H100 (NVLink):
    - 1.3B: 64.52 fps at 512×512 with 1 step; 61.57 fps with 4 steps; 42.26 fps at 480p.
    - 14B: 58.28 fps at 512×512 with 1 step; 31.62 fps with 4 steps.
  - Throughput on **4× RTX 4090 (PCIe)**, 1.3B: about 16 fps at 480p and 24 fps at 512×512.
  - Time to first frame is 0.37–0.47 s. Mean per-frame tail latency is 357 ms against a 1 s deadline.
  - It claims "strong temporal consistency" (temporal CLIP 98.51) and motion-aware noise scheduling against tearing at high motion.
  - Source for these figures: [arXiv 2511.07399 v2, 2026-02-22](https://arxiv.org/html/2511.07399v2).
- **Krea Realtime 14B.** Released 2025-10-20. It is Wan 2.1 14B distilled with Self-Forcing into an autoregressive model — [Krea blog](https://www.krea.ai/blog/krea-realtime-14b).
  - Speed: 11 fps text-to-video with 4 steps on a single **B200**, about 1 s to first frame.
  - It supports video-to-video ("stream real videos, webcam inputs… into the model").
  - Licence Apache-2.0 — [HF krea/krea-realtime-video](https://huggingface.co/krea/krea-realtime-video).
  - The README recommends **40 GB+ VRAM**; the KV cache takes up to 25 GB per GPU — [GitHub krea-ai/realtime-video](https://github.com/krea-ai/realtime-video).
  - The repo was last pushed 2025-11-13; the HF card was modified 2026-09-08 (5.5k downloads in 30 days) — GitHub/HF API.
  - Livepeer's Scope GPU benchmark says the RTX 5090 "hits memory limits… on memory-heavy pipelines (notably krea-realtime-video)" — [Livepeer Scope GPU Benchmark Report](https://livepeer.notion.site/Scope-GPU-Benchmark-Report-2dc0a34856878012b257d8a1702833a9) (search excerpt; page did not render).
- **FluxRT** (May 2026, Unlicense). This is a stream-editing pipeline built on the FLUX.2-klein-4B instruct-editing model. At 512×512 its README claims 20–40 fps with about 0.2 s end-to-end latency on an **RTX 5090**, and 15–30 fps with about 0.3 s on an **RTX 4090**. It has 0 stars, so it is a niche project — [GitHub thinhlpg/FluxRT](https://github.com/thinhlpg/FluxRT).
- **Daydream Scope** (Livepeer). Launched 2025-11-06 as an open tool for real-time interactive generative-video pipelines — [BusinessWire, 2025-11-06](https://www.businesswire.com/news/home/20251106860538/en/Daydream-Launches-Scope-and-Expands-StreamDiffusion-with-SDXL-Support-Advancing-the-Open-Source-Real-Time-AI-Video-Ecosystem).
  - Backends: StreamDiffusionV2, LongLive, Krea Realtime, RewardForcing, MemFlow.
  - It has **Spout/NDI** input and output for VJ tools such as Resolume and TouchDesigner. The HF README states Apache-2.0; the GitHub API reports NOASSERTION — [HF daydreamlive/scope README](https://huggingface.co/daydreamlive/scope/blob/main/README.md).
  - Release v0.2.5 on 2026-05-15, last push 2026-07-17, 452 stars — [GitHub daydreamlive/scope](https://github.com/daydreamlive/scope).
- **Screen Diffusion** (itch.io) is a "live image-to-image AI renderer" that restyles whatever is on the screen using SD-Turbo — [itch.io](https://screendiffusion.itch.io/screen-diffusion-v01). Its date and fps are unverified.
- **GitHub search on 2026-10-07** for "obs streamdiffusion", "reshade diffusion realtime" and "realtime game restyle diffusion" returned **no repositories**. No ReShade add-on or OBS plugin running a diffusion model in-frame was found — [GitHub search](https://github.com/search?q=reshade+diffusion+realtime&type=repositories).

#### NVIDIA Cosmos (offline sim-to-real "transfer")
- **Cosmos-Transfer2.5-2B** is a video-to-video model with edge, depth, segmentation and blur control. NVIDIA's examples include "Simulations to Photorealism". It is 3.5× smaller than Cosmos-Transfer1-7B, with "less hallucination and error accumulation" — [NVIDIA Research, Cosmos-Transfer2.5](https://research.nvidia.com/labs/cosmos-lab/cosmos-transfer2.5).
  - Code: release v1.5.4 on 2026-05-13, Apache-2.0 — [GitHub nvidia-cosmos/cosmos-transfer2.5](https://github.com/nvidia-cosmos/cosmos-transfer2.5).
  - Weights: licence "other", auto-gated, 73.8k downloads in 30 days — [HF nvidia/Cosmos-Transfer2.5-2B](https://huggingface.co/nvidia/Cosmos-Transfer2.5-2B).
- **[older, Mar 2025]** NVIDIA demonstrated "real-time" Cosmos-Transfer1-7B only by sharding it across a **GB200 NVL72 rack** (72 Blackwell GPUs) — [arXiv 2503.14492](https://arxiv.org/pdf/2503.14492).

#### Cloud and hosted restyling
- **Decart MirageLSD** (2025-07-17) was the first "Live-Stream Diffusion" model. It ran at 20 fps and 768×432 with under 40 ms per-frame response — [The Decoder](https://the-decoder.com/decart-launches-miragelsd-an-ai-model-that-transforms-live-video-feeds-in-real-time). A demo restyled Fortnite gameplay into an underwater world — [ETCentric](https://www.etcentric.org/decart-ai-s-mirage-transforms-live-stream-video-in-real-time/). **[superseded by Lucy 2.5]**
- **Decart Oasis 2.0** (2025-09-30) is a client-only Fabric mod for Minecraft 1.21.8 and the closest precedent to restyling an OpenGL game. It works in three steps — [Decart Cookbook](https://cookbook.decart.ai/lucy-restyle-minecraft-mod):
  - After the 3D world renders, it copies the window framebuffer to a PBO.
  - It sends the frame over WebRTC to the cloud model Lucy Restyle.
  - It writes the returned frame to a PBO and blits it to the window.
  - It does **not** use depth or other game buffers. All processing happens on Decart's servers.
  - Players switch prompts with `[`/`]` or `/oasis prompt` — [Oasis 2.0 how-to](https://oasis2.decart.ai/how-to-play).
- **Decart Lucy 2.5** (2026-07-16) runs at 30 fps and 1080p with "near-zero" latency. Its "self-anchoring" (using its own output as an anchor) is meant to keep edits stable "for hours without drift". It is available only through the Decart API, fal.ai and lucy.decart.ai — [The Next Web](https://thenextweb.com/news/decart-lucy-2-5-live-video-effects-physical-ai); [AlphaSignal](https://alphasignal.ai/news/decart-s-lucy-2-5-transforms-live-video-at-30-fps-without-drifting) (search excerpt).

#### World models (they generate new worlds; they do not restyle a game)
- **Dynamics Lab Mirage 2** (2025-08-22) turns an image into a navigable world in the browser. It is an autoregressive transformer diffusion model trained on gameplay footage — [The Decoder](https://the-decoder.com/mirage-2-allows-users-to-turn-sketches-and-photos-into-interactive-game-worlds/); [GIGAZINE, 2025-08-25](https://www.gigazine.net/gsc_news/en/20250825-ai-generative-world-mirage-2).
- **Odyssey-2** (2025-11-03) streams a frame every 40 ms. Odyssey-2 Pro (2026-01-23) was the first version in the API; Odyssey-2 Max followed on 2026-04-27. All are cloud only — [Odyssey](https://odyssey.ml/introducing-odyssey-2); [i-SCOOP](https://www.i-scoop.eu/odyssey-2-max-world-model/).
- **Google Genie 3** (Aug 2025) has about one minute of memory. **Project Genie** (2026-01-29) gives US Google AI Ultra subscribers aged 18+ access, with 60-second generations — [Google blog](https://blog.google/innovation-and-ai/models-and-research/google-deepmind/project-genie/); [Dataconomy, 2026-01-30](https://dataconomy.com/2026/01/30/google-launches-project-genie-create-interactive-worlds-with-ai/).
- **Tencent HY-World 1.5 (WorldPlay)** is open source (2025-12-17). It is a streaming video-diffusion world model with keyboard and mouse control, running at **24 fps** on 480p image-to-video. A lighter WorldPlay-5B "for small-VRAM GPUs (compromised quality)" followed on 2026-01-06. It needs an NVIDIA CUDA GPU — [GitHub Tencent-Hunyuan/HY-WorldPlay](https://github.com/Tencent-Hunyuan/HY-WorldPlay).

#### AMD and Intel support for real-time diffusion
- StreamDiffusionV2 lists only "Linux with NVIDIA GPU" — [GitHub](https://github.com/chenfengxu714/StreamDiffusionV2).
- AMD's documented ROCm video-diffusion stack (xDiT) targets Instinct MI300X/MI325X/MI350X/MI355X, not Radeon — [ROCm docs](https://rocm.docs.amd.com/projects/ai-ecosystem/en/latest/inference/xdit.html).
- On consumer Radeon, AMD only promotes **offline** generative video enhancement (Topaz on RDNA 3/4) — [GPUOpen](https://gpuopen.com/learn/topaz-labs-brings-generative-ai-video-enhancement/).
- No Intel Arc numbers were found for any real-time video-diffusion model.

### Inferences
- **Dead end for an in-game filter in 2026–27: local real-time diffusion restyling.** The best single-GPU local figure is 20–40 fps at 512×512 with about 200 ms latency (FluxRT on a 5090). Compared with a 1080p/60 fps target and a frame budget under about 33 ms, that is roughly 8× short on pixels and about 6–10× too slow on latency. These models also lack depth or G-buffer conditioning, so in YaE's dark, low-contrast scenes they will hallucinate and drift. On AMD and Intel there is no local path at all.
- **Usable today, but not for gameplay:**
  - "Spectator" or streaming restyles: pipe a capture through Spout/NDI into Scope.
  - Cloud restyling on the Oasis 2.0 pattern (framebuffer → WebRTC → blit). This fits an OpenGL game technically, but it ties the look to a commercial service, adds network round-trip time and cost, and is not a faithful restoration.
- **Recommended experiment (cheap, no runtime dependency): offline "look-dev targets".**
  - Run short YaE capture clips through Cosmos-Transfer2.5 with depth and segmentation control (and optionally Krea v2v or Lucy) to produce reference frames for a "photoreal" or "remastered" look.
  - Use those frames as art-direction targets for yae-materials and native-engine lighting, and as a third column in DLSS 5 NR comparisons.
- **The decisive technical difference is guidance.** DLSS 5 NR is constrained by engine data (albedo, normals, lighting; see section 4). Every non-NVIDIA alternative above is an RGB-in, RGB-out model. A native engine that exposes clean G-buffers is the only route to G-buffer-guided restyling with any vendor's future model.

### Gaps
- No verified single-GPU RTX 4090/5090 fps for StreamDiffusionV2 or Krea Realtime at 720p or above. The paper gives 4-GPU figures only.
- No pricing or real-world wide-area-network latency found for Lucy 2.5 or Oasis 2.0. The Oasis cookbook gives no fps or resolution.
- Screen Diffusion performance, date and GPU support are unverified.
- No temporal-stability measurements were found for any of these models on dark or low-light game footage.

## 2. Offline AI remastering of game assets (texture super-resolution and PBR maps, 3D generation and retopology, relighting): quality, open-model state of the art, and how assets feed RTX Remix and native engines

### Takeaway
The mature, high-ROI part of AI remastering in 2026 is the 2D texture pipeline: de-lighting, super-resolution and PBR map estimation, run batch-wise through ComfyUI and wired into RTX Remix's REST API. For 3D, TRELLIS.2 (Microsoft, MIT licence, 4B parameters, full PBR) is the open state of the art and heavily used. Tencent's open Hunyuan3D line stopped at 2.1 while 3.x went closed or cloud-only. Generated meshes still need retopology and art review.
- Contest-winning mods mix AI materials with hand-crafted hero assets.
- Commercial remasters that leaned on visible AI upscaling were punished. Deus Ex Remastered was delayed indefinitely.

### Cited Findings

#### Texture super-resolution and PBR generation
- **RTX Remix built-in AI texture tools** "analyze low-resolution textures… generate physically accurate materials" with up to 4× upscaling — [NVIDIA blog, 2025-03-13](https://blogs.nvidia.com/blog/rtx-ai-garage-rtx-remix) **[older]**.
  - The Remix Toolkit exposes a **REST API**. Modders batch-export captured textures to **ComfyUI**, enhance them, and re-import them automatically. They can also change the style with text prompts.
  - The community model **PBRFusion 3** (modder NightRaven) pairs a PBR model with a diffusion upscaler. It produces normal, roughness and height maps at up to 8× resolution and ships plug-and-play ComfyUI graphs.
  - All of the above: same NVIDIA blog post.
- **PBRify_Remix** (Kim2091) is "my custom (ethical) set of AI models to upscale textures and generate PBR maps". Licence CC0-1.0. Release v1.7.2 on 2025-05-22, last push 2026-02-19, 147 stars — [GitHub](https://github.com/Kim2091/PBRify_Remix).
- **Ubisoft La Forge CHORD** (SIGGRAPH Asia 2025). It is a diffusion model that turns one texture image into base colour, normal, height, roughness and metalness, with ComfyUI-Chord nodes. Weights and code are under a **Research-Only** licence — [Ubisoft La Forge](https://www.ubisoft.com/en-us/studio/laforge/news/1i3YOvQX2iArLlScBPqBZs/generative-base-material-an-opensource-prototype-for-pbr-material-estimation-debuting-at-siggraph-asia-2025); [Comfy blog](https://blog.comfy.org/p/ubisoft-open-sources-the-chord-model). The repo was created 2025-11-18 and last pushed 2025-12-09 — [GitHub ubisoft/ubisoft-laforge-chord](https://github.com/ubisoft/ubisoft-laforge-chord).
- **Marigold v1.1** (ETH, 2025-05-15) released these checkpoints — [GitHub prs-eth/Marigold](https://github.com/prs-eth/Marigold):
  - Marigold-IID-Appearance: albedo, roughness, metallicity.
  - Marigold-IID-Lighting: albedo, diffuse shading, non-diffuse residual. This is directly relevant to removing lighting baked into 2006-era textures.
  - Normals v1.1 and Depth v1.1.
  - The code is Apache-2.0 and the repo is active (last push 2026-09-06).
- **Material Anything** (CVPR 2025 Highlight) generates materials for any 3D object with diffusion. MIT, last push 2025-12-24 — [GitHub 3DTopia/MaterialAnything](https://github.com/3DTopia/MaterialAnything).
- **MatFuse** (CVPR 2024; MIT; 63 stars; last push 2026-02-19) — [GitHub giuvecchio/matfuse](https://github.com/giuvecchio/matfuse). **StableMaterials** (HF; created 2024-06-12, last modified 2025-04-05, OpenRAIL, 921 downloads in 30 days) — [HF gvecchio/StableMaterials](https://huggingface.co/gvecchio/StableMaterials). Both are **[older]** and lower-traction.
- **SeedVR2** (ByteDance Seed, ICLR 2026, Apache-2.0) is a diffusion image and video restorer and upscaler — [GitHub ByteDance-Seed/SeedVR](https://github.com/ByteDance-Seed/SeedVR).
  - SeedVR2-7B: 33k HF downloads in 30 days — [HF](https://huggingface.co/ByteDance-Seed/SeedVR2-7B).
  - The ComfyUI node has 2.9k stars, release v2.5.23 on 2025-12-24 — [GitHub numz/ComfyUI-SeedVR2_VideoUpscaler](https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler).
- **The classic ESRGAN-family toolchain is still maintained.**
  - chaiNNer (GPL-3.0, v0.25.1 on 2025-10-23, pushed 2026-10-01) — [GitHub](https://github.com/chaiNNer-org/chaiNNer).
  - Phhofm's upscaling models (newest 2xParagonSR_Nano, 2025-11-14) — [GitHub](https://github.com/Phhofm/models).
- **Material Maker** is procedural (Godot-based), not AI. Release 1.7 on 2026-07-14, MIT, 6k stars — [GitHub RodZill4/material-maker](https://github.com/RodZill4/material-maker).
- **NVIDIA neural-asset SDKs relevant to a native engine:**
  - RTX Neural Texture Compression SDK v0.10.0-beta (2026-08-04) — [GitHub NVIDIA-RTX/RTXNTC](https://github.com/NVIDIA-RTX/RTXNTC).
  - RTX Neural Shading SDK v1.5.0 (2026-09-17) — [GitHub NVIDIA-RTX/RTXNS](https://github.com/NVIDIA-RTX/RTXNS).

#### AI 3D asset generation and retopology
- **TRELLIS.2** (Microsoft, MIT). A 4B-parameter image-to-3D model at 512³–1536³ resolution with "full PBR materials". It exports GLB, and also offers shape-conditioned PBR texturing of existing meshes — [GitHub microsoft/TRELLIS.2](https://github.com/microsoft/TRELLIS.2).
  - Hardware: "An NVIDIA GPU with at least 24GB of memory is necessary". It is verified on A100/H100 and uses flash-attn by default.
  - Repo created 2025-11-26, last push 2026-07-10, 11.5k stars — same repo.
  - The HF weights were created 2025-12-01 and had **about 1.89M downloads in 30 days** — [HF microsoft/TRELLIS.2-4B](https://huggingface.co/microsoft/TRELLIS.2-4B).
  - Vendor blog, **OPINION**: TRELLIS 2 is "currently the quality leader among fully open models", generates transparency and translucency, and takes 1–3 min against 2–6 min for Hunyuan — [3D AI Studio](https://www.3daistudio.com/blog/trellis-2-vs-hunyuan-3d-differences-explained).
- **Hunyuan3D (Tencent).**
  - The open releases are 2.0 (Jan 2025; 15k stars; 122k HF downloads in 30 days) and 2.1 (June 2025; "production-ready PBR"; 59k HF downloads in 30 days). Licence "other". Both repos were last pushed in Oct 2025 — [GitHub Hunyuan3D-2](https://github.com/Tencent-Hunyuan/Hunyuan3D-2); [GitHub Hunyuan3D-2.1](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1); [HF tencent/Hunyuan3D-2.1](https://huggingface.co/tencent/Hunyuan3D-2.1).
  - The flagship "Hunyuan 3D Pro 3.1" and the retopology model **"Hunyuan Polygen 1.5"** ("retopologizes an existing mesh into clean game-ready geometry") are offered through platforms such as Scenario — [Scenario help](https://help.scenario.com/articles/5967392966-hunyuan-3d-models-the-essentials).
  - The Tencent-Hunyuan GitHub org has **no open 3.x 3D-generation repo**. Its repos active in 2026 are world models and tech reports instead, all last pushed in Aug 2026 (these are push dates, not release dates): HY-World 2.0, Hunyuan3D-Buffalo1.0, Hunyuan3D-WorldClaw — [GitHub Tencent-Hunyuan](https://github.com/Tencent-Hunyuan).
- **Other open models:**
  - Meta **SAM 3D Objects**: repo created 2025-09-29, 7.5k stars, weights gated — [GitHub](https://github.com/facebookresearch/sam-3d-objects).
  - **Step1X-3D** (Apache-2.0, May 2025) — [GitHub](https://github.com/stepfun-ai/Step1X-3D).
  - **TripoSG** (MIT, Mar 2025) — [GitHub](https://github.com/VAST-AI-Research/TripoSG).
  - **MeshAnythingV2** ("mesh like human artists", ICCV 2025; last push 2025-04) — [GitHub](https://github.com/buaacyw/MeshAnythingV2).
- **Commercial tools** (3D AI Studio, a vendor blog, 2026-06-03 — **OPINION**):
  - Rodin gives the "most detailed, photoreal output", but its dense meshes need remeshing and it has no auto-rig.
  - Tripo gives "clean, quad-friendly topology", but "fine detail and texturing trail".
  - Meshy offers auto-rig with animation presets.
  - Source: [3D AI Studio](https://www.3daistudio.com/blog/best-ai-game-asset-generators-2026).
  - A HackerNoon stress test of Meshy 6, Tripo v3.1 and Rodin Gen-2.5 found that Tripo produced the best geometry and cleanest topology — [HackerNoon](https://hackernoon.com/how-i-stress-tested-3-ai-3d-generators-on-the-same-inputs-what-the-numbers-actually-show?source=rss) (search excerpt).

#### AI relighting and de-lighting
- **NVIDIA DiffusionRenderer** (Cosmos-Transfer1 based) does "high-quality video de-lighting and re-lighting". Apache-2.0; created 2025-06-09, last push 2025-10-02 — [GitHub nv-tlabs/cosmos-transfer1-diffusion-renderer](https://github.com/nv-tlabs/cosmos-transfer1-diffusion-renderer).
- **IC-Light** (Apache-2.0, 8.5k stars, last push 2025-02-20) — [GitHub](https://github.com/lllyasviel/IC-Light) **[older]**.
- **RGB↔X** (intrinsic decomposition and synthesis; last push 2026-01-24) — [GitHub zheng95z/rgbx](https://github.com/zheng95z/rgbx).

#### Quality versus manual work, and how assets flow into Remix and engines
- The **RTX Remix Mod Contest** (results 2025-08-18; 24 entries) was won by **Painkiller RTX** (Merry Pencil Studios), which took Best Overall and Best Use of RTX — [NVIDIA](https://www.nvidia.com/en-us/geforce/news/rtx-remix-mod-contest-winners) **[older]**.
  - Its features: new PBR materials, high-poly displacement, subsurface scattering on marble, RTX Skin, volumetrics.
  - NVIDIA describes remastering with "AI-generated materials and hand crafted hero assets".
- **Commercial backlash against visible AI upscaling:**
  - Aspyr's **Deus Ex Remastered** trailer (Sept 2025) drew accusations of AI-upscaling artifacts and flat textures — [iXBT Games, 2025-09-25](https://ixbt.games/en/news/2025/09/25/remaster-deus-ex-vyzval-skval-kritiki-obvineniia-v-nizkom-kacestve-i-ispolzovanii-ii.html). In Dec 2025 Aspyr cancelled the 2026-02-05 release, delayed it indefinitely and refunded preorders — [Pure Xbox, Dec 2025](https://www.purexbox.com/news/2025/12/deus-ex-remastered-no-longer-releasing-in-february-2026-due-to-negative-feedback).
  - **Plants vs. Zombies Replanted** leaked footage was criticised for poor AI upscaling — [Notebookcheck](https://www.notebookcheck.net/Plants-vs-Zombies-Replanted-leaks-and-players-are-horrified-by-its-poor-AI-upscaling.1141024.0.html) **[older, 2025]**.
- **Remix pipeline mechanics.** Remix captures a running game's render data (textures, geometry, lights) to **USD**. Modders replace assets there. Non-D3D9 games work through **translation layers that target D3D9**, which is how YaE's QindieGL route works — [RTX Remix runtime user guide](https://github.com/NVIDIAGameWorks/rtx-remix/wiki/runtime-user-guide); [Nexus Mods Q&A with NVIDIA](https://www.nexusmods.com/news/14758) **[older]**.
- **Recent Remix features useful for low-poly assets:**
  - Remix 1.5 (June 2026) adds **Smooth Normals**, which auto-generates smoothed normals on old models — [Profesional Review, 2026-06-16](https://www.profesionalreview.com/2026/06/16/nvidia-actualiza-rtx-remix-1-5-lanza-el-driver-610-62-whql-y-prepara-mas-juegos-con-dlss-y-trazado-de-rayos/amp/) (search excerpt).
  - Remix 1.4.2 reportedly adds a particle **Curve Editor**, **Texture Hot-Reload** (textures update live in-game when saved in an image editor) and "RTX Skin Optimization" up to 55% faster. Press dates this to May 2026, while the GitHub tag is 2026-04-21 — [Softpedia RTX Remix changelog](https://www.softpedia.com/progChangelog/NVIDIA-RTX-Remix-Changelog-270480.html) (search excerpt; the originating page was not verified).
  - Release tags: remix-1.4.2 on 2026-04-21, remix-1.5.2 on 2026-06-16 — [GitHub NVIDIAGameWorks/rtx-remix](https://github.com/NVIDIAGameWorks/rtx-remix).
- **TRELLIS.2 output is GLB with PBR** — [GitHub](https://github.com/microsoft/TRELLIS.2). That fits glTF-based native engines directly and Remix via USD conversion.

### Inferences
- **Best ROI for yae-materials and the native engine: a curated 2D chain** of de-light → SR → PBR estimation → human review:
  - De-light: Marigold-IID-Lighting or RGB↔X.
  - SR: SeedVR2, or ESRGAN-family models such as Phhofm's or PBRify (CC0).
  - PBR estimation: CHORD (research-only licence), Marigold-IID-Appearance, Material Anything or PBRFusion.
  - The same outputs can feed RTX Remix (USD) and the native engine (glTF) from one material library. That matches how Remix modders already work through ComfyUI.
- **3D generation is for props and clutter, not for YaE's hero assets.** YaE's mutants, faces and signature Soviet-era set dressing should stay manually authored or carefully AI-assisted. The contest winners and the Deus Ex delay both point the same way.
  - TRELLIS.2 locally needs a 24 GB+ NVIDIA card (RTX 3090/4090/5090 class). AMD and Intel users are effectively limited to cloud services or manual work.
  - Plan for retopology (Polygen-type remeshers or MeshAnything-class tools, or manual) and for UV and texel-density normalisation before anything reaches the engine.
- **De-lighting is the under-used step.** 2006-era textures usually have baked lighting and AO. Feeding them unchanged into path tracing double-lights them. IID models released in 2025 make automated de-lighting feasible.
- **Avoid:** bulk unreviewed AI upscaling shipped as "the remaster". Players read it as cost-cutting (Deus Ex Remastered, PvZ Replanted).

### Gaps
- Not checked this session: Substance 3D Sampler's AI image-to-material, Adobe or Autodesk AI features, and the current RTX Remix AI texture model versions.
- No independent, quantitative 2026 benchmark found that compares AI PBR estimators (CHORD, Marigold-IID, Material Anything, PBRFusion) on game textures.
- Licence terms of Hunyuan 3D Pro 3.1 and Polygen 1.5, and whether any 3.x weights will open, are unknown.
- No AMD ROCm or Intel results found for TRELLIS.2, Hunyuan3D or SeedVR2.

## 3. Community direction 2025–2026: what old-game remaster projects are doing, what is gaining momentum and what fizzled

### Takeaway
Momentum in 2025–26 is concentrated in three places.
- **RTX Remix:** steady releases about every 2–3 months, NVIDIA-funded contests, OpenGL games via D3D9 wrappers (Quake III RTX), and agentic tooling arriving in October 2026.
- **The ReShade/RenoDX/OptiScaler injection scene:** it found and spread the leaked DLSS 5 NR DLL within days, and ported it to AMD and Intel within weeks.
- **ComfyUI-based AI texture pipelines.**

What fizzled or stalled:
- The RTGL1 source-port family (no commits since 2023).
- Half-Life 2 RTX's public progress (demo only since March 2025).
- The original StreamDiffusion.
- Tencent's open 3D-generation line.

### Cited Findings

#### RTX Remix
- **Release cadence**, from [GitHub NVIDIAGameWorks/rtx-remix](https://github.com/NVIDIAGameWorks/rtx-remix):
  - 1.0.0: 2025-03-13
  - 1.1.0: 2025-07-18
  - 1.2.4: 2025-09-09
  - 1.3.6: 2026-01-27
  - 1.4.2: 2026-04-21
  - 1.5.2: 2026-06-16
- **dxvk-remix** saw "Sparse Rendering – Compact GBuffer" commits on 2026-10-05/06 and an RTXIO bump for arm64 on 2026-10-02 — [GitHub NVIDIAGameWorks/dxvk-remix commits](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main).
- **toolkit-remix** has "[REMIX-5681] MR2 (Agentic Remix Productization)…" (2026-10-05) and a "Remix skill" bug fix (2026-10-06), so an AI-agent workflow is coming to the Toolkit — [GitHub NVIDIAGameWorks/toolkit-remix commits](https://github.com/NVIDIAGameWorks/toolkit-remix/commits/main).
- **RTX Remix 1.3** (CES, Jan 2026) added **Remix Logic**: game events such as doors, switches or "enemy is close" trigger visual changes from 900+ settings, without source code — [TweakTown](https://tweaktown.com/news/109906/rtx-remix-1-3-is-available-now-adds-new-rtx-remix-logic-feature-for-modders/index.html); [MuyComputer, 2026-01-06](https://www.muycomputer.com/2026/01/06/ces-2026-nvidia-presenta-rtx-remix-logic-y-confirma-mejoras-de-rendimiento-en-ia-con-sus-geforce-rtx/).
- **Advanced Particle VFX** (GDC; rolled out 2026-04-21) was demonstrated with WoodBoy's Quake III Arena RTX — [Worthplaying, 2026-04-21](https://worthplaying.com/article/2026/4/21/news/149646-nvidia-will-rolls-out-rtx-remix-advanced-particle-vfx-update-marvel-rivals-geforce-reward-and-new-dlss-games-updates/); [NVIDIA](https://www.nvidia.com/en-us/geforce/news/rtx-remix-advanced-particle-vfx).
- **Quake III Arena RTX** (woodboy90) is an **OpenGL** game on Remix. It started with 3 maps (Q3DM1/6/10); v0.7 overhauls 27 levels and has moved from demo to Early Access — [PCGH](https://www.pcgameshardware.de/Quake-3-Spiel-28934/News/RTX-Remix-Mod-wurde-auf-27-Level-erweitert-1529889/); [DSOGaming](https://www.dsogaming.com/news/quake-3-arena-rtx-remix-path-tracing-mod-released/). Exact dates were not captured: first release 2025–26, v0.7 likely 2026. NVIDIA used it as the GDC 2026 showcase for Advanced Particle VFX — [NVIDIA](https://www.nvidia.com/en-us/geforce/news/rtx-remix-advanced-particle-vfx).
- **$50k RTX Remix Mod Contest** with ModDB (2025-08-18; 24 entries) — [NVIDIA](https://www.nvidia.com/en-us/geforce/news/rtx-remix-mod-contest-winners) **[older]**. Mods are distributed through the ModDB Remix hub — [ModDB](https://www.moddb.com/remix).
  - Painkiller RTX won Best Overall and Best Use of RTX.
  - Community Choice went to "Call of Duty 2 RTX Remix of Carentan".
  - Entries also covered Half-Life 2, NFS Underground, Portal 2 and Deus Ex.
- **Scale claims [older, aggregator]:** "over 30,000 modders… hundreds of classic games… more than 1 million gamers" — [CO/AI summarising NVIDIA](https://ww.getcoai.com/?p=57630).
- **Half-Life 2 RTX** (Orbifold Studios): the demo (Ravenholm and Nova Prospekt) came out 2025-03-18 and was last patched 2025-05-08. As of 2026 there is "no full release, no release date, and no announced window" — [GamerTagMythras blog](https://gamertagmythras.com/blog/half-life-2/half-life-2-rtx-demo-guide) (secondary source); project page [Valve Developer Wiki](https://developer.valvesoftware.com/wiki/Half-Life_2_RTX).

#### Ray-traced source ports and ReShade GI
- **RTGL1 family (sultim-t): dormant** — GitHub API:
  - [RayTracedGL1](https://github.com/sultim-t/RayTracedGL1): last push 2023-12-02.
  - [xash-rt](https://github.com/sultim-t/xash-rt) (Half-Life 1 path tracing; 1.2k stars): last release 1.0.5a on 2023-03-04, last push 2023-08.
  - [prboom-plus-rt](https://github.com/sultim-t/prboom-plus-rt): last push 2023-08.
  - [Serious-Engine-RT](https://github.com/sultim-t/Serious-Engine-RT): last release v1.5 on 2022-04.
- **ReShade** itself is active (last push 2026-09-24) — [GitHub crosire/reshade](https://github.com/crosire/reshade).
- **Pascal Gilcher's RTGI** is Patreon-distributed. An update was reported as "biggest yet", with a custom sampler claimed to beat ReSTIR GI, plus a path-traced volumetric fog beta — [Wccftech](https://wccftech.com/rtgi-reshade-shader-receives-its-biggest-update-yet-outperforming-restir-gi-according-to-its-author/amp/) (date not captured; possibly **[older]**). The iMMERSE repo was last pushed 2026-07-08 — [GitHub martymcmodding/iMMERSE](https://github.com/martymcmodding/iMMERSE).

#### DLSS 5 NR injection scene (tooling covered by other researchers; momentum only here)
- **The leak (late Aug 2026).** The **RenoDX** community found `nvngx_dlssnr.dll` (DLSSNR 310.8.0.0) in an NBA 2K27 early-access build. It then ran it in Control, Skyrim, FF VII Rebirth, GTA San Andreas and more — [ProPakistani, 2026-08-29](https://propakistani.pk/2026/08/29/leaked-dlss-5-build-is-turning-game-characters-into-nightmares/); [VGC](https://www.videogameschronicle.com/news/this-is-horrifying-nvidias-controversial-dlss-5-ai-filter-leaks-and-layers-are-inserting-it-into-every-game/); [st-hakky summary](https://book.st-hakky.com/en/news/nvidia-dlss-5-leaked-uncanny-nightmares).
  - This project pins exactly that DLL (nvngx_dlssnr 310.8.0.0) — [VERSIONS.txt](/home/alex/PetProjects/YAE-dlls/yae-dlss5/VERSIONS.txt).
- **Repo activity:**
  - RenoDX: 4.4k stars, nightly build 2026-10-06 — [GitHub clshortfuse/renodx](https://github.com/clshortfuse/renodx).
  - OptiScaler: 11.6k stars, v0.9.4 on 2026-07-18, pushed 2026-10-06 — [GitHub optiscaler/OptiScaler](https://github.com/optiscaler/OptiScaler).
- **Second-GPU offload (about Sept 2026).** The ReShade add-on "MGPU Bridge" (Marcelo Guibout) runs NR on a second RTX 5060 Ti 16GB. It gives up to +127% fps with DLSS SR at Ultra Performance — [PC Gamer](https://pcgamer.com/hardware/graphics-cards/new-dlss-5-mod-offloads-neural-rendering-to-a-second-card-massively-cutting-the-ai-filters-performance-hit).
- **AMD ports (Sept 2026).** Two projects, "dlss5-on-amd-9070xt-porting" (Kien) and "DLSS-NR-on-AMD" (Daniel Blanco), use custom HIP kernels on RX 9000 and RX 7000 — [Let's Data Science](https://letsdatascience.com/news/modder-runs-dlss-5-on-amd-radeon-gpus-dce2c9ee); [TweakTown](https://www.tweaktown.com/news/113775/modders-supercharge-dlss-5-on-amd-gpus-with-faster-performance-and-one-click-installation/index.html); [Club386](https://www.club386.com/?p=157918).
  - Performance went from 11–12 fps to about 28–30 fps at 1080p.
  - The developer **claims** 75 fps in Cyberpunk 2077 on an RX 9070 XT.
- **Intel reimplementation (Sept 2026).** "dlss-nr-on-intel" uses Vulkan with XMX and no NVIDIA code. On an Arc 140V it runs at about 2.4 fps at 1080p and about 3 fps at 720p — [Gaming-ST](https://gaming-st.com/news/dlss5-neural-rendering-intel-arc140v-xmx-vulkan-2026-09/); [MuyComputer, 2026-09-21](https://www.muycomputer.com/2026/09/21/dlss-5-funciona-en-juegos-con-una-intel-arc-140v-pero-a-3-fps-con-resolucion-720p/).
- **RTX 40.** An RTX Remix modder reportedly patched the NR DLL to run on RTX 4090/4080 before NVIDIA confirmed official RTX 40 support — [Notebookcheck](https://www.notebookcheck.net/Nvidia-confirms-DLSS-5-is-coming-to-RTX-40-series-GPUs-but-Ada-Lovelace-owners-have-no-release-date-yet.1388828.0.html) (search excerpt).

#### AI texture and 3D tooling momentum
- TRELLIS.2 weights had about 1.89M HF downloads in 30 days — [HF](https://huggingface.co/microsoft/TRELLIS.2-4B).
- The original StreamDiffusion has been dormant since 2024-12 — [GitHub](https://github.com/cumulo-autumn/StreamDiffusion).
- Tencent's open Hunyuan3D repos were last pushed Oct 2025 — [GitHub](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1).

#### Communities
- **RenoDX Discord:** where the DLSS NR leak surfaced — [st-hakky summary](https://book.st-hakky.com/en/news/nvidia-dlss-5-leaked-uncanny-nightmares).
- **ModDB RTX Remix hub** — [ModDB](https://www.moddb.com/remix).
- **NVIDIAGameWorks GitHub** (rtx-remix, dxvk-remix, toolkit-remix).
- **OptiScaler GitHub.**
- **Daydream / Livepeer** for real-time video AI — [Livepeer ecosystem](https://livepeer.org/ecosystem/daydream).

### Inferences
- **YaE's QindieGL → D3D9 → Remix route matches what the most visible current OpenGL Remix project, Quake III RTX, does.** That route is validated.
- **The RTGL1 path is a dead end for new work.** It has had no maintenance since 2023, and it requires engine source, which the native engine replaces anyway.
- **The injection scene moves fast but fragile.** Any chain built on a leaked DLL (310.8.0) should be treated as a lab experiment, not a distribution channel. Expect breakage when official DLLs and drivers change. Cross-vendor ports exist but run at 2–75 fps depending on the GPU.
- **The winning community pattern** is a hybrid: AI-assisted bulk materials, hand-crafted hero assets, and path tracing done well (Painkiller RTX). It is not a whole-frame AI filter.

### Gaps
- No reliable 2026 counts of Remix mods or players. The only figures found are 2025 NVIDIA claims via an aggregator.
- RTGI's latest 2026 version and date were not verified.
- No data found on uptake of AI texture packs on Nexus Mods or ModDB, or on platform AI-content policies in 2026.
- AMD and Intel performance of Remix path-traced mods in 2026 was not verified.

## 4. Reception and risks: sentiment about DLSS 5 NR as an "AI filter", how projects handle "faithful by default", and specific concerns for dark horror games

### Takeaway
Reception of DLSS 5 NR has been predominantly negative among enthusiasts since the March 2026 reveal.
- Self-selected polls show 58–71% rejection.
- Criticism centres on altered faces and a homogenised "AI" look that overrides art direction.
- NVIDIA answered with developer controls: structure and tone intensity, masking, and three models.

For a dark horror game, the specific risks are a "glamorised" look on faces and creatures, smoothed grime, and changed atmosphere. Precedent supports shipping such effects **off by default, with an instant A/B toggle and intensity control**.

### Cited Findings

#### What NVIDIA announced and shipped
- **Announcement: GTC, March 2026**, for launch in fall 2026.
  - NVIDIA calls it "3D-guided neural rendering" that adds "photoreal lighting and materials" at up to 4K.
  - It requires RTX 50 "Neural Shader cores".
  - Bethesda, Capcom, Ubisoft and WB Games committed support.
  - Sources: [Distrito, GTC 2026](https://www.distrito.me/blog/gtc-2026-nvidia-apresenta-dlss-5-e-aposta-neural-rendering); [Notebookcheck IT](https://www.notebookcheck.it/Nvidia-DLSS-5-e-confermato-per-il-lancio-nel-corso-dell-anno-con-il-rendering-neurale.1251863.0.html) (search excerpts).
  - First named games: Hogwarts Legacy, Resident Evil Requiem, Assassin's Creed Shadows, Delta Force, Starfield — [Digit, 2026-03-18](https://www.digit.in/features/gaming/nvidia-dlss-5-5-games-you-can-try-it-in.html/amp/).
- **SIGGRAPH 2026 keynote** (article updated 2026-07-21), from [PC Guide](https://www.pcguide.com/news/nvidia-just-showed-off-more-dlss-5-to-explain-how-it-preserves-artistic-intent-with-controls-for-developers/):
  - Global **Structure Intensity** and **Tone Intensity** sliders (0–1).
  - **Developer masking** with automatic masking of characters and models.
  - **Three trained models (A/B/C)** that developers can mix through a game.
  - It is constrained by albedo, surface normals and lighting.
  - Edward Liu (NVIDIA): "DLSS must change the image in a way that it does not change the story."
  - It "originally required two RTX 5090s".
- **Launch, Sept 2026**, from [GamingBible, 2026-09-30](https://www.gamingbible.com/news/platform/pc/dlss-5-explained-supported-games-gpu-871066-20260930):
  - **NBA 2K27** was the only official title.
  - It runs on RTX 50 desktop and laptop and on GeForce NOW. RTX 40 is "planned"; RTX 20 and 30 are not confirmed.
  - NBA 2K27 at 4K on an RTX 5080 fell to 45 fps with DLSS 5 on.
  - An unofficial "DLSS 5 Swapper" exists.
- **RTX 40** support is confirmed "once RTX 50 Series performance is more fully tuned", with "limited user controls" and no date — [AI Weekly](https://aiweekly.co/alerts/nvidia-commits-dlss-5-to-rtx-40-series-once-rtx-50-tuning-wraps-sets-no-firm); [OC3D](https://overclock3d.net/news/software/dlss-5-is-coming-to-rtx-40-series-gpus-but-not-yet) (late Sept 2026).
- **Performance.** Digital Foundry and about five other outlets measured a native frame-rate drop of roughly 50–73% before Multi Frame Generation recovers it — [Tech Insider aggregation](https://tech-insider.org/?p=22591); [Notebookcheck: "DLSS 5 humbles RTX 5090 with over 50% performance loss"](https://www.notebookcheck.net/First-DLSS-5-game-tested-DLSS-5-humbles-RTX-5090-with-over-50-performance-loss.1391978.0.html) (search excerpts, Sept–Oct 2026).

#### Sentiment
- **Jensen Huang**, GTC 2026 press Q&A with Tom's Hardware: "Well, first of all, they're completely wrong". He called it "not post-processing at the frame level, it's generative control at the geometry level" and said developers can "fine-tune the generative AI" — [Tom's Hardware](https://tomshardware.com/pc-components/gpus/jensen-huang-says-gamers-are-completely-wrong-about-dlss-5-nvidia-ceo-responds-to-dlss-5-backlash); [Club386](https://www.club386.com/nvidia-ceo-jensen-huang-dlss-5-backlash-response/) (search excerpts).
- **The criticism focused on** Resident Evil Requiem's Grace Ashcroft and Leon Kennedy. Players said faces looked "glamorous", "hyper-glamorous", "a completely different person", "AI slop" or homogenised — [Tom's Hardware](https://tomshardware.com/pc-components/gpus/jensen-huang-says-gamers-are-completely-wrong-about-dlss-5-nvidia-ceo-responds-to-dlss-5-backlash); [GamingBible](https://www.gamingbible.com/news/platform/pc/dlss-5-explained-supported-games-gpu-871066-20260930).
  - Artist Karla Ortiz was quoted as saying it "kills the expertly calibrated visual cohesion, visual intention, and visual identity of a game" — [RedShark News](https://www.redsharknews.com/nvidia-dlss-5-neural-rendering-backlash); [Space Coast Daily, Mar 2026](https://spacecoastdaily.com/2026/03/dlss-5-0-breakdown-why-neural-rendering-is-facing-massive-backlash/) (search excerpt).
- **Capcom producer Masato Kumazawa** (Eurogamer interview, about 2026-05-04): "The fact a lot of players commented they really liked the original design of Grace and didn't want to see it changed was a positive… It meant we got the design right" — [Nintendo Wire, 2026-05-04](https://nintendowire.com/news/2026/05/04/resident-evil-requiem-producer-on-nvidias-controversial-ai-grace-redesign-it-meant-we-got-the-design-right/embed/); [VGC](https://www.videogameschronicle.com/news/resident-evil-requiem-producer-says-dlss-5-anger-shows-we-got-graces-original-design-right/).
- **Polls (self-selected, not representative; spring 2026):**
  - TechPowerUp, about 20,000 responses: 58% said "AI should not alter game visuals at all", about 28% wanted to wait for finished games, 8% said it looks better than native, and about 6% would accept it for fps — [TweakTown](https://www.tweaktown.com/news/111513/58-of-gamers-dont-want-dlss-5-altering-their-games-while-others-await-real-world-results/index.html) (search excerpt).
  - PC Gamer, 4,484 votes: 37% "ethically opposed… would never enable it" and 34% "looks awful", 71% combined — [MP1st](https://mp1st.com/?p=305532); [Rutab, 2026-04-10](https://rutab.net/b/hardware/2026/04/10/tolko-1-iz-4-igrokov-vklyuchit-dlss-5-soobschestvo-mobilizovano-protiv-tehnologii-nvidia.html) (search excerpts).
- **Leak-era coverage (late Aug 2026):**
  - "'This is horrifying'" — [VGC](https://www.videogameschronicle.com/news/this-is-horrifying-nvidias-controversial-dlss-5-ai-filter-leaks-and-layers-are-inserting-it-into-every-game/).
  - "'Unsettling'… gamers are horrified" — [Creative Bloq](https://creativebloq.com/3d/unsettling-nvidias-dlss-5-controversial-ai-filter-has-leaked-and-gamers-are-horrified).
  - "'This Looks Like Dogsh*t'" — [Push Square, Aug 2026](https://www.pushsquare.com/news/2026/08/this-looks-like-dogsht-disturbing-dlss-5-ai-filter-applied-to-major-ps5-games-after-leaking).
  - Reports said Skyrim's atmosphere was "almost completely changed", while Control was "not too bad"; there was an "eerie and distorted" trend — [st-hakky summary](https://book.st-hakky.com/en/news/nvidia-dlss-5-leaked-uncanny-nightmares).
- **XDA on old games** (2026-09-19; leaked build via ReShade and RenoDX), from [XDA](https://www.xda-developers.com/i-tested-the-leaked-dlss-5-and-its-doing-something-to-old-games-that-nvidia-probably-didnt-intend/):
  - Geralt came out "waxy", in uncanny-valley territory, while Triss was "flattered".
  - "DLSS 5 is not neutral about art direction at all".
  - It gave large atmosphere gains in Arkham Knight (wet asphalt, overcast lighting) and Metro Exodus (volumetrics, corpse detail).
  - The author expects the official implementation to "almost certainly behave differently".
- **OPINION:**
  - PCWorld argues games may need a "dev's intended experience mode" — [PCWorld](https://www.pcworld.com/article/3224774/dlss-5-is-here-and-i-cant-help-wondering-if-we-need-a-devs-intended-experience-mode-in-games.html).
  - Fextralife: "makes games both look and run terribly" — [Fextralife](https://fextralife.com/nvidias-new-ai-filter-makes-games-look-and-run-terribly/).

#### Horror-specific concerns
- [Digit, 2026-03-18](https://www.digit.in/features/gaming/nvidia-dlss-5-5-games-you-can-try-it-in.html/amp/):
  - "Horror lives and dies by atmosphere…"
  - "The grotesque enemy detail, the oppressive darkness, the way light catches a wet surface…"
  - "if DLSS 5 starts smoothing out the grime and texture that makes Resident Evil feel viscerally uncomfortable…"
  - "Horror does not forgive visual inconsistency the way other genres might."
- Hands-on summaries mention per-studio intensity, colour-grading and masking controls, plus "natural", "cinematic" and "sharper default" presets that change colour grading — [igor'sLAB](https://www.igorslab.de/en/what-we-know-and-dont-know-about-dlss-5-so-far-reality-and-visual-aesthetics-put-to-the-test/); [MindStudio](https://www.mindstudio.ai/blog/dlss-5-neural-rendering-hands-on/) (search excerpts; unverified detail).

#### "Faithful by default" precedents
- **Tomb Raider I–III Remastered** (Feb 2024) lets players switch between Classic and Remastered visuals instantly at any time (Options button), like Halo: MCC — [TechPowerUp, 2024-01-17](https://www.techpowerup.com/317944/tomb-raider-i-iii-remastered-features-explored); [Push Square](https://www.pushsquare.com/news/2024/01/big-list-of-tomb-raider-remastered-ps5-ps4-upgrades-revealed) **[older]**.
- **DLSS 5 is officially an opt-in setting** with developer-controlled strength — [GamingBible](https://www.gamingbible.com/news/platform/pc/dlss-5-explained-supported-games-gpu-871066-20260930).
- **This project's own README already presents side-by-side OFF/ON comparisons** and documents a toggle key — [yae-dlss5 README](/home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md).

### Inferences
- **For YaE, NR should be "experimental look", OFF by default.** Provide:
  - An instant A/B toggle in the Tomb Raider Remastered style.
  - An intensity control. If the leaked 310.8.0 DLL exposes no structure or tone controls, blend the NR output with the original frame in ReShade.
  - Masks for HUD, faces and creatures where possible.
  - Plain labelling as AI-generated.
- **The specific YaE risks** follow from the evidence:
  - Mutants and zombies being "humanised" or "glamorised".
  - Dark corridors lifted or re-graded.
  - Grime smoothed.
  - Atmosphere replaced, as with Skyrim.
  - Mitigations: keep the original tone mapping and LUT after NR, test dark-scene histograms (black level, percentage of near-black pixels) OFF against ON, and review creature faces specifically.
- **Path tracing with authored materials keeps authorship. NR "re-imagines".** For a restoration project, the defensible primary path is path tracing and AI-assisted assets. NR is a showcase or optional mode.

### Gaps
- No quantitative study found of DLSS 5's effect on luminance or black levels in dark scenes.
- No horror game had an official DLSS 5 implementation by 2026-10-07 (RE Requiem support is announced, not shipped), so no horror-specific official evidence exists yet.
- Unknown whether the leaked 310.8.0 DLL honours any of the SIGGRAPH-announced controls.
- Tom's Hardware, TweakTown and Notebookcheck pages were not directly fetchable (HTTP 403). Quotes rely on corroborating excerpts.

## 5. Industry moves likely to matter by 2027 (AMD and Intel responses, DirectX and Vulkan ML, next GPU generations, consoles)

### Takeaway
By 2027, generative neural rendering officially remains NVIDIA-only: RTX 50, with RTX 40 limited.
- **AMD** has officially announced only FSR Diamond, which is "built for next-gen neural rendering" for Xbox Project Helix. An RDNA 5-only "Neural Lighting"/FSR 5 that reads engine geometry is a rumour.
- **Intel** has XeSS 3 MFG, but its discrete roadmap reportedly lost Celestial.
- **Cross-vendor ML-in-shader plumbing is landing:** DirectX SM 6.9 cooperative vectors are retail, SM 6.10 linalg is in preview, and Vulkan cooperative-matrix extensions are expanding.
- **Next GPUs and consoles slip toward H2 2027 to 2029** because of the memory-price crisis. RTX 20/30 and RDNA 2/3 will remain a large installed base.

### Cited Findings

#### NVIDIA
- **DLSS 4.5** (CES, 2026-01-06) — [NVIDIA](https://nvidia.com/en-us/geforce/news/dlss-4-5-dynamic-multi-frame-gen-6x-2nd-gen-transformer-super-res); [Notebookcheck](https://www.notebookcheck.net/Nvidia-DLSS-4-5-brings-2nd-gen-Transformer-and-6x-multi-frame-gen-to-RTX-50-Blackwell-RTX-20-and-RTX-30-stand-to-benefit-with-caveats.1197464.0.html):
  - Its 2nd-gen transformer Super Resolution supports RTX 20/30/40/50.
  - RTX 20/30 lack FP8, so the new models M and L cost more there, and model K (DLSS 4.0) may be preferable.
  - Dynamic MFG up to 6× (spring 2026) is RTX 50-only.
- **DLSS 5 NR** is RTX 50 now and RTX 40 later with limited controls (section 4). **RTXNS v1.5.0** came out 2026-09-17 and **RTXNTC v0.10.0-beta** 2026-08-04 — [GitHub RTXNS](https://github.com/NVIDIA-RTX/RTXNS); [GitHub RTXNTC](https://github.com/NVIDIA-RTX/RTXNTC).
- **RUMOUR:** RTX 60 ("Rubin", GR20x dies) in **H2 2027** (kopite7kimi). The rumoured RTX 50 Super refresh reportedly vanished over GDDR7 supply — [Guru3D](https://www.guru3d.com/story/leaker-suggests-nvidia-rtx-60-launch-in-h2-2027-with-gr200family-silicon/); [KitGuru](https://www.kitguru.net/components/graphic-cards/joao-silva/nvidia-rtx-60-series-rubin-expected-to-release-in-2h-2027/).
- **OPINION:** igor'sLAB argues that DLSS 5 is the RTX 60-era "true next-gen feature" brought forward — [igor'sLAB](https://www.igorslab.de/en/with-the-geforce-rtx-6090-and-dlss-5-nvidia-has-brought-forward-its-true-next-gen-feature/).

#### AMD
- **FSR Redstone** (2025-12-10) — [Guru3D](https://www.guru3d.com/story/fsr-4-redstone-amd-new-ai-upscaling-arrives-december-10-officially/); [TechSpot](https://www.techspot.com/article/3072-amd-fsr-redstone/) **[older]**:
  - It covers FSR Upscaling 4 (ML), ML Frame Generation, **Ray Regeneration** (ML denoiser; first in CoD: Black Ops 7) and **Radiance Caching** (ML, "2026").
  - It is RDNA 4 (RX 9000)-exclusive. Radiance Caching and Ray Regeneration are not available "in any form on RDNA 3 or earlier".
- **FSR 4.1** (announced 2026-05-15) brings ML upscaling to **RDNA 3 (July 2026)** and **RDNA 2 (early 2027)** through an INT8 path, with 300+ games — [NoobFeed](https://www.noobfeed.com/hardware/amd-fsr-4-1-rdna-3-rdna-2-radeon-gpu) (search excerpt).
- **FSR Diamond** (official, 2026-03-12, Jack Huynh) — [Club386](https://www.club386.com/amd-fsr-diamond-rdna-5-exclusive-rumour/):
  - "Built for next-gen neural rendering", next-gen ML upscaling, new ML multi-frame generation, next-gen Ray Regeneration for RT and path tracing.
  - "Natively optimized for Project Helix and deeply integrated into the GDK".
  - **RUMOUR** (Kepler_L2): RDNA 5-exclusive; same source.
  - **RUMOUR:** up to 8× frame generation — [HotHardware](https://hothardware.com/news/amd-fsr-leaks-with-8x-frame-gen-and-ray-regeneration).
- **RUMOUR (Sept 2026):** an AMD "Neural Lighting" feature (leaker, 2026-09-08) and FSR 5 with neural rendering that reads full scene geometry, depth and meshes, not just colour and motion vectors. It would be RDNA 5 / RX 10000-only. AMD has not confirmed any of this — [XenoSpectrum](https://xenospectrum.com/en/amd-neural-lighting-evidence/); [Aroged, 2026-09-17](https://www.aroged.com/2026/09/17/amd-is-preparing-fsr-5-with-neural-rendering-its-not-a-dlss-5-neural-filter-but-more/). No official AMD comment on DLSS 5 was found.
- **RUMOUR:** RDNA 5 Radeon in **mid-2027** (Moore's Law Is Dead; TSMC N3P). Board partners expect H2 2027, others early 2028 — [TweakTown](https://tweaktown.com/news/112289/amds-rdna-5-radeon-gpus-will-launch-in-mid-2027-per-new-leak/index.html); [Wccftech](https://wccftech.com/amd-rdna-5-next-gen-radeon-gpus-launch-mid-2027-tsmc-n3p-node-rumor/amp/); [igor'sLAB](https://www.igorslab.de/en/amd-rdna-5-rumored-late-2027-early-2028-radeon-roadmap-delay/).
- **AMD "Toyshop"** real-time path-tracing and neural-rendering demo on an RX 9070 XT drew complaints of blur and artifacts — [TechRadar](https://www.techradar.com/computing/gpu/amd-rx-9070-could-struggle-to-compete-with-nvidia-50-series-gpus-according-to-latest-tech-demo) **[older, 2025]**.

#### Intel
- **XeSS 3** (CES 2026) adds Multi Frame Generation on Arc GPUs with XMX. XeSS-SR also has a cross-vendor path on SM 6.4+ — [Intel](https://www.intel.com/content/www/us/en/developer/topic-technology/gamedev/xess.html); [PCGH](https://www.pcgameshardware.de/Intel-Arc-Grafikkarte-267650/News/XeSS-3-mit-Multi-Frame-Generation-1490211/galerie/4108491/).
- **RUMOUR (Apr 2026):** discrete Arc "Celestial" was cancelled "long ago", there are "no gaming GPUs" on Xe3P, and the B770 is in limbo — [Club386](https://www.club386.com/?p=142417); [igor'sLAB](https://www.igorslab.de/intel-arc-celestial-bericht-sieht-keine-diskrete-gaming-gpu-auf-xe3p-basis-mehr/).
- No Intel generative-NR announcement was found. The only DLSS-NR-on-Intel effort is a community reimplementation at about 2.4–3 fps on an Arc 140V (section 3).

#### Microsoft DirectX
- **Cooperative vectors** were announced 2025-01-06 **[older]** — [DirectX Dev Blog](https://devblogs.microsoft.com/directx/enabling-neural-rendering-in-directx-cooperative-vector-support-coming-soon/).
- **GDC 2026** (Mar 2026) — [igor'sLAB](https://www.igorslab.de/en/microsoft-is-making-directx-ready-for-the-ml-era-shader-stuttering-is-set-to-disappear-dxr-2-0-is-already-in-the-pipeline/):
  - **Shader Model 6.9 is retail** in Agility SDK 1.619, including cooperative vectors.
  - **DirectX Linear Algebra** public preview: April 2026.
  - **DirectX Compute Graph Compiler** private preview: summer 2026.
  - **DXR 2.0 + SM 6.10** preview (Opacity Micromaps, RT Tier 2.0): "late summer 2026".
  - AMD, Intel, NVIDIA and Qualcomm committed to day-one support.
  - Advanced Shader Delivery targets shader stutter.
- **SM 6.10 + Agility SDK 1.720-preview** shipped 2026-04-27 with `linalg::Matrix`, Group Wave Index, variable groupshared memory, RT intrinsics and batched async command lists. Preview drivers came from AMD, Intel and NVIDIA — [DirectX Dev Blog, 2026-04-27](https://devblogs.microsoft.com/directx/shader-model-6-10-agilitysdk-720-preview/); [Wccftech](https://wccftech.com/microsoft-shader-model-6-10-agilitysdk-720-preview-now-available-dx12-neural-rendering/amp/).
- **DirectSR** (preview since 2024) had "limited attention… adoption" — [TechRadar](https://www.techradar.com/computing/gpu/microsoft-underlines-how-directsr-tech-will-bring-upscaling-to-many-more-pc-games-but-theres-a-catch) **[older]**.

#### Vulkan
- **VK_NV_cooperative_vector** (NVIDIA) accelerates small neural networks in shaders — [Vulkan docs](https://docs.vulkan.org/features/latest/features/proposals/VK_NV_cooperative_vector.html).
- **VK_KHR_cooperative_matrix** is cross-vendor, supported in Mesa RADV (23.3) and Intel ANV (24.0) — [Phoronix](https://www.phoronix.com/news/Intel-ANV-Cooperative-Matrix) **[older]**.
- **Vulkan 1.4.352** (2026-05-15) added VK_NV_cooperative_matrix_decode_vector — [Phoronix](https://phoronix.com/news/Vulkan-1.4.352-Released).
- **Vulkan 1.4.359** (2026-08-07) added VK_EXT_cooperative_matrix_maintenance1 — [Phoronix](https://www.phoronix.com/news/Vulkan-1.4.359).

#### Consoles
- **Sony/AMD Project Amethyst** (Oct 2025): **Neural Arrays** (CUs acting "like a single, focused AI engine"), **Radiance Cores** (dedicated ray-traversal hardware for "unified light transport") and **Universal Compression** — [TweakTown](https://www.tweaktown.com/news/108160/sony-confirms-new-ps6-tech-radiance-cores-neural-arrays-and-universal-compression/index.html) **[older]**. The same features are rumoured for RDNA 5 — [TweakTown](https://tweaktown.com/news/112289/amds-rdna-5-radeon-gpus-will-launch-in-mid-2027-per-new-leak/index.html).
- **PS6 timing.** In May 2026 Sony CEO Hiroki Totoki told the WSJ that PS6 launch timing and price are undecided, with memory prices expected to stay high through FY2027 — [Push Square, May 2026](https://pushsquare.com/news/2026/05/ps6-release-date-and-price-not-decided-yet-says-sony); [TheSixthAxis, 2026-05-08](https://www.thesixthaxis.com/2026/05/08/sony-ps6-launch-date-price/). **RUMOUR:** Nov 2027, or 2028–2029.
- **Xbox Project Helix** (GDC, 2026-03-11) — [Xbox Wire](https://news.xbox.com/en-us/?p=218661):
  - A custom AMD SoC "co-designed for the next generation of DirectX and FSR".
  - An "order of magnitude leap in ray tracing performance".
  - It "integrates intelligence directly into the graphics and compute pipeline" and plays Xbox console and PC games.
  - **Alpha dev kits in 2027.**
  - Lisa Su said AMD is ready for a 2027 Xbox launch as the best case, with 2028 possible — [Gamereactor](https://www.gamereactor.eu/report-next-gen-xbox-could-have-multiple-build-options-huge-price-increase-and-swerve-2027-release-date-1671653/).

### Inferences
- **Through 2027 there will be no cross-vendor generative-NR standard.** AMD's rumoured approach is engine-integrated and needs geometry, which favours YaE's native engine over frame injection. Design the engine to export clean G-buffers (albedo, normals, depth, motion, roughness/metal, emissive), so that DLSS 5 (via Streamline), FSR Diamond/5 or future XeSS can plug in.
- **Vendor-neutral neural pieces are realistic for a native engine by 2027:**
  - Neural texture compression.
  - Neural radiance caching, as in FSR Redstone's Radiance Caching and NVIDIA's NRC.
  - Small neural materials using SM 6.9 cooperative vectors, SM 6.10 linalg or Vulkan cooperative matrix.
  - ML denoising (Ray Regeneration / Ray Reconstruction) for path tracing on mainstream RDNA 4, RTX 40/50 and next-gen consoles.
- **Coverage planning for Project Empty:**
  - Path tracing plus ML denoise is the cross-vendor mainstream target: RTX 40/50, RDNA 4, consoles from 2027–28.
  - Generative NR is an NVIDIA-RTX-50 extra; RTX 40 comes later with limited controls.
  - RTX 20/30, RDNA 2/3 and Intel Arc need a non-neural or light-ML fallback: DLSS 4.5 model K or FSR 4.1 INT8 upscaling, and baked or ReSTIR-lite GI.
  - Slower hardware turnover caused by memory prices makes that fallback more important, not less.
- **Dead ends to avoid:**
  - Betting on Intel discrete hardware for advanced features.
  - Waiting for DirectSR to unify upscalers.
  - Assuming console-class neural rendering before 2028.

### Gaps
- No official AMD or Intel product that is a generative NR equivalent to DLSS 5 exists or has been announced as of 2026-10-07. Everything here is rumour or Xbox-specific.
- Whether the DXR 2.0 preview actually shipped in late summer 2026 was not verified.
- No cross-vendor Khronos cooperative-*vector* (KHR/EXT) extension was found.
- RTX 60, RDNA 5 and Helix/PS6 specifications and dates are unconfirmed.
- Whether NVIDIA plans to integrate DLSS 5 NR into RTX Remix officially is unknown; nothing found.
