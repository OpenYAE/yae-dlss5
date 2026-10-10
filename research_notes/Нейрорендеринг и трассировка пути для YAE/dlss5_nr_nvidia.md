# NVIDIA DLSS 5 Neural Rendering (DLSS-NR, `nvngx_dlssnr.dll`): the official product, GPU support and the community injection ecosystem (as of 2026-10-07)

Labels used below: **[official]** = NVIDIA page, NVIDIA code or NVIDIA release; **[code]** = read directly from source code or a config file during this research; **[release notes]** = a GitHub release or README written by the tool's author; **[press]** = tech press; **[forum/user]** = forum posts, issue reports and user claims; **[community RE]** = community reverse-engineering. Star counts and "last push" dates were read through the GitHub API on 2026-10-07.

Naming: NVIDIA markets it as "DLSS 5 with 3D-Guided Neural Rendering". The runtime is `nvngx_dlssnr.dll` (Product Name "NVIDIA DLSSNR"), NGX feature ID 18. NVIDIA's own RTX Remix code calls the effect "DLSS 3D-Guided Neural Generation", and the NVIDIA research report is titled "DLSS 5: Generative Neural Rendering".

## 1. What DLSS 5 / DLSS Neural Rendering is: dates, function, model versions, controls, inputs, temporal behaviour

### Takeaway
DLSS 5 Neural Rendering is a same-resolution, one-frame-in/one-frame-out generative pass that re-lights the finished frame. NVIDIA describes it as a one-step pixel-space diffusion model. It changes tone, lighting, materials, structure and skin, and it is not an upscaler. NVIDIA announced it at GTC on 16 March 2026 and shipped it on 3 September 2026 (runtime 310.8.0). NVIDIA's own RTX Remix code exposes the full official parameter set: Intensity, LocalTone, LocalStructure, GlobalTone, SkinStructure, Style (Model A/B/C), UseAutoMask with a per-pixel control mask, depth, motion vectors and a history reset. The pass works in the SDR/LDR domain.

### Cited Findings

#### Timeline
- **16 Mar 2026 [press]:** NVIDIA revealed DLSS 5 at GTC 2026. Jensen Huang called it "the GPT moment for graphics". It was promised for fall 2026 on RTX 50 only. — [Ubergizmo, Mar 2026](https://www.ubergizmo.com/2026/03/nvidia-dlss-5/); [Wccftech](https://wccftech.com/nvidia-dlss-5-game-changing-visuals/amp/); [Techloy](https://www.techloy.com/nvidia-dlss-5-everything-you-need-to-know-about-the-ai-graphics-update-coming-in-2026/)
- **GTC showcase titles [press]:** Resident Evil Requiem, Hogwarts Legacy, Starfield and Assassin's Creed Shadows. — [Notebookcheck (DE)](https://www.notebookcheck.com/Nvidia-bestaetigt-Launch-von-DLSS-5-mit-Neural-Rendering-noch-fuer-dieses-Jahr.1252355.0.html)
- **GTC demo hardware [official]:** the reveal ran on two RTX 5090s. NVIDIA says pipeline and model changes later made it about 5x faster in six months, so it runs on one GPU. — [NVIDIA GeForce News, 1 Sep 2026](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/); also [mezha.net](https://mezha.net/eng/news/28c3c32c_nvidia_will_launch_dlss/)
- **~27–28 Aug 2026 [press, release]:** `nvngx_dlssnr.dll` 310.8.0.0 leaked from the early-access PC build of NBA 2K27. — [XDA](https://www.xda-developers.com/nvidia-dlss-5-has-leaked-modders-are-already-creating-uncanny-valley-nightmares/); [LTT forum](https://linustechtips.com/topic/1642227-dlss-5-dll-leaked-from-early-access-build-of-nba2k27-feature-control-already-exposed-for-control/)
  - The first public mirror is the `dlssnr-310.8.0` release on RankFTW/rhi-repo, published 2026-08-27 10:42 UTC. — [rhi-repo release](https://github.com/RankFTW/rhi-repo/releases/tag/dlssnr-310.8.0)
- **1 Sep 2026 [official]:** NVIDIA announced the launch. NVIDIA Research (ADLR) published a project page the same day. — [NVIDIA GeForce News](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/); [NVIDIA ADLR DLSS 5 page](https://research.nvidia.com/labs/adlr/DLSS5/)
- **3 Sep 2026, 9 PM PT [official]:** DLSS 5 launched in NBA 2K27 with Game Ready Driver 616.64 WHQL. — [NVIDIA GeForce News, 3 Sep 2026](https://www.nvidia.com/en-eu/geforce/news/nba-2k27-dlss-5-3d-guided-neural-rendering-geforce-game-ready-driver/); [VideoCardz](https://videocardz.com/newz/nvidia-dlss-5-gets-5x-faster-in-six-months-launches-september-3-on-all-rtx-50-gpus)
- **22 Sep 2026 [official]:** NVIDIA's developer blog recap of DLSS 5. It names no public SDK. — [NVIDIA Developer Blog](https://developer.nvidia.com/blog/whats-new-for-game-developers-dlss-5-with-3d-guided-neural-rendering-nvidia-ace-updates-and-new-rtx-kit-capabilities/)

#### What it does
- **Official description [official]:**
  - It is the final stage of the rendering pipeline. It "infuses" the engine frame with lifelike lighting and materials while "the engine frame defines what must remain".
  - Named effects: skin subsurface scattering, light transmission through hair and foliage, deeper contact shadows, and global-illumination-like effects.
  - It is deterministic: identical input frames give identical output.
  - Source: [NVIDIA GeForce News, 1 Sep 2026](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/)
- **Research description [official]:**
  - A "one-step pixel-space diffusion model designed for high-resolution, real-time rendering".
  - Its inputs are the current rendered frame, engine motion vectors, carried temporal state and artistic-direction values.
  - It is "trained for frame-to-frame temporal stability", grounded by "consistency supervision from renderer-derived scene attributes" and trained on real-world visual data.
  - It runs in real time at up to 4K on RTX 50.
  - The full PDF report returned HTTP 403 during this research.
  - Source: [NVIDIA ADLR DLSS 5 page](https://research.nvidia.com/labs/adlr/DLSS5/)
- **NVIDIA's 3 Sep launch article describes a "diffusion transformer" running "1 frame in 1 frame out" [official; paraphrased by the fetch tool, wording not checked verbatim].** — [NVIDIA GeForce News, 3 Sep 2026](https://www.nvidia.com/en-eu/geforce/news/nba-2k27-dlss-5-3d-guided-neural-rendering-geforce-game-ready-driver/)
- **Same resolution in and out [community RE]:** NR is not an upscaler. Community ports therefore run it before super resolution, at render resolution, to save cost (section 5). — [OpenDLSS-NR README](https://github.com/maanHimself/OpenDLSS-NR); [dlss5-nr-pre-upscale README](https://github.com/Xeakaes/dlss5-nr-pre-upscale)

#### Runtime, model and network facts
- **The DLL [code, release notes]:**
  - `nvngx_dlssnr.dll` 310.8.0.0 is 165,840,496 bytes (about 158 MB) and signed by NVIDIA.
  - It is NVIDIA's largest DLSS DLL so far.
  - Sources: [YAE package README.txt](../../README.txt); [OC3D](https://overclock3d.net/news/software/nvidia-dlss-5-neural-rendering-dll-files-leak-launch-incoming/)
- **Network architecture [community RE]:**
  - A U-Net of 71 blocks / 152 layers: shifted-window (Swin) transformer blocks with global ViT blocks at the bottom.
  - FP8 (E4M3) activations and weights with FP16 accumulation, about 141 MiB of weights.
  - Inputs: an LDR proxy of the frame, 3 lanes of Gaussian noise, the previous output reprojected, and 5 conditioning scalars.
  - Outputs: 4 f32 channels per pixel, namely an RGB residual and one temporal-blend logit.
  - The authors claim bit-exact parity with the original. These are not NVIDIA statements.
  - Sources: [OpenDLSS-NR README](https://github.com/maanHimself/OpenDLSS-NR); [dlssnr-pytorch README](https://github.com/mauri870/dlssnr-pytorch)
- **Version line [official, code]:**
  - Only 310.8.0 is known in the wild.
  - The public DLSS SDK reached 310.9.1 on 2026-09-08. It ships only `nvngx_dlss`, `nvngx_dlssd` and `nvngx_dlssg`, with no NR DLL.
  - I found no newer NR runtime as of 2026-10-07.
  - Sources: [NVIDIA/DLSS v310.9.1](https://github.com/NVIDIA/DLSS/releases/tag/v310.9.1); [rhi-repo releases](https://github.com/RankFTW/rhi-repo/releases)
- **Modified 310.8 builds circulating [release notes]:** none is official.
  - `310.8.0-RTX40` (2026-08-30)
  - `310.8.SF` and `310.8.SF-v2` (2026-08-30), the ShortFuse cross-generation builds
  - `310.8.Lecram` (2026-09-24)
  - Source: [rhi-repo releases](https://github.com/RankFTW/rhi-repo/releases)

#### Official controls and inputs
NVIDIA's RTX Remix runtime is public on GitHub. Its 2026-09-18 commit drives NR through NVIDIA's private NR headers, which gives the authoritative parameter list.

- **Evaluate parameters [code, official]:** `NVSDK_NGX_VK_DLSSNR_Eval_Params` contains:
  - `pInColor`, `pInOutput`, `pInMVec`, `pInDepth`
  - `pInControlMask`, which is null when Auto Mask is on
  - `InReset`, `InDepthInverted`, `InEnabled`
  - `InIntensity`, `InLocalToneStrength`, `InLocalStructureStrength`
  - `InGlobalToneStrength` (Remix fixes it at 1.0)
  - `InStyle` (= the chosen model), `InUseAutoMask`, `InSkinStructureStrength`
  - `InMVecScaleX/Y` and the colour, output, MV, depth and mask sub-rects
  - The feature is created with `NGX_VULKAN_CREATE_DLSSNR_EXT1` and run with `NGX_VULKAN_EVALUATE_DLSSNR_EXT`.
  - Support is queried through `NVSDK_NGX_Parameter_DLSSNR_Available`, `_NeedsUpdatedDriver`, `_MinDriverVersionMajor/Minor` and `_FeatureInitResult`.
  - Source: [dxvk-remix rtx_ngx_wrapper.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_ngx_wrapper.cpp)
- **Remix's documented NR options and defaults [code, official]:**

  | Option | Default | Range / values | Official description |
  |---|---|---|---|
  | `rtx.dlssNeuralRendering.enable` | false | | |
  | `.intensity` | 1 | 0–1 | |
  | `.model` | 0 | "0: Model A, 1: Model B, 2: Model C" | "Their appearance is content-dependent" |
  | `.structuralStrength` | 0.7 | 0–1 | "details, shadows, and materials" |
  | `.toneStrength` | 0.3 | 0–1 | "lightness, darkness, and color" |
  | `.skinStructureStrength` | 0.5 | 0–1 | adjustments to characters, only with Auto Mask on |
  | `.useAutoMask` | false | | "automatic character mask instead of the material control mask" |
  | `.enableVolumetricControlMask` | true | | modulates the control mask by fog, volumetrics and alpha-blended transmittance |
  | `.enableHighlightRecovery` | true | | "Recover highlights compressed by … LDR-domain processing" |

  Source: [dxvk-remix RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md)
- **Marketing names for the same controls [official]:**
  - "multiple AI models with different parameter weights" = the Style / Model selector
  - "Structure Intensity" (high-frequency detail such as AO and SSS)
  - "Tone Intensity" (low-frequency lighting and colour response)
  - "semantic AI masking" (= Auto Mask)
  - "engine-level masking" of props and asset groups
  - "per-pixel uplift control masks"
  - Sources: [NVIDIA GeForce News, 1 Sep 2026](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/); [NVIDIA Developer Blog, 22 Sep 2026](https://developer.nvidia.com/blog/whats-new-for-game-developers-dlss-5-with-3d-guided-neural-rendering-nvidia-ace-updates-and-new-rtx-kit-capabilities/)
- **NR runs in SDR [code, official]:**
  - Remix's code comment reads: "DLSS-NR operates in SDR space; inverse tone mapping restores HDR for downstream post-processing."
  - Remix's order is: auto-exposure, then a fast forward tone map, then NR, then an inverse tone map, then bloom, motion blur, the main tone mapping and lens effects. The HUD is drawn later, at present.
  - NR is dispatched after DLSS SR/RR. When RR is active it uses the RR depth and MV guides.
  - Sources: [dxvk-remix rtx_context.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_context.cpp); [dxvk-remix rtx_dlss_neural_rendering.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_dlss_neural_rendering.cpp)
- **Neutral reference values [community RE]:** the controls NVIDIA's reference frames were made with are intensity 1.0, style 0, local_tone 1.0, local_structure 1.0, skin_structure −1.0 ("follow local structure") and auto_mask true. — [dlssnr-pytorch README](https://github.com/mauri870/dlssnr-pytorch)
- **What OptiScaler_DLSSNR v0.2.0 exposes [code, YAE package]:**
  - NVIDIA's parameters: Preset, Style, Intensity, LocalStructure, LocalTone, SkinStructure (−1 = model default) and AutoMask (default true).
  - Preset is baked in when the feature is created. The author notes that NR's preset scale is not the SR/RR one, and that the presets and styles are undocumented.
  - Source: [payload/host64/OptiScaler.ini [DlssNr]](../../payload/host64/OptiScaler.ini)
- **Undocumented caller check [release notes]:** the model refuses calls from any module whose path does not contain `nvngx.dll`. That is why Dagherbou's fork ships a forwarder named `nvngx.dll_dlssnr.dll`. — [Dagherbou v0.2.0 release notes](https://github.com/Dagherbou/OptiScaler_DLSSNR/releases/tag/v0.2.0-dlssnr)
- **Supported APIs [release notes, code]:**
  - The model works on D3D12 and Vulkan only, not D3D11. D3D11 games reach it through a D3D11-on-12 bridge. — [y4my4my4m fork v4 notes](https://github.com/y4my4my4m/OptiScaler_DLSSNR_Multipass_MFG/releases/tag/v10.0.0-dev-fork-y4my4my4m-v4)
  - Remix uses the Vulkan entry points. — [rtx_ngx_wrapper.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_ngx_wrapper.cpp)
  - NVIDIA ships no 32-bit NGX at all. — [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder)

#### Temporal behaviour and history
- **Official [official]:** "a strict one-frame-in, one-frame-out model". It uses engine motion vectors to remove "shimmering and temporal drift". — [NVIDIA GeForce News](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/)
  - The research page lists "carried temporal state" as an input. — [ADLR](https://research.nvidia.com/labs/adlr/DLSS5/)
  - Remix passes `InReset` when the history is reset. — [rtx_ngx_wrapper.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_ngx_wrapper.cpp)
- **Mechanism [community RE]:** the history is the previous output, reprojected with the motion vectors, blended per pixel by a network-predicted logit. — [OpenDLSS-NR README](https://github.com/maanHimself/OpenDLSS-NR)
- **Position in the frame [press]:** NR runs after upscaling and before frame generation, which Digital Foundry calls "tailor-made for frame gen". — [ResetEra DF thread, 6 Sep 2026](https://www.resetera.com/threads/digital-foundry-dlss-5-tested-nba-2k27-image-quality-benchmarks-mods-and-more.1625434/)
- **With frame generation in community tools [release notes]:** the pass runs once per rendered frame and generated frames inherit the result. — [YAE package OptiScaler readme](<../../payload/host64/READ ME - DLSS Neural Rendering.txt>)

### Inferences
- Official evidence says the network needs only colour and motion vectors plus a history reset; NVIDIA's marketing likewise says colour plus motion vectors. Depth is an evaluate input in NVIDIA's API, but the community reimplementations list no depth lane in the network itself. Depth is therefore most likely used for reprojection and disocclusion rather than read by the network. This is an inference from community RE, not documented.
- The LDR-domain processing confirmed in Remix fits You Are Empty, which is an 8-bit SDR OpenGL game. No inverse tone map is needed, and OptiScaler's own composition passes a tone-mapped frame through untouched.
- Remix's defaults (tone 0.3, structure 0.7, skin 0.5, Auto Mask off with a material mask) are NVIDIA's own tuned starting point for an old-game remaster. They are far more conservative than the community reference values (tone and structure 1.0). This is a useful baseline for a dark horror game.

### Gaps
- The full NVIDIA research PDF (`DLSS5_Report.pdf`) returned HTTP 403 to both WebFetch and curl, so training details, parameter count and stated limitations come only from the project page and community RE.
- I found no official documentation of what the Preset value does, or of what distinguishes Models A, B and C beyond "content-dependent".
- I found no official statement of the exact VRAM footprint per resolution (only Digital Foundry's 731 MB peak; see section 3).

## 2. Official delivery: games, SDK availability, NVIDIA App, RTX Remix

### Takeaway
As of 2026-10-07, NBA 2K27 is the only shipping DLSS 5 game confirmed by NVIDIA. More titles are announced for "fall". There is no public SDK: the public DLSS SDK 310.9.1 and Streamline 2.14.1 contain no NR binary, header or plugin, and the public NGX header lists feature 18 as `Reserved18`. Developer access appears limited to partners. The one notable official exception is the RTX Remix runtime's main branch, which integrated NR on 2026-09-18 through a private NVIDIA header package. That integration is not yet in a tagged Remix release.

### Cited Findings
- **The only launch game [official]:** NBA 2K27 (Visual Concepts / 2K), on 3 Sep 2026. — [NVIDIA GeForce News](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/)
  - It is also available on GeForce NOW Ultimate (RTX 5080 rigs). — [VideoCardz](https://videocardz.com/newz/nvidia-dlss-5-gets-5x-faster-in-six-months-launches-september-3-on-all-rtx-50-gpus)
- **Announced later titles [press, unverified on an NVIDIA page]:** AION 2, Assassin's Creed Shadows, Black State, CINDER CITY, Delta Force, Hogwarts Legacy, Justice, NARAKA: BLADEPOINT, NTE, Phantom Blade Zero, Resident Evil Requiem, Sea of Remnants, Starfield, Oblivion Remastered and Where Winds Meet. — [blockchain-council summary](https://www.blockchain-council.org/ai/dlss-5-release-timeline-supported-games/); [ElevenForum](https://www.elevenforum.com/t/nvidia-dlss-5-available-september-3-2026.49142/)
  - Press coverage through mid-September lists NBA 2K27 as the only shipping title. I found no other game shipping DLSS 5 as of 2026-10-07. — [tech-insider](https://tech-insider.org/nvidia-dlss-5-rtx-40-gpus-no-full-control-2026/)
- **Official integration routes [official]:** Streamline and an Unreal Engine 5 plugin. DLSS 5 is an optional feature that runs independently of SR, MFG and RR. — [NVIDIA GeForce News, 1 Sep 2026](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/)
- **No public SDK [official, code]:**
  - The DLSS SDK 310.9.1 release (2026-09-08) only "Added DLSS Ray Reconstruction Transformer Mode (Preset F)". Its `lib/` holds only dlss, dlssd and dlssg. — [NVIDIA/DLSS v310.9.1](https://github.com/NVIDIA/DLSS/releases/tag/v310.9.1)
  - The public `nvsdk_ngx_defs.h` lists `NVSDK_NGX_Feature_Reserved18 = 18`, with no named NR feature. — [NVIDIA/DLSS include/nvsdk_ngx_defs.h](https://github.com/NVIDIA/DLSS/blob/main/include/nvsdk_ngx_defs.h)
  - Streamline 2.14.1 (2026-09-08) has only `sl_dlss.h`, `sl_dlss_d.h` and `sl_dlss_g.h`, and its notes mention only Dynamic MFG V-Sync/limiter support and `VK_NV_low_latency2`. — [Streamline v2.14.1](https://github.com/NVIDIA-RTX/Streamline/releases/tag/v2.14.1)
  - NVIDIA's 22 Sep developer blog gives no SDK, early-access or UE5 plugin download details for DLSS 5. — [NVIDIA Developer Blog](https://developer.nvidia.com/blog/whats-new-for-game-developers-dlss-5-with-3d-guided-neural-rendering-nvidia-ace-updates-and-new-rtx-kit-capabilities/)
- **Developer forum [forum/user]:** a 2026-09-08 thread asks for official DLSS 5 SDK / UE 5.8.2 plugin access. By 2026-10-01 it had no NVIDIA staff answer. One developer wrote: "We're a bit left in the cold, while the big studios get to generate a couple of showcase marketing packages." — [NVIDIA Developer Forums](https://forums.developer.nvidia.com/t/official-dlss-5-neural-rendering-plugin-access-for-unreal-engine-5-8-2/382731)
- **Official RTX Remix integration [code, official]:**
  - Commit `ecf646d3ea` on NVIDIAGameWorks/dxvk-remix (2026-09-18), "[REMIX-5351][REMIX-5935][REMIX-6028] DLSS 3D-Guided Neural Generation Integration", adds:
    - `rtx_dlss_neural_rendering.cpp/.h`
    - NR options in `RtxOptions.md`
    - Remix API fields (`remix.h`, `remix_c.h`)
    - per-material control-mask data
    - fast and inverse tone-mapping passes
    - Source: [commit ecf646d3ea](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/ecf646d3ea)
  - A 2026-09-29 commit ("Enabling DLSSNR in Windows-on-Arm builds") followed. — [commit history](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main/src/dxvk/rtx_render/rtx_ngx_wrapper.cpp)
  - The headers (`nvsdk_ngx_defs_dlssnr.h`, `nvsdk_ngx_helpers_dlssnr_vk.h`) come from a packman package named `rtx-remix-ngx_sdk_dlnr`, not from a public repo. — [packman-external.xml](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/packman-external.xml)
  - The latest tagged Remix release is still remix-1.5.2 (2026-06-16), from before the integration. — [rtx-remix releases](https://github.com/NVIDIAGameWorks/rtx-remix/releases)
- **Community use of the Remix route [release notes]:** DLSS5-Autopilot offers a "remix" route, where "DLSS 5 runs inside the Remix runtime, after its upscaler. Nothing injected". It says ReShade crashes a Remix game before it draws. — [DLSS5-Autopilot README](https://github.com/Kizzuwatnaa/DLSS5-Autopilot)
- **No official Remix announcement found:** a web search for an NVIDIA announcement of DLSS 5 in RTX Remix returned only the general DLSS 5 developer posts. — [search result list incl. GameDev.net mirror of the NVIDIA dev blog](https://gamedev.net/news/whats-new-for-game-developers-dlss-5-with-3d-guided-neural-rendering-nvidia-ace-updates-and-new-rtx-kit-capabilities-r5948/)
- **NVIDIA App [official, press]:**
  - The 3 Sep driver article lists NVIDIA App items: per-game Resizable BAR, borderless windowed support, and FPS limiter / V-Sync support with Dynamic MFG.
  - The app's DLSS overrides exist globally and per game, but I found no NVIDIA statement that the app overrides or toggles DLSS 5 NR.
  - In NBA 2K27 the option is in the game's settings.
  - Sources: [NVIDIA GeForce News, 3 Sep 2026](https://www.nvidia.com/en-eu/geforce/news/nba-2k27-dlss-5-3d-guided-neural-rendering-geforce-game-ready-driver/); [NVIDIA App global overrides article](https://www.nvidia.com/en-us/geforce/news/nvidia-app-update-5-geforce-game-ready-driver/)
- **Official way to get the DLL [release notes]:** none. Community tools say it comes from a driver package or the NBA 2K27 install, and that it must sit beside the game, with no shared system location. — [YAE package OptiScaler readme](<../../payload/host64/READ ME - DLSS Neural Rendering.txt>); [YAE README.txt](../../README.txt)

### Inferences
- NR is in effect an NDA/partner feature. The only publicly readable official integration is RTX Remix's main branch. That integration matters for a remaster such as You Are Empty: an RTX Remix mod would get NVIDIA's own NR integration (before the UI, with a material control mask and LDR handling) without community injectors, once a Remix build including it is released. You Are Empty is OpenGL rather than D3D8/9, so Remix compatibility is a separate question.
- Because the public NGX headers lack the NR structs, every community tool depends on reverse-engineered structs. The parameter names in NVIDIA's open Remix code are now the best public reference for them.

### Gaps
- I could not confirm whether NVIDIA App 11.x exposes any DLSS 5 override; the 2K support page for NBA 2K27 DLSS 5 returned 403.
- No dated, NVIDIA-sourced list of DLSS 5 games beyond NBA 2K27 was retrievable. The fall list above comes from secondary aggregators.
- I found no information on whether any Remix nightly or CI build artifact including NR is publicly downloadable.

## 3. Official GPU support and the reasons; precision; measured cost and VRAM

### Takeaway
Officially DLSS 5 runs on all GeForce RTX 50 desktop and laptop GPUs and on GeForce NOW Ultimate. NVIDIA has said RTX 40 support will come after RTX 50 tuning and a fall model update, with no date as of 2026-10-07. Nothing has been said about RTX 20 or 30. The model is FP8 (E4M3) with Blackwell-only CUDA kernels (NGX arch gate `Blackwell2`).

On RTX 50 the pass costs about 8 ms at 4K on an RTX 5090 (Digital Foundry), roughly halving native frame rate, with a peak of about 731 MB of VRAM. Derived costs are about 14.5 ms on an RTX 5080 at 4K, about 10.5 ms on an RTX 5070 at 1440p and about 10.7 ms on an RTX 5060 at 1080p.

### Cited Findings
- **Official support [official]:**
  - "All GeForce RTX 50 Series GPUs and laptop GPUs support DLSS 5", plus GeForce NOW Ultimate. — [NVIDIA GeForce News, 1 Sep 2026](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/)
  - It "leverages Tensor Cores of GeForce RTX 50 Series GPUs" and runs "locally on a single GeForce RTX 50 Series GPU at up to 4K". — [NVIDIA Developer Blog, 22 Sep 2026](https://developer.nvidia.com/blog/whats-new-for-game-developers-dlss-5-with-3d-guided-neural-rendering-nvidia-ace-updates-and-new-rtx-kit-capabilities/)
- **RTX 40 statement [official via press]:**
  - NVIDIA spokesperson Rajal Maharaj told The Verge on 4 Sep 2026: "Our current focus is on optimizing performance for the GeForce RTX 50 Series with model updates expected later this fall. Once RTX 50 Series performance is more fully tuned, we plan to work on expanding official support to the GeForce RTX 40 Series."
  - No date, driver or performance target was given, and nothing was said about RTX 20/30.
  - Sources: [Wccftech](https://wccftech.com/nvidia-dlss-5-rtx-40-gpus-support-confirmed/); [tbreak](https://tbreak.com/nvidia-dlss-5-rtx-40-support/); [iXBT, 4 Sep 2026](https://ixbt.games/en/news/2026/09/04/432463-nvidia-podtverdila-dlss-5-dlia-rtx-40-texnologiia-bolse-ne-budet-ekskliuzivom-rtx-50.html); [tech-insider (cites The Verge)](https://tech-insider.org/nvidia-dlss-5-rtx-40-gpus-no-full-control-2026/)
  - As of that article's mid-September cutoff there was no RTX 40 release. I found no later report of one up to 2026-10-07.
- **Precision and architecture gating [code]:**
  - The DLL holds CUDA fatbins with PTX and ELF images.
  - The NR kernels use FP8 E4M3 conversions (`cvt.rn.satfinite.e4m3x2.f16x2`) and FP8 tensor-core MMA (`mma.sync.aligned.m16n8k32.row.col.f16.e4m3.e4m3.f16`).
  - NGX architecture IDs in the patcher: Turing 0x160, Ampere 0x170, Ada 0x190, Blackwell2 0x1B0. The patcher rewrites both the kernels and the architecture "requirement" cases.
  - The patcher's comment: "Pre-Ada GPUs execute the source E4M3 path through integer conversions and FP16 MMAs, so results and performance can differ from native FP8."
  - Source: [dev-camo/dlssnr-patcher dlssnr_patcher.py](https://github.com/dev-camo/dlssnr-patcher/blob/main/dlssnr_patcher.py)
- **Precision, other sources [community RE, release notes]:**
  - "FP8 (E4M3) activations with FP16 accumulation". — [OpenDLSS-NR](https://github.com/maanHimself/OpenDLSS-NR)
  - "the DLSS 5 model is FP8 with RTX-50-only kernels". — [DLSS5oneclick README](https://github.com/faisalkindi/DLSS5oneclick)
  - FP4 is not used by NVIDIA's shipped model. A community "NVFP4 hybrid" exists only in wilsjo2's fork, for Blackwell (section 5).
- **Why the cost is high on Ada [press]:** Ada's 4th-gen tensor cores "appear to be straining" on FP8-heavy work that Blackwell's 5th-gen tensor cores were built for. This is press reasoning, not an NVIDIA statement. — [tech-insider](https://tech-insider.org/dlss-5-patched-rtx-4000-ada-lovelace-2026/)
- **Digital Foundry measurements in NBA 2K27 [press, via ResetEra summary, 6 Sep 2026]:**

  | GPU | Resolution | Without NR | With NR |
  |---|---|---|---|
  | RTX 5090 | 4K max | 128 fps | 63 fps |
  | RTX 5080 | 4K max | 95 fps | 40 fps |
  | RTX 5070 | 1440p max | 120 fps | 53 fps |
  | RTX 5060 | 1080p High+RT | 70 fps | 40 fps |

  - About an "8 millisecond cost when running at 4K on a 5090".
  - Peak GPU memory 731 MB.
  - An RTX 5070 reaches 190 fps at 1440p with DLSS 5 and frame generation.
  - Source: [ResetEra DF thread](https://www.resetera.com/threads/digital-foundry-dlss-5-tested-nba-2k27-image-quality-benchmarks-mods-and-more.1625434/)
  - The thread's "from 8 ms to 13 ms" line for the RTX 5080 is ambiguous. It most plausibly means the NR cost per GPU.
- **Other press measurements [press]:**
  - RTX 5090 at 4K/Ultra: 128.4 → 62.7 fps (−51.2%), most likely relaying DF's run; Notebookcheck returned 403, so these numbers are from search snippets. — [Notebookcheck](https://www.notebookcheck.net/First-DLSS-5-game-tested-DLSS-5-humbles-RTX-5090-with-over-50-performance-loss.1391978.0.html); [TheFPSReview](https://www.thefpsreview.com/2026/09/05/the-fps-review-weekender-dlss-5-arrives-in-nba-2k27-and-costs-half-your-frame-rate-plus-11-more-hardware-reviews/)
  - GameGPU, with different settings: RTX 5090 at 4K, 162 → 68 fps. — [GameGPU](https://en.gamegpu.com/news/igry/dlss-5-snizil-proizvoditelnost-rtx-5090-v-nba-2k27-v-2-5-raza-s-162-do-68-fps-v-4k)
- **NVIDIA's marketing numbers [official]:** these include SR and MFG.
  - NBA 2K27 at 4K Ultra with RT: up to 370 fps on an RTX 5090.
  - At 1440p: 590 fps (5090), 410 fps (5080), 350 fps (5070 Ti), 260 fps (5070).
  - Source: [NVIDIA GeForce News](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/)
  - RTX 5060: 258 fps at 1080p with DLSS Quality and 6X MFG. — [TweakTown](https://www.tweaktown.com/news/113375/nvidias-dlss-5-benchmarks-show-the-rtx-5060-hitting-250-plus-fps-in-nba-2k27/index.html)
- **Leaked-DLL results on RTX 50 [press]:**
  - RTX 5070 in Cyberpunk 2077 at 1440p: raster 138 → 68 fps; RT Ultra 111 → 55; path tracing 71 → 45.
  - RTX 5070 Ti in Control at 4K: about 71 → 35 fps.
  - Sources: [The PC Enthusiast, 30 Aug 2026](https://thepcenthusiast.com/dlss-5-mod-games-rtx-50-40-30-gpus/); [MakeUseOf, 6 Sep 2026](https://www.makeuseof.com/how-to-install-nvidia-dlss-5-on-almost-any-rtx-gpu-in-minutes/)
- **Minimum driver [release notes, code]:**
  - 616.56 is the community-stated minimum. — [Dagherbou v0.2.0](https://github.com/Dagherbou/OptiScaler_DLSSNR/releases/tag/v0.2.0-dlssnr); [wilsjo2 v0.3.0](https://github.com/wilsjo2/OptiScaler-DLSSNR-PreSR-Multipass/releases/tag/v0.3.0-crossgen-portable)
  - 616.64 WHQL is the launch driver. — [NVIDIA](https://www.nvidia.com/en-eu/geforce/news/nba-2k27-dlss-5-3d-guided-neural-rendering-geforce-game-ready-driver/)
  - Remix checks `DLSSNR_NeedsUpdatedDriver` and the minimum driver version at runtime. — [rtx_ngx_wrapper.cpp](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/src/dxvk/rtx_render/rtx_ngx_wrapper.cpp)

### Inferences
- **Derived NR cost per frame** from the DF frame rates (1/fps_on − 1/fps_off):

  | GPU | Resolution | NR cost |
  |---|---|---|
  | RTX 5090 | 4K | ≈ 8.0 ms (matches DF's stated 8 ms) |
  | RTX 5080 | 4K | ≈ 14.5 ms |
  | RTX 5070 | 1440p | ≈ 10.5 ms |
  | RTX 5060 | 1080p | ≈ 10.7 ms |

  The cost scales roughly with pixel count and tensor throughput. On an RTX 5090 at 1080p, about 2 ms would be expected by pixel scaling, but that is not measured.
- The RTX 50 gate is a software/kernel gate (CUDA cubins for SM120 plus an NGX arch check), not a hard incompatibility. Ada has native FP8 MMA. Turing and Ampere must emulate E4M3 through FP16, which is why community tiers rank them as "heavy".
- NVIDIA's "fall model updates" for RTX 50 may also change the API or behaviour of the community-mirrored 310.8 runtime. Tools pinned to 310.8 hashes, such as the YAE installer, should expect a new runtime version.

### Gaps
- I found no official ms-per-resolution table from NVIDIA, and no measured NR cost at 1080p or 1440p on an RTX 5090 or 5080.
- Latency figures surfaced in search summaries (RTX 5070 at 1440p 20 → 39 ms; RTX 5060 34 → 63 ms) could not be tied to a verified source page and are not used here.
- I found no official explanation of why RTX 40 is not supported at launch beyond "optimization focus".

## 4. Community attempts to run the official `nvngx_dlssnr.dll` on RTX 20/30/40

### Takeaway
The original NVIDIA-signed 310.8.0 creates feature 18 only on RTX 50; elsewhere it fails with `0xbad00001`. Within days of the leak (28–30 Aug 2026), modders made modified runtimes that do run on older cards:

- Uncle Burrito's Ada build (RTX 40)
- ShortFuse's cross-generation `310.8.SF`, which selects an Ada path on RTX 40 and an FP16 path on RTX 20/30
- dev-camo's open-source patcher, which recompiles the fatbins for sm_75, sm_86 and sm_89 with exact FP8 emulation

The results work but are expensive. An RTX 4090 loses about 39% in Control. Ampere cards land around 20–40 fps at 720p–1440p. The modified DLLs break NVIDIA's Authenticode signature, and installers that check the signature, such as YAE's, reject them.

### Cited Findings
- **The original DLL fails on older cards [release notes, forum/user]:**
  - On an RTX 20/30/40 card, the original 310.8.0 and the modified 310.8.Lecram both fail: "feature 18 create failed with 0xbad00001", so DLSS antialiasing runs but no neural pass. — [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder)
  - An RTX 4080 Laptop on driver 616.56 failed with the RHI 310.8.0 build (SHA-256 E16BCF15…) and worked with a Discord-distributed modified 310.8.0.0 build (SHA-256 8270B350…). It was used in 32-bit Resident Evil 5 (DX9) through the Feeder, issue opened 24 Sep 2026. — [DLSS5-Feeder issue #131](https://github.com/jlrouzies-fr/DLSS5-Feeder/issues/131)
- **Uncle Burrito's Ada patch (reported by 30 Aug 2026) [press]:**
  - The RTX Remix modder Uncle Burrito patched the DLL for Ada (RTX 4090/4080) by replacing the Blackwell-only CUDA binaries with Ada-compatible ones.
  - Result: RTX 4090 in Control, about 135 → 82 fps (−39%).
  - Sources: [VideoCardz](https://videocardz.com/newz/leaked-dlss-5-already-working-with-rtx-40-series); [TweakTown](https://www.tweaktown.com/news/113331/dlss-5-mod-also-works-on-rtx-40-series-gpus-rtx-4090-tested-with-control-using-custom-patched-dlss-5-dll/index.html); [OC3D](https://overclock3d.net/news/gpu-displays/modder-add-dlss-5-support-to-rtx-40-series-gpus-using-leaked-dll-files/); [tech-insider](https://tech-insider.org/dlss-5-patched-rtx-4000-ada-lovelace-2026/)
- **Other Ada build [release notes]:** "DLSSNR-Ada-Experimental v1" (28 Aug 2026), tested on an RTX 4070 Ti SUPER in Control, labelled a proof of concept. — [igorsilvercosta18-wq/DLSSNR-Ada-Experimental](https://github.com/igorsilvercosta18-wq/DLSSNR-Ada-Experimental)
- **ShortFuse cross-generation runtime [release notes]:**
  - The build is "ShortFuse cross-generation 310.8", SHA-256 `E67DEE209320CDAFE0E93E45675D7AA34323A53ACC57A72B2E40A181581C989A`, from ShortFuse's pinned RenoDX Discord thread.
  - It "automatically selects an FP16-oriented path on RTX 20/30, an Ada-compatible path on RTX 40, and leaves the RTX 50 path unchanged". "RTX 20/30 use a much heavier FP16 path, so reduced model resolution may be necessary."
  - Windows reports the NVIDIA signature as invalid.
  - Source: [wilsjo2 INSTALL-DLSSNR.md](https://github.com/wilsjo2/OptiScaler-DLSSNR-PreSR-Multipass/blob/main/INSTALL-DLSSNR.md)
  - DLSS5oneclick describes the same build: `310.8.SF` "adds patched binaries for RTX 40 and an FP16 path for RTX 20/30", with tiers "RTX 50 full speed · RTX 40 moderate cost · RTX 20/30 heavy cost". — [DLSS5oneclick README](https://github.com/faisalkindi/DLSS5oneclick)
- **Mirrored variants (zipped sizes) [release notes]:** none of these mirrors carries release notes.
  - `310.8.0-RTX40`: 110.6 MB
  - `310.8.SF`: 114.6 MB
  - `310.8.SF-v2`: 116.7 MB
  - Source: [rhi-repo releases](https://github.com/RankFTW/rhi-repo/releases)
- **Open-source patcher [code, release notes]:**
  - dev-camo/dlssnr-patcher (GPL-2.0, created 2026-08-29, last push 2026-09-03, 9 stars) patches the user's own DLL for Turing, Ampere and Ada (`-t/-A/-a`, or all by default).
  - It needs Python 3.10+ and CUDA Toolkit 13.3 (`ptxas`, `fatbinary`, `cuobjdump`).
  - It rewrites the PTX, emulating FP8 E4M3 conversions and FP8 MMA through exact integer conversions and FP16 MMA on pre-Ada GPUs. It recompiles the cubins, patches the NGX architecture cases, strips the invalidated signature and fixes the PE checksum.
  - Its warning: "Patching changes the DLL and invalidates its NVIDIA digital signature."
  - Sources: [README](https://github.com/dev-camo/dlssnr-patcher); [dlssnr_patcher.py](https://github.com/dev-camo/dlssnr-patcher/blob/main/dlssnr_patcher.py)
- **Ampere and Ada results with the modified DLLs [press, forum/user]:**
  - RTX 3080 Ti in GTA V at 1440p: 20–30 fps.
  - RTX 3090 in Hogwarts Legacy: about 30 fps.
  - RTX 3090 in Cyberpunk 2077 at 720p: about 41 fps.
  - Tested Ada cards also included the RTX 4080 and 4090.
  - Source: [The PC Enthusiast, 30 Aug 2026](https://thepcenthusiast.com/dlss-5-mod-games-rtx-50-40-30-gpus/)
  - RTX 4060 in "Fatal Flash II Remake" (as transcribed; probably Fatal Frame II Remake): 1080p at 30 fps, from user comments. — [MakeUseOf, 6 Sep 2026](https://www.makeuseof.com/how-to-install-nvidia-dlss-5-on-almost-any-rtx-gpu-in-minutes/)
- **Ada measurements from tool authors [release notes]:**
  - RTX 4070 Ti at 1280×720 render resolution: the network costs 3.27 ms (colour encode/decode about 0.03 ms). — [neural-upstream README](https://github.com/matiasLombo/neural-upstream)
  - RTX 4070 Ti SUPER with a 1912×1080 model input: about 5–9 ms per frame (8.5 ms at 4K in WoW). — [ls-addon-manager README](https://github.com/Echo-Storm/ls-addon-manager)
  - Guild Wars Reforged (32-bit, DXVK) on an RTX 4070 at 3440×1440: 55 fps with NR against 350+ without (user report #32). — [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder)
- **Reimplementations that run on NVIDIA Ada without NVIDIA's runtime [community RE]:** these are covered in depth by another researcher.
  - OpenDLSS-NR runs "an NVIDIA Ada (or newer) GPU" through `VK_EXT_shader_float8` and `VK_NV_cooperative_matrix2`. Whole network on an RTX 4070 SUPER: 7.8 ms at 1080p, 12.6 ms at 1440p, 29.3 ms at 4K.
  - The user supplies the weights, extracted from their own DLL.
  - Source: [OpenDLSS-NR README](https://github.com/maanHimself/OpenDLSS-NR)
- **Per-generation status in one capture-based tool [release notes]:** NeuralScreen lists RTX 40 "reported" (4080 Super ×2, 4060 needs a retest). On its direct route it lists RTX 30 and RTX 20 as "known failure (below Ada)". — [NeuralScreen README](https://github.com/perseval-BLR/NeuralScreen)
- **Spoofing or driver flags:** I found no evidence that GPU-ID spoofing or driver profile flags alone enable NR on pre-RTX 50 cards. Every working route found modifies the CUDA kernels.

### Inferences
- For YAE's reach goal, the practical RTX 20/30/40 path is to stop requiring a valid NVIDIA signature on `nvngx_dlssnr.dll` for non-RTX-50 cards. Two options follow from that:
  - Tell users to supply the ShortFuse cross-generation build, verified by its SHA-256.
  - Let users run dev-camo's patcher on their own DLL.

  Users should then expect:
  - On Ada: roughly 1.5–3x the Blackwell cost.
  - On Turing/Ampere: much heavier cost. This makes reduced model resolution (`WorkingScale`) or a lower game resolution almost mandatory.
- YAE's chain already runs OptiScaler in the 64-bit D3D12 host. The OptiScaler `WorkingScale` (model resolution) control therefore applies there, regardless of the Feeder's OpenGL path being fixed at 100% work resolution.

### Gaps
- I found no systematic, controlled benchmarks of the cross-generation runtime on RTX 20/30 cards (ms at fixed resolutions); the numbers above are anecdotal.
- I found no public statement by ShortFuse describing the FP16 path's quality loss against native FP8. dev-camo's comment only says results "can differ".
- It is unknown whether NVIDIA's promised RTX 40 support will use the same model or a different one.

## 5. The community injection ecosystem: tools, how they get depth and MVs, HUD handling, versions and activity

### Takeaway
The ecosystem exploded after the leak: dozens of repositories were created between 28 Aug and early Sep 2026. They fall into four groups:

1. **Neural consumers** that actually call the model: RenoDX's `renodx-dlss5` (Krish) and `renodx-dlss` (ShortFuse), both Discord-distributed binaries; Deep Fried Chicken (Discord); and the OptiScaler_DLSSNR forks (Dagherbou, wilsjo2, y4my4my4m and others).
2. **Feeders and bridges** that manufacture or mirror a DLSS evaluate: DLSS5-Feeder, NIGos' dlss5-bridge, the Vulkan bridges.
3. **One-click installers** that orchestrate these: DLSS5-Swapper (about 7.9k stars), Autopilot, DLSS5oneclick and others.
4. **Capture-based, API-agnostic tools** that work on any window: NeuralScreen, the Lossless Scaling add-on, desktop wrappers.

DLSS5-Feeder remains the only route for 32-bit and OpenGL games, and the most active project (1.18.0-beta.2, 6 Oct 2026). Tools that intercept the game's own DLSS avoid the HUD by running before the UI. Feeder- and capture-based routes process the HUD unless the user masks it.

### Cited Findings

#### Neural consumers

**RenoDX DLSS 5 add-ons [release notes]**
- `renodx-dlss5.addon64` (Krish, the "#DLSS5" build) is a "neural add-on" that hooks a game's own DLSS evaluate. It is not on GitHub; it comes from the RenoDX Discord. — [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder)
- Its build generations: v4.55 (classic engine), v4.6/v4.7 ("lazy adoption", which fault on driver 616.64+), v6.1.0, v7.0.0-rc8, v8.0.1 and 8.5.0-rc10. — [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder); [rhi-repo renodx-dlss5-8.5.0-rc10, 2026-09-26](https://github.com/RankFTW/rhi-repo/releases/tag/renodx-dlss5-8.5.0-rc10)
- The 8.x settings include `NRHookPoint` (Render = before the game's DLSS upscales, "on far fewer pixels"; Upscaled = at output resolution), `NRPasses` and `NRDetailStability` (holds grass and leaves still). — [DLSS5oneclick README](https://github.com/faisalkindi/DLSS5oneclick)
- ShortFuse's separate `renodx-dlss` builds the DLSS request itself in-process for 64-bit D3D9/11/12 and replaces the Feeder. It is reported failing in many games other than DX9. "SF" builds are mirrored, latest 26.1003.2350 (2026-10-04). — [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder); [DLSS5-Autopilot README](https://github.com/Kizzuwatnaa/DLSS5-Autopilot); [rhi-repo](https://github.com/RankFTW/rhi-repo/releases/tag/renodx-dlss-SF-26.1003.2350)
- The public `clshortfuse/renodx` repo (MIT, 4,437 stars, nightly builds through 2026-10-06) has DLSS helper utilities (`src/utils/dlss/*`). The DLSS 5 add-on source is not in its main tree as of 2026-10-07 (checked via the GitHub tree API). — [clshortfuse/renodx](https://github.com/clshortfuse/renodx)

**Deep Fried Chicken [release notes]**
- By "Alexander", distributed on Discord. It is the Feeder's recommended consumer (1.4.8+) and hooks NGX with Detours. It goes idle if a second consumer is present.
- Its author defined the "ABI-1" Feeder interop.
- Source: [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder)

**Dagherbou/OptiScaler_DLSSNR [release notes, code]**
- GPL-3.0, created 2026-08-29, 794 stars, 32 open issues.
- Latest release v0.2.0 (2026-09-03) plus v0.2.0-patch1 (2026-09-04, "Onimusha should now launch"). Last push 2026-09-04, so dormant for about a month.
- Design:
  - Runs NR "immediately after the game's upscaler, on the same command list, before the interface is drawn… the model never sees your HUD".
  - Needs a game that already uses DLSS, FSR or XeSS.
  - DX12 and Vulkan natively; DX11 through the D3D11-on-12 bridge.
  - The colour composition (luminance-ratio "UpgradeToneMap", OkLab hue correction, reversible gamut compression) is from RenoDX's DLSS 5 add-on (MIT).
  - Model resolution 25–100%, plus supersampling up to 2x on DX12/Vulkan.
  - "Matched residual" and box-filter downsample contributed by hhkbble.
  - Live exposure read from the game.
  - Minimum driver 616.56; older architectures need a modded DLL.
- Sources: [v0.2.0 release notes](https://github.com/Dagherbou/OptiScaler_DLSSNR/releases/tag/v0.2.0-dlssnr); [YAE package readme](<../../payload/host64/READ ME - DLSS Neural Rendering.txt>); [RenoDX attribution](../../payload/host64/Licenses/RenoDX_ATTRIBUTION.txt)

**wilsjo2/OptiScaler-DLSSNR-PreSR-Multipass [release notes]**
- GPL-3.0, created 2026-09-05, 766 stars, 76 open issues, last push 2026-09-29.
- Releases: Latest v0.8.3 (2026-09-13); newest prerelease v0.8.91 (2026-09-23, "Compressed model input preview").
- Features:
  - NR before SR (`RunBeforeSR`)
  - multipass with per-pass settings
  - separate skin and scenery settings
  - "finished picture" NR on Present, which "helps with green noise" and works with FG and HDR in native DX12
  - model resolution
  - a "direct NR runtime — no helper DLL" since v0.8.1
  - an RTX 40 MFG package and a "Display Filter" preview
- Supports RTX 20–50 with the right runtime.
- An experimental FP8/"NVFP4 hybrid" (v0.7.1/v0.7.2, 8–9 Sep 2026) for Blackwell only:
  - "VERY minor improvements on Blackwell": about a 1–2% NR-pass reduction at 4K.
  - BG3: 55.16 fps (recommended hybrid) against 54.57 fps (FP8), "not established as repeatable".
- Model resolution below 100% flickers on builds up to v0.8.91 (colour at working size, guides at full size). The fixed build v0.8.92 is on the Feeder author's fork.
- Sources: [README](https://github.com/wilsjo2/OptiScaler-DLSSNR-PreSR-Multipass); [v0.7.1](https://github.com/wilsjo2/OptiScaler-DLSSNR-PreSR-Multipass/releases/tag/v0.7.1-hybrid); [v0.7.2](https://github.com/wilsjo2/OptiScaler-DLSSNR-PreSR-Multipass/releases/tag/v0.7.2-hybrid); [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder); [jlrouzies-fr fork v0.8.92](https://github.com/jlrouzies-fr/OptiScaler-DLSSNR-PreSR-Multipass/releases/tag/v0.8.92)

**y4my4my4m/OptiScaler_DLSSNR_Multipass_MFG [release notes]**
- GPL-3.0, created 2026-09-03, 47 stars, last push 2026-09-06 (dormant).
- v10.0.0-dev-fork-y4my4my4m-v4 (2026-09-05):
  - NR "inside the upscaler… at render resolution" (`[DlssNr] DualFeature=true`), also on native Vulkan. Measured "219.6 ms to 5.7 ms per frame at 1440p"; the GPU is not stated.
  - Per-pass model settings.
  - An MFG unlock on Ada.
  - A "_with_DLSS" archive bundling DLSS 310.9 and Streamline 2.14.
- Source: [release notes](https://github.com/y4my4my4m/OptiScaler_DLSSNR_Multipass_MFG/releases/tag/v10.0.0-dev-fork-y4my4my4m-v4)

**Other forks [release notes]**
- OpMoonRise2 (FFXI changes: DLAA motion-smear fix, multipass taper)
- Markxiao94 (NR before SR)
- peace-csaba (VRAM leak fixes)
- ShyVortex (RTX 20/30 MFG unlock)
- evairx/OptiScaler-MFG
- Janblade's fork of wilsjo2
- Sources: [GitHub search, 2026-10-07](https://github.com/search?q=OptiScaler+DLSSNR&type=repositories); [DLSS5oneclick README](https://github.com/faisalkindi/DLSS5oneclick); [DLSS5-Autopilot README](https://github.com/Kizzuwatnaa/DLSS5-Autopilot)

#### Feeders and bridges

**jlrouzies-fr/DLSS5-Feeder [release notes, code]**
- MIT; "Portions derived from dlss5-dx11-bridge… NIGos (MIT)". Created 2026-08-29, 1,048 stars, 11 open issues.
- Releases: Latest **1.18.0-beta.2 (2026-10-06)**; 1.18.0-beta.1 (2026-09-29, 64-bit helper mode); **1.17.0 stable (2026-09-27)**; 1.16.0-beta.7 (2026-09-22); 1.16.0-beta.6 (2026-09-20).
- Sources: [repo](https://github.com/jlrouzies-fr/DLSS5-Feeder); [releases](https://github.com/jlrouzies-fr/DLSS5-Feeder/releases); [YAE THIRD-PARTY-NOTICES](../../THIRD-PARTY-NOTICES/DLSS5-Feeder-LICENSE.txt)

How it works [README]:
- It builds a synthetic DLSS DLAA contract (render size = output size, no jitter) from:
  - the ReShade back buffer
  - the Generic Depth depth buffer (R32F)
  - optical-flow motion vectors from a ReShade shader (RG16F, in pixels)
  - a trust mask (R8) passed as DLSS's bias-current-colour mask; the 32-bit add-on "does not pass it yet"
- It runs a genuine `NGX_D3D12_EVALUATE_DLSS`, and the installed neural consumer hooks that evaluate.
- Supported APIs:
  - D3D10, D3D11, D3D12
  - Vulkan, 64-bit and 32-bit through DXVK
  - OpenGL, 32-bit and 64-bit
  - D3D9 through dgVoodoo2 or DXVK
  - 32-bit games through a 64-bit helper, `dlss5-feed-host64.exe`, with shared textures and fences over a named pipe
  - since 1.18.0-beta.1, a "64-bit helper mode" for 64-bit games whose process cannot run NGX (Bloodborne on shadPS4)

The OpenGL path [README]:
- It needs `GL_EXT_memory_object_win32` and `GL_EXT_semaphore_win32`. A D3D12 fence is imported as a GL semaphore.
- Per frame: `glCopyImageSubData` for MV, depth and mask; `glBlitFramebuffer` for colour; `glSignalSemaphoreEXT` + `glFlush`; then `glWaitSemaphoreEXT` and a blit back.
- `GL_FRAMEBUFFER_SRGB` is forced off.
- For 32-bit GL the host creates the shared textures, because GL memory objects are import-only.
- Verified in Worms Ultimate Mayhem (32-bit OpenGL, 4K, 0.13 ms per frame transport) and by user reports in KOTOR (32-bit OpenGL, RTX 2060, fixed in 0.9.0) and MX Bikes (64-bit OpenGL).

Motion-vector providers (`DLSS5_MV_PROVIDER`) [README]:

| Value | Provider | Notes |
|---|---|---|
| 0 | anything writing `texMotionVectors` (qUINT, dh_uber_motion) | |
| 1 | iMMERSE Launchpad | |
| 2 | VORT | |
| **3** | **LumeniteFX Kernel** | **recommended**: 1/8-resolution flow plus a confidence map |
| 4 | LumeniteFX QuantMotion | |

- DRME does not compile on ReShade 6.8.
- `DLSS5_Feed.fx` validates every vector: depth disocclusion, consistency, and a "static hypothesis" test with two-frame hysteresis. Vectors that fail are zeroed.

Limitations [README]:
- "the UI is processed with the scene (a UI mask / pre-UI colour capture is future work)".
- Estimated MVs cause ghosting and softness in fast motion.
- Lights that flicker faster than the history converges become slow pulses.
- Work resolution of 50–100% exists only on 64-bit D3D11. D3D12, Vulkan and OpenGL stay at 100%.

Changes since 1.16.0-beta.6 [release notes]:
- 1.16.0-beta.7 fixed a crash when Work resolution was set below 100 (D3D11; #123).
- 1.17.0 supports wilsjo2's fork and RenoDX v6.1+ (which pass 300/300 on driver 617.14 where v4.7 fails).
- 1.17.0 adds an experimental "Output stabiliser" (`hold_strength`/`hold_tolerance`).
- **The IPC protocol moved from v10 to v11; a 1.16.x half refuses to talk to a 1.17 half.**
- 1.18.0-beta.2 explains "NGX refused to start" signature-check failures, lets host64 find runtimes in the game folder, and warns about the wrong (for example MSAA) depth buffer.
- Sources: [1.16.0-beta.7](https://github.com/jlrouzies-fr/DLSS5-Feeder/releases/tag/v1.16.0-beta.7); [1.17.0](https://github.com/jlrouzies-fr/DLSS5-Feeder/releases/tag/v1.17.0); [1.18.0-beta.2](https://github.com/jlrouzies-fr/DLSS5-Feeder/releases/tag/v1.18.0-beta.2)

Driver compatibility [README]:

| Consumer | 616.56 | 616.64 | 617.14 |
|---|---|---|---|
| renodx-dlss5 v4.7 | works | fails (faults inside `nvngx_dlssnr.dll`) | fails |
| renodx-dlss5 v6.1+, Deep Fried Chicken, classic-engine builds | | works | works |

**NIGos/dlss5-bridge (formerly dlss5-dx11-bridge) [release notes]**
- MIT, created 2026-08-28, 304 stars, 24 open issues, last push 2026-09-13. Stable v1.4.12; test build v1.4.13-pre8 (2026-09-13).
- Three routes:
  - **D3D11 bridge:** copies the game's own Color, Depth and MotionVectors into shared textures, evaluates on a private D3D12 device and copies back.
  - **Vulkan mirror:** the same idea, with the game's resources imported into D3D12.
  - **Substitute contract (`synth=1`, off by default):** for games without DLSS, DLAA at back-buffer size from ReShade depth plus NVIDIA Optical Flow or a ReShade MV shader. "Text softens and dense foliage smears."
- On the substitute path the input "may already include the game's tone mapping and UI".
- It warns that `dlss5bridge.com` is unofficial and that Hybrid Analysis classifies its installer as Malicious.
- Source: [README](https://github.com/NIGos/dlss5-bridge)

**Vulkan-specific [release notes]**
- AlanBacker/dlss5-vk-bridge: a Vulkan port of the DX11 bridge, v0.2.0 (2026-09-02), dormant since.
- bmitch87/DLSS5VKLayer: a Linux Vulkan implicit layer that forwards presented frames to a Windows NGX helper under Wine or Proton, with `VK_NV_optical_flow` synthetic MVs and an HDR float16 proxy. AGPL-3.0, 0.3.1-2 (2026-09-26).
- Yukikaze20170315/dlss5-vulkan-fg-relay.
- Sources: [dlss5-vk-bridge](https://github.com/AlanBacker/dlss5-vk-bridge); [DLSS5VKLayer](https://github.com/bmitch87/DLSS5VKLayer)

**Cost-reduction tools [release notes]**
- matiasLombo/neural-upstream (MIT, v0.3.0, 2026-09-02) and its near-copy Xeakaes/dlss5-nr-pre-upscale (2026-09-15) run NR at render resolution before the game's DLSS. Cost relative to output resolution: 0.25x for 1080p → 4K and 0.11x for 720p → 4K.
- Cadence modes that skip frames cause FG pacing stutter.
- xenmods/DLSSNR-Cost-Scaler (MIT, v1.0.6, 2026-09-13) is a proxy DLL: model scale 25–200%, a "matched residual" composite, and an FPS governor.
- Sources: [neural-upstream](https://github.com/matiasLombo/neural-upstream); [dlss5-nr-pre-upscale](https://github.com/Xeakaes/dlss5-nr-pre-upscale); [DLSSNR-Cost-Scaler](https://github.com/xenmods/DLSSNR-Cost-Scaler)

#### Installers and "DLSS 5 for any game" orchestrators

**rakanki911/DLSS5-Swapper [release notes]**
- MIT, created 2026-08-29, **7,896 stars**, 67 open issues, v2.2.9 (2026-09-29).
- Routes: RenoDX native, the Feeder for games without DLSS, OptiScaler, multipass.
- APIs: DX8/9/11/12, Vulkan, OpenGL, DirectDraw and emulators. DX8 is 32-bit through dgVoodoo2 → DX11 → Feeder.
- RTX 20–50 "with the bundled modified runtime".
- An F8 overlay and a community compatibility page.
- Source: [README](https://github.com/rakanki911/DLSS5-Swapper)

**Kizzuwatnaa/DLSS5-Autopilot [release notes]**
- MIT, 841 stars, v2.0.8 (2026-09-30).
- Eight routes: native, neural-upstream, optiscaler, bridge, feeder, standalone-dlssnr, renodx-dlss and remix.
- OpenGL, D3D10 and 32-bit games go to the Feeder.
- It pins `renodx-dlss5` to 4.55 on driver 616.64+ because newer builds fault.
- Source: [README](https://github.com/Kizzuwatnaa/DLSS5-Autopilot)

**faisalkindi/DLSS5oneclick [release notes]**
- MIT, written in Rust, 1,005 stars, v0.14.16 (2026-10-06).
- RTX 20–50; refuses non-NVIDIA and non-tensor GPUs.
- It writes the RenoDX 8.x "cheap" settings and offers RTX 20/30 MFG unlocks.
- Source: [README](https://github.com/faisalkindi/DLSS5oneclick)

**Others**
- kibblerz/DLSS5-Reshade-AIO (Apache-2.0, v2.2.4, 2026-09-11): its own feed with NVIDIA Optical Flow; DX12/11/9/Vulkan. — [repo](https://github.com/kibblerz/DLSS5-Reshade-AIO)
- xdzleo/dlss5-launcher (MIT, v1.99.0, 2026-09-07): DX9 and 32-bit games through DXVK or dgVoodoo2 plus a 64-bit helper. — [repo](https://github.com/xdzleo/dlss5-launcher)
- RazvanManolache/DLSS5-Everything (MIT, 3 stars, v0.3.2, 2026-09-07): claims x86/x64 DirectX, Vulkan, OpenGL and Glide. — [repo](https://github.com/RazvanManolache/DLSS5-Everything)
- perseval-BLR/dlss5-classic-games: 22 classic games. — [repo](https://github.com/perseval-BLR/dlss5-classic-games)
- OPness99/fnv-dlss5-neural-rendering: Fallout: New Vegas via DXVK → Vulkan → ReShade → Feeder → 64-bit host. This is the same pattern as YAE's chain. — [repo](https://github.com/OPness99/fnv-dlss5-neural-rendering)
- perseval-BLR/dlss5-remix-r32f-patch: an RTX Remix R32_SFLOAT depth fix for dlss5-bridge (HL2 RTX, Painkiller RTX). — [repo](https://github.com/perseval-BLR/dlss5-remix-r32f-patch)

**Capture-based tools (any API including OpenGL; no injection) [release notes]**
- perseval-BLR/NeuralScreen: 1,026 stars, v2.1.10 (2026-10-06). Real-time NR on the whole desktop. Depth is flat and motion is estimated, "so UI and text can distort". — [README](https://github.com/perseval-BLR/NeuralScreen)
- Echo-Storm/ls-addon-manager: a Lossless Scaling add-on, MIT, 0.9.38 (2026-10-03).
  - Motion is measured from the frames.
  - HUD areas are drawn by hand to exclude them.
  - "Neural Rendering backs off when the card is full."
  - A "Dark guard" setting since 0.9.31.
  - Source: [README](https://github.com/Echo-Storm/ls-addon-manager); [releases](https://github.com/Echo-Storm/ls-addon-manager/releases)
- Also ThioJoe/Full-Screen-DLSS5-Wrapper and pcdofafa/dlss5-for-all. — [GitHub search](https://github.com/search?q=dlss5&type=repositories)

#### Integrations into other engines and media tools [release notes]
- bgfx (andrewmd5/bgfx-dlss5-nr), UE5 (praveenkumarappu/DLSS5ForUE5), Unity (Kuan-Mi/UnityDLSSNR).
- Many ComfyUI, video, Blender and Nuke tools.
- Source: [GitHub search "dlss5"/"dlssnr"/"dlss-nr", 2026-10-07](https://github.com/search?q=dlssnr&type=repositories)

#### Safety and provenance warnings [release notes]
- The Feeder warns of fake malicious websites and lookalike GitHub repos that serve ZIPs (#88, #115). — [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder)
- NIGos warns about `dlss5bridge.com`. — [dlss5-bridge README](https://github.com/NIGos/dlss5-bridge)
- Some repos make broad, unverified claims and deserve caution. Fastbrasecret8/DLSS5-Manager was created 2026-06-15, before the leak, declares no license, and claims support for "RTX 20/30/40/50, AMD RDNA, Intel Arc". optiscalerdlss/OptiScaler-DLSSNR-5 calls itself the "Official free download". Nothing here establishes that either is malicious; they are listed only as examples of the pattern the Feeder warns about. — [GitHub API metadata, 2026-10-07](https://github.com/Fastbrasecret8/DLSS5-Manager); [optiscalerdlss repo](https://github.com/optiscalerdlss/OptiScaler-DLSSNR-5)

### Inferences
- **Upgrade the pinned Feeder.** YAE pins Feeder 1.16.0-beta.6 (protocol v10). Moving to 1.17.0 or 1.18.x requires updating both the 32-bit add-on and the host together, because of protocol v11. It brings wilsjo2-fork support, NGX diagnostics and the output stabiliser. The 1.16.0-beta.7 crash fix (#123) is D3D11-only and does not affect YAE's OpenGL path.
- **YAE's HUD handling.** The OptiScaler pass does not see the HUD only when it intercepts a game's own pre-UI upscaler. In YAE's chain the Feeder's DLAA evaluate is fed the post-HUD back buffer. The model therefore processes YAE's HUD, unlike in native DLSS games. Options:
  - a pre-UI capture point in the OpenGL stream (Feeder roadmap item), for example at the switch to orthographic HUD drawing;
  - a hand-drawn HUD mask, as in the Lossless Scaling add-on;
  - a control mask via the official `pInControlMask` with Auto Mask off, if the consumer exposes it.
- **Quality and cost levers proven elsewhere:**
  - pre-SR placement at a lower working resolution;
  - matched-residual composition at reduced model resolution (Dagherbou, xenmods);
  - supersampled model resolution up to 2x for less noise (Dagherbou v0.2.0);
  - RenoDX's `NRDetailStability` for foliage stability.

  For YAE, OptiScaler `WorkingScale` combined with matched residual is the most direct lever. Use wilsjo2 ≥ v0.8.92 or Dagherbou, since wilsjo2 ≤ v0.8.91 flickers below 100%.
- Dagherbou's fork has been inactive since 2026-09-04. Long-term maintenance appears to have shifted to wilsjo2's fork and the jlrouzies-fr fork of it.

### Gaps
- The `renodx-dlss5`, `renodx-dlss` and Deep Fried Chicken sources and changelogs live on Discord and could not be read; versions are known only through mirrors and third-party READMEs.
- I could not confirm whether the 32-bit Feeder path will ever pass the trust mask; the README says "not yet".
- I found no tool that runs NR before the HUD in a non-DLSS OpenGL game. This appears to be an open problem.

## 6. Reception and known problems

### Takeaway
Reception has been polarised since the GTC reveal (March 2026). Critics called it an "AI slop" or "AI filter" that changes art direction and faces. Jensen Huang first said critics were "completely wrong", then on the Lex Fridman podcast said "I don't love AI slop myself".

The NBA 2K27 launch (Sept 2026) drew measured praise for contact shadows and hair, alongside criticism of:
- a roughly 50% frame-rate cost
- art-style drift in stylized games
- "excessively pink" lips
- weak handling of crowds
- distant facial shadows and temporal stability
- an uncanny mismatch with dated animation

The leaked-DLL mods produced "uncanny valley nightmares". Reported failure modes include grain and noise in dark interiors lit by candles, highlights turning into "strings of coloured cells", flicker at reduced model resolution, and HUD/text distortion in feeder or capture routes.

### Cited Findings
- **GTC reveal backlash (Mar 2026) [press]:**
  - Memes and "AI slop" criticism; Resident Evil Requiem's appearance was a flashpoint.
  - Huang to Tom's Hardware: "first of all, they're completely wrong… it's not post-processing… it's generative control at the geometry level."
  - Sources: [Tom's Guide](https://www.tomsguide.com/gaming/theyre-completely-wrong-nvidia-ceo-jensen-huang-responds-to-dlss-5-criticism); [HotHardware](https://hothardware.com/news/nvidia-ceo-fires-back-at-dlss-5-criticism)
  - Later: "I can see where they're coming from, because I don't love AI slop myself", while still holding that it does not compromise artistic vision. — [TechRadar](https://www.techradar.com/computing/gpu/i-could-see-where-theyre-coming-from-i-dont-love-ai-slop-myself-nvidia-ceo-tries-to-defend-dlss-5-again-shortly-after-telling-gamers-theyre-completely-wrong)
- **Leak reaction (28–30 Aug 2026) [press]:**
  - "modders are already creating uncanny valley nightmares". — [XDA](https://www.xda-developers.com/nvidia-dlss-5-has-leaked-modders-are-already-creating-uncanny-valley-nightmares/)
  - "This is horrifying". — [VGC](https://www.videogameschronicle.com/news/this-is-horrifying-nvidias-controversial-dlss-5-ai-filter-leaks-and-layers-are-inserting-it-into-every-game/)
  - "Unsettling". — [Creative Bloq](https://creativebloq.com/3d/unsettling-nvidias-dlss-5-controversial-ai-filter-has-leaked-and-gamers-are-horrified)
  - The leak "apparently makes games look and run worse". — [Gizmodo](https://gizmodo.com/first-leak-of-nvidias-dlss-5-apparently-makes-games-look-and-run-worse-2000804311)
  - Anime characters made photorealistic. — [Dexerto](https://www.dexerto.com/gaming/anime-fan-uses-nvidia-dlss-5-to-make-characters-photorealistic-and-its-pure-nightmare-fuel-3404533/)
- **Digital Foundry (≈6 Sep 2026) [press, via ResetEra summary]:**
  - Better contact shadows (for example between jersey and body), shadowing in hair, and more depth in environment occlusion.
  - Faces more consistent than at the reveal (Starfield).
  - Problems: stylized faces (FF7 Rebirth via mods) get excessive detail and clash with the art style; lips "excessively pink"; crowds and bystanders enhanced poorly; temporal-stability concerns with distant facial shadows.
  - It is a "lighting diffusion model" requiring "expert implementation".
  - Source: [ResetEra DF thread](https://www.resetera.com/threads/digital-foundry-dlss-5-tested-nba-2k27-image-quality-benchmarks-mods-and-more.1625434/)
  - DF also noted the uncanny pairing of photorealism with NBA 2K27's dated animation. — [search summary of DF coverage, ResetEra](https://www.resetera.com/threads/digital-foundry-dlss-5-tested-nba-2k27-image-quality-benchmarks-mods-and-more.1625434/)
- **ResetEra forum themes [forum/user]:** "a 2d filter" over 3D work; fears that developers will lower baseline assets; calls for per-game or path-traced-trained models; also "first gen" optimism. — [ResetEra](https://www.resetera.com/threads/digital-foundry-dlss-5-tested-nba-2k27-image-quality-benchmarks-mods-and-more.1625434/)
- **Other press [press]:**
  - "makes NBA 2K27 look incredibly real, which is kind of the problem". — [PCWorld](https://www.pcworld.com/article/3223955/nvidias-dlss-5-makes-nba-2k27-look-incredibly-real-which-is-kind-of-the-problem.html)
  - With the leaked build, "HDR support is also broken", and effects were inconsistent, mostly on characters. — [MakeUseOf, 6 Sep 2026](https://www.makeuseof.com/how-to-install-nvidia-dlss-5-on-almost-any-rtx-gpu-in-minutes/)
- **Dark scenes [press, weak source]:** with the leaked DLL in Crimson Desert, "in closed, dark spaces with dim light sources like candles… noticeable graininess on surfaces and visual noise", and wrong diffuse in enclosed spaces. This is a machine-translated, internally inconsistent article. — [GameGPU, 31 Aug 2026](https://en.gamegpu.com/news/igry/integratsiya-fajlov-dlss-5-v-crimson-desert-izmenila-rabotu-trassirovki-luchej)
- **Failure modes documented by tool authors [release notes]:**
  - Highlights: "Lights are where the model has least to say… Guards against the model turning a bright light into a string of coloured cells" (the MaxRatio / highlight guard). — [YAE OptiScaler readme and ini](<../../payload/host64/READ ME - DLSS Neural Rendering.txt>)
  - "Replace" proxies cause "flashing lights or even no lights", and a high colour strength can flicker. — [Dagherbou v0.2.0](https://github.com/Dagherbou/OptiScaler_DLSSNR/releases/tag/v0.2.0-dlssnr)
  - "Neural Rendering costs performance and can cause flicker or other visual problems." — [wilsjo2 README](https://github.com/wilsjo2/OptiScaler-DLSSNR-PreSR-Multipass)
  - Cyberpunk 2077 drives DLSS from several threads, so the RenoDX add-on recreates its feature constantly: FPS drops with no visible change. — [DLSS5oneclick README](https://github.com/faisalkindi/DLSS5oneclick)
  - The substitute or feeder routes include tone mapping and UI, altering colours across the whole view. — [dlss5-bridge README](https://github.com/NIGos/dlss5-bridge)
- **Remix's built-in mitigations [code, official]:**
  - "highlight recovery" for highlights compressed by LDR processing.
  - A volumetric/fog/alpha-blend modulation of the control mask, implying that fog and transparent surfaces are known weak points.
  - Source: [dxvk-remix RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md)

### Inferences
- You Are Empty is a dark, foggy 2006 horror game with HUD, text and stylized Soviet characters. That sits squarely in the documented weak areas: dark interiors with small light sources, fog and transparencies, highlights, faces and stylization drift, and HUD processing in feeder routes.
- Conservative official-style settings (tone ≈ 0.3, structure ≈ 0.7, intensity < 1), a highlight cap, and a mask that excludes the HUD and fog are the evidence-based starting point.

### Gaps
- I found no rigorous, controlled study of temporal flicker or hallucination rates. The evidence is DF commentary, tool READMEs and anecdote.
- I found no DF video transcript; the DF points above are from a ResetEra summary of the video.
- I found no published analysis of DLSS 5 in horror or dark games beyond the weak GameGPU piece.

## 7. NVIDIA's adjacent technologies and next steps relevant to a remaster

### Takeaway
NVIDIA's announced next steps for DLSS 5 are RTX 50 model updates "later this fall", then RTX 40 support. Nothing has been announced for RTX 20/30, and there is no public SDK. The most remaster-relevant signal is that NVIDIA's open RTX Remix runtime has integrated DLSS 5 NR (Sep 2026, main branch) alongside DLSS 4.5 SR/RR, 6x frame generation and the Neural Radiance Cache, which is the default indirect integrator. Around it, DLSS 4.5 (CES Jan 2026) brought a second-generation transformer SR model for all RTX GPUs and Dynamic MFG up to 6x for RTX 50. RTX Kit updates (Sep 2026) advanced Neural Texture Compression (0.10 beta), Neural Shading (1.4) and Mega Geometry (2.0).

### Cited Findings
- **DLSS 5 roadmap [official via press]:** "model updates expected later this fall" for RTX 50, then RTX 40 (4 Sep 2026). — [Wccftech](https://wccftech.com/nvidia-dlss-5-rtx-40-gpus-support-confirmed/); [DSOGaming](https://www.dsogaming.com/news/nvidia-promises-dlss-5-support-for-rtx-40-series-gpus-in-the-future/)
- **Developer access [official, forum/user]:** NVIDIA's channels are Streamline and a UE5 plugin. — [NVIDIA GeForce News](https://nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/)
  - No public release had appeared by 2026-10-01. — [NVIDIA Developer Forums](https://forums.developer.nvidia.com/t/official-dlss-5-neural-rendering-plugin-access-for-unreal-engine-5-8-2/382731)
- **RTX Remix [code, official]:**
  - NR was integrated as "DLSS 3D-Guided Neural Generation" on 2026-09-18, Windows-on-Arm enabled on 2026-09-29.
  - DLSS SR and RR were updated to 4.5 (310.7.128) on 2026-08-24.
  - 6x DLFG was implemented on 2026-05-20.
  - Source: [dxvk-remix commit history](https://github.com/NVIDIAGameWorks/dxvk-remix/commits/main/src/dxvk/rtx_render/rtx_ngx_wrapper.cpp)
  - Remix's default indirect lighting mode is "2: RTX Neural Radiance Cache (NRC)… an AI based world space radiance cache… live trained by the path tracer". — [RtxOptions.md](https://github.com/NVIDIAGameWorks/dxvk-remix/blob/main/RtxOptions.md)
- **DLSS 4.5 [press]:**
  - Announced at CES 2026.
  - A second-generation transformer SR model with less ghosting, available on all RTX GPUs from the 2060 up.
  - Dynamic MFG scales from 3x to 6x; the 5x/6x and dynamic modes are RTX 50-exclusive and arrived in spring 2026.
  - Sources: [Guru3D](https://www.guru3d.com/story/nvidia-dlss-45-expands-ai-frame-generation-to-6x-and-improves-image-sharpness/); [tbreak](https://tbreak.com/nvidia-dlss-4-5-uae-launch-details/); [MSFS Addons, 1 Apr 2026](https://msfsaddons.com/2026/04/01/dlss-4-5-dynamic-frame-generation-is-here-and-it-could-change-how-msfs-2024-runs-on-rtx-50-hardware/)
- **Recent official SDKs [official]:**
  - DLSS SDK 310.9.1 (2026-09-08): "DLSS Ray Reconstruction Transformer Mode (Preset F)". — [NVIDIA/DLSS](https://github.com/NVIDIA/DLSS/releases/tag/v310.9.1)
  - Streamline 2.14.1 (2026-09-08): V-Sync and FPS limiters for Dynamic MFG, `VK_NV_low_latency2`. — [Streamline](https://github.com/NVIDIA-RTX/Streamline/releases/tag/v2.14.1)
- **RTX Kit, 22 Sep 2026 [official]:**
  - RTX Neural Texture Compression 0.10 beta (DX12 Agility SDK and ARM64 support)
  - RTX Neural Shading 1.4 (DirectX Linear Algebra toolchain)
  - RTX Character Rendering 1.4 (hair BCSDF)
  - RTX Dynamic Illumination 3.1 (DLSS RR integration)
  - RTX Texture Filtering 1.3
  - RTX Mega Geometry 2.0 (LOD streaming)
  - Source: [NVIDIA Developer Blog](https://developer.nvidia.com/blog/whats-new-for-game-developers-dlss-5-with-3d-guided-neural-rendering-nvidia-ace-updates-and-new-rtx-kit-capabilities/)
- **Community MFG unlocks on older cards [release notes]:** these are unofficial.
  - RTX 40 MFG: wilsjo2's package, y4my4my4m's Ada unlock, dashdogy's Universal RTXMFG.
  - RTX 20/30 "3X–4X" via ShyVortex's OptiScaler build.
  - Sources: [DLSS5oneclick README](https://github.com/faisalkindi/DLSS5oneclick); [y4my4my4m v4](https://github.com/y4my4my4m/OptiScaler_DLSSNR_Multipass_MFG/releases/tag/v10.0.0-dev-fork-y4my4my4m-v4)

### Inferences
- For a remaster of You Are Empty, the strategically cleanest NVIDIA-sanctioned route to NR is RTX Remix once a release ships with the NR integration. It runs before the HUD with a material control mask, uses NRC and DLSS 4.5 RR, and puts NR after the path tracer. This depends on the game running under Remix, a D3D8/9 fixed-function interception layer. You Are Empty is OpenGL, so a GL→D3D9 bridge or another route would be needed; this is an inference to be verified by the Remix-focused research.
- Neural Texture Compression and Neural Shading are developer-integration technologies, not injectable overlays. They are relevant to the yae-engine reimplementation rather than to the injected yae-dlss5 chain.
- The likely sequence is a new NR runtime (post-310.8) for RTX 50, then official Ada support. Both would invalidate hash-pinned installs, and an official Ada runtime would remove the need for modified DLLs on RTX 40, but not on RTX 20/30.

### Gaps
- I found no 2026 status for RTX Neural Faces (shown with RTX Kit at CES 2025). The Sep 2026 RTX Kit post did not mention it.
- I found no NVIDIA statement on NR for RTX 20/30, on a public NR SDK date, or on NR in a tagged RTX Remix release.
- I could not verify whether NVIDIA's "fall model updates" have shipped as of 2026-10-07; no newer `nvngx_dlssnr.dll` than 310.8.0 was found.
