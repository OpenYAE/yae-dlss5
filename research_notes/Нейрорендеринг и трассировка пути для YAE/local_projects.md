# Local projects: state, architecture, plans and gaps for neural rendering (NR) and path tracing (PT) — yae-dlss5, yae-QindieGL, yae-engine (+ cross-project links)

These notes describe the local repositories as of **2026-10-07**. Unless a path is absolute, it is relative to
`/home/alex/PetProjects/YAE-dlls/`. Sources are `file://` links with line anchors. "Strings" means text
embedded in a shipped binary, read with `strings`, because the binaries' source code is not in the
repository. Line numbers were checked on 2026-10-07. Not read, as instructed: `yae-dlss5/research_notes/`,
`yae-dlss5/reports/`, `yae-dlss5/.kilo/`, and everything in `yae-research-private` except its README.
Two upstream web pages were fetched (RTGL1 and OpenDLSS-NR), only to say what those components are.

---

## 1. yae-dlss5: the chain, what reaches the NR model, the HUD, the knobs, the GPU requirement, the installer and the limits

### Takeaway
yae-dlss5 is a Windows-only mod in an installer package. It works today on the original 32-bit OpenGL game, tested on an RTX 5090 with driver 616.92. The chain:
1. ReShade x86 (`opengl32.dll`) runs LumeniteFX optical flow and then `DLSS5_Feed.fx`.
2. DLSS5-Feeder 1.16.0-beta.6 ships colour, raw depth, optical-flow motion vectors and a trust mask to a 64-bit D3D12 helper process over shared GPU textures.
3. In the helper, OptiScaler DLSS-NR 0.2.0 runs DLAA at native resolution with no upscaling. It then runs the DLSS 5 NR model (`nvngx_dlssnr.dll` 310.8.0, "feature 18") on the DLAA output, and the result goes back into the game's frame.

The game has no engine motion vectors and no jitter, and the frame is SDR. The frame the feeder captures is the finished back buffer, so the game's own HUD is almost certainly inside the processed frame; only ReShade's overlay is excluded. The NR path is undocumented by NVIDIA and needs an RTX 50 GPU.

### Cited Findings

**What is in the repository, and recent history**
- It is an installer package. The payload holds the binaries of ReShade, the feeder and the OptiScaler fork, with their configs. The NVIDIA runtimes and LumeniteFX are not stored: the installer downloads them. The installer and scripts are MIT. — [yae-dlss5/README.md:97-104](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md#L97-L104); [yae-dlss5/.gitignore:1-2](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/.gitignore#L1-L2)
- The git history has six commits, 2026-09-22 → 2026-10-06:
  - `63ab25f` "Publish one-command You Are Empty DLSS5 installer" (09-22)
  - comparison screenshots (09-22)
  - EN/UK READMEs (10-04)
  - OptiScaler GPL-3.0 and FreeType licences (10-04)
  - MIT LICENSE (10-06)
  
  The direction since publication is packaging and licensing; the rendering pipeline itself has not changed. — `git log` in [yae-dlss5](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5)
- The workspace README describes the repository as "DLSS 5 Neural Rendering for the *original* 32-bit OpenGL game … needs an RTX 50 GPU | Experiment, public". — [README.md:67](file:///home/alex/PetProjects/YAE-dlls/README.md#L67)

**The processing chain, step by step**
- The README gives the chain as: `You Are Empty x86/OpenGL -> ReShade x86 -> DLSS5-Feeder32 -> host64 / D3D12 -> OptiScaler -> DLSS/DLAA + DLSS Neural Rendering`. — [yae-dlss5/README.md:8-17](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md#L8-L17)
- **Step 1: ReShade in the game.** ReShade x86 is `payload\opengl32.dll` in the game folder, and ReShade x64 is `payload\host64\dxgi.dll` in the helper. The game's renderer `ds2render.dll` imports `OPENGL32.dll`, so the game-folder `opengl32.dll` decides what the game loads. — [THIRD-PARTY-NOTICES/README.txt:58-62](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/THIRD-PARTY-NOTICES/README.txt#L58-L62); [yae-QindieGL/tools/remix/README.md:8-9](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L8-L9)
- **Step 2: the two ReShade effects.**
  - The effects must be enabled in this order: `Lumenite_Kernel`, then `DLSS5_Feed`. The installer's preset sets that order and `DLSS5_MV_PROVIDER=3`.
  - The reason the README gives: "Lumenite creates optical-flow motion vectors, because the old game engine does not output its own motion vectors" (translated from the Russian README).
  
  — [payload/ReShadePreset.ini:1-8](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/ReShadePreset.ini#L1-L8); [README.txt:252-258](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.txt#L252-L258)
- **Step 3: the feeder add-on.** `dlss5-feed.addon32` describes itself as: "Feeds DLSS 5 neural rendering in 32-bit D3D10, D3D11, OpenGL and Vulkan (DXVK) games without DLSS: ships the frame, depth and motion vectors to a 64-bit helper process (host64\dlss5-feed-host64.exe) over cross-process shared GPU textures, and blits the neural result back." — [payload/dlss5-feed.addon32 (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/dlss5-feed.addon32)
- **Step 3a: the OpenGL interop it needs.**
  - On OpenGL the feeder needs `GL_EXT_memory_object_win32` and `GL_EXT_semaphore_win32` (log text: "OpenGL interop unavailable: %s", "shared set ready (OpenGL)").
  - The verifier warns that on a hybrid machine "the interop extensions do not exist on an iGPU".
  
  — [payload/dlss5-feed.addon32 (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/dlss5-feed.addon32); [payload/Verify-DLSS5Feeder.ps1:1522](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/Verify-DLSS5Feeder.ps1#L1522)
- **Step 4: the 64-bit helper.**
  - It publishes "a complete 1:1 DLAA contract" ("upscaling off").
  - It "passes AutoExposure and owns no exposure buffer".
  - Both halves must speak the same protocol: "the game add-on speaks protocol v%u, this host v%u -- … reinstall dlss5-feed.addon32 and host64\ together". The tested protocol is v10.
  
  — [payload/host64/dlss5-feed-host64.exe (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/dlss5-feed-host64.exe); [VERSIONS.txt:9](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/VERSIONS.txt#L9)
- **Step 5: OptiScaler takes the NGX calls.**
  - The OptiScaler DLSS-NR fork is shipped as `host64\winmm.dll` (OptiScaler.dll renamed so the helper loads it), with `nvngx.dll_dlssnr.dll` and `OptiScaler.ini` beside it.
  - Source: `Dagherbou/OptiScaler_DLSSNR` release v0.2.0-dlssnr, commit `973761621353b99bee3dc7d4bb27b117fef2644f`. The binaries are byte-identical to the release.
  - The healthy log lines are "OptiScaler DLSS-NR loaded as WINMM.dll", "NGX calls are routed through OptiScaler DLSS-NR", and "feature ready: ... DLAA".
  
  — [THIRD-PARTY-NOTICES/README.txt:14-30](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/THIRD-PARTY-NOTICES/README.txt#L14-L30); [README.txt:287-290](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.txt#L287-L290)
- **Step 5a: the upscaler.** `[Upscalers] Dx12Upscaler=dlss`. The installer copies `nvngx_dlss.dll` (DLSS SR) and `nvngx_dlssnr.dll` into `host64\`. — [payload/host64/OptiScaler.ini:8-11](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/OptiScaler.ini#L8-L11); [Install-YAE-DLSS5.ps1:117-118](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Install-YAE-DLSS5.ps1#L117-L118)
- **Step 6: the NR pass.** `[DlssNr] Enabled=true`. OptiScaler.ini describes the pass:
  - "Synthesises detail in the upscaler's output, before frame generation sees it."
  - It needs `nvngx_dlssnr.dll` plus the `nvngx.dll_dlssnr.dll` shim, because the model "refuses callers whose module path does not contain 'nvngx.dll'".
  - "Undocumented and driven directly, so none of it is officially supported."
  
  The helper names the model as "feature 18 (neural rendering, what nvngx_dlssnr.dll backs)". — [payload/host64/OptiScaler.ini:1552-1562](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/OptiScaler.ini#L1552-L1562); [host64 exe (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/dlss5-feed-host64.exe)
- **Step 6a: how the model's answer is composed.** The model is shown "a display-referred version of the upscaler's output". Its answer is treated as "a complete picture … rescaled so its brightness sits where your original says it should, with its hue held in place". This colour composition is taken from RenoDX's DLSS 5 add-on (MIT). — [payload/host64/READ ME - DLSS Neural Rendering.txt:74-83](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/READ%20ME%20-%20DLSS%20Neural%20Rendering.txt#L74-L83); [THIRD-PARTY-NOTICES/README.txt:37-39](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/THIRD-PARTY-NOTICES/README.txt#L37-L39)
- **Step 7: back into the game.** "The add-on runs DLSS + DLSS 5 neural rendering right after the 'DLSS5_Feed' technique has rendered, so anything placed below it in the list is applied on top of the neural output." The feeder notes that "the feed inserts before ReShade's UI pass". — [payload/reshade-shaders/Shaders/DLSS5_Feed.fx:56-57](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L56-L57); [addon32 (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/dlss5-feed.addon32)
- **Proof that the model really runs.** Regular `DLSS-NR running` / `DLSS-NR cost` lines in `host64\OptiScaler.log` are the evidence; "a simple message that the DLL loaded is not enough". The helper also prints "neural consumer outcome: neural feature active (feature 18 created and evaluated)". — [README.txt:264-298](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.txt#L264-L298); [host64 exe (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/dlss5-feed-host64.exe)

**Component versions (VERSIONS.txt)**

| Component | Tested version |
|---|---|
| ReShade x86 (game) | 6.8.0.2156 |
| ReShade x64 (helper) | 6.8.0.2155 |
| DLSS5-Feeder | 1.16.0-beta.6, protocol v10 |
| OptiScaler DLSS-NR | 0.2.0 |
| `nvngx_dlss.dll` | 310.9.1.0 |
| `nvngx_dlssnr.dll` | 310.8.0.0 |
| GPU and driver | RTX 5090, driver 616.92 |

- Pinned NR source: `https://github.com/RankFTW/rhi-repo/releases/download/dlssnr-310.8.0/nvngx_dlssnr_310.8.0.zip`.
  - ZIP SHA-256 `388C0A79…FFFB3AC`
  - DLL SHA-256 `E16BCF15…96E1FC8E`
  
  — [VERSIONS.txt:7-26](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/VERSIONS.txt#L7-L26)
- The expected `nvngx_dlssnr.dll` is 165,840,496 bytes, Product Name "NVIDIA DLSSNR". It is "not nvngx_dlssd.dll (Ray Reconstruction)". — [README.txt:168-179](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.txt#L168-L179)
- DLSS5-Feeder is by Jean-Laurent Rouzies (MIT) and includes portions of dlss5-dx11-bridge by NIGos. LumeniteFX is by umar-afzaal and is downloaded at install time. — [THIRD-PARTY-NOTICES/README.txt:70-82](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/THIRD-PARTY-NOTICES/README.txt#L70-L82)

**What reaches DLSS/DLAA and the NR model**
- **The textures `DLSS5_Feed.fx` produces:**

  | Texture | Format | Content |
  |---|---|---|
  | `DLSS5_MV` | RG16F | motion vectors **in pixels**, current → previous; vectors failing validation are zeroed |
  | `DLSS5_Depth` | R32F | "the game's raw hardware depth (not linearised)", with ReShade's orientation fixes |
  | `DLSS5_Mask` | R8 | a "bias current colour" mask: 1 where the vector cannot be trusted; "Optional" |
  
  — [DLSS5_Feed.fx:4-14](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L4-L14); [DLSS5_Feed.fx:364-370](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L364-L370); [DLSS5_Feed.fx:696-717](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L696-L717)
- **Colour.** The colour is "ReShade's completed frame", declared as `texture DLSS5_ColorInput : COLOR` and exposed to the add-on as an SRV. — [DLSS5_Feed.fx:72-76](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L72-L76)
- **Motion-vector provider.** Provider 3, LumeniteFX Kernel (`Kernel::tFlow`), is "pyramidal optical flow with per-level median + a-trous filtering and previous-frame seeding. 1/8 resolution, upsampled here. Needs no depth buffer". Its 1/8-resolution flow is upsampled bilinearly by default (`MV_LOWRES_FILTER = 0`). Providers 0, 1, 2 and 4 (DRME/qUINT, Launchpad, VORT, QuantMotion) also exist, and "DRME does not compile on ReShade 6.8". — [DLSS5_Feed.fx:16-33](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L16-L33); [DLSS5_Feed.fx:109-119](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L109-L119); [DLSS5_Feed.fx:157-165](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L157-L165)
- **Why the vectors are validated.**
  - The shader explains that optical flow answers "a lighting change (flicker, flames, particles)" with "a vector that points at whatever happened to match -- confidently wrong".
  - Each pixel is therefore reprojected and checked by luma, depth and consistency tests. A failing vector is zeroed and the pixel is flagged in `DLSS5_Mask`.
  - Defaults:
    - `MV_VALIDATE` on
    - static-hypothesis test on, with two-frame hysteresis
    - luma test off
    - depth test on, tolerance 0.10
    - consistency test on, 1.4 px
    - `MASK_STRENGTH` 1.0
  
  — [DLSS5_Feed.fx:41-54](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L41-L54); [DLSS5_Feed.fx:231-333](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L231-L333)
- **Geometry vectors, an experimental alternative.** The shader can fit a camera-motion model plus depth each frame. This is "EXPERIMENTAL", off by default, and "the per-frame fit is still noisy". — [DLSS5_Feed.fx:167-186](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L167-L186)
- **What OptiScaler's NR pass reads.** OptiScaler states that NR "needs depth and motion vectors, and … this reads the ones the game already hands to DLSS every frame". In this chain, "the game" from the NGX side is the helper's DLAA call built from the feeder's textures. — [READ ME - DLSS Neural Rendering.txt:42-48](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/READ%20ME%20-%20DLSS%20Neural%20Rendering.txt#L42-L48)
- **Colour range and exposure.**
  - The feeder publishes "the SDR sRGB bridge … for an SDR game". Its paper-white control is "1.0 for an SDR game like this one". — [addon32 (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/dlss5-feed.addon32)
  - OptiScaler's white-point logic "Applies only to a linear buffer; a frame the game reports as already tone-mapped is passed over untouched". — [OptiScaler.ini:1576-1584](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/OptiScaler.ini#L1576-L1584)
- **Resolution and jitter.**
  - The work resolution is "Fixed at 100% on the OpenGL and Vulkan transports: DLSS runs at the game's native resolution there."
  - A jittered path exists only for `work_upscale=2`: "DLSS %s … Halton(2,3) over %u phases" and "(synthetic jitter)".
  
  — [addon32 (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/dlss5-feed.addon32); [host64 exe (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/dlss5-feed-host64.exe)

**The HUD and UI**
- The OptiScaler fork's own document (written for native DX12 DLSS games) says the pass runs "Immediately after the game's upscaler, on the same command list, before the interface is drawn … the model never sees your HUD". — [READ ME - DLSS Neural Rendering.txt:63-71](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/READ%20ME%20-%20DLSS%20Neural%20Rendering.txt#L63-L71)
- In this chain, however:
  - The input colour is ReShade's completed frame. — [DLSS5_Feed.fx:72-76](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L72-L76)
  - The shader warns that "anything not part of the 3D world (the HUD) gets camera vectors it should not have -- expect jitter there". — [DLSS5_Feed.fx:183-184](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L183-L184)
  - The add-on's settings list "NR UI Correction — Keeps HUD/UI from being re-lit. The feed inserts before ReShade's UI pass, so leave on." This text sits among the RenoDX-style NR settings (NR Preset, NR Style). — [addon32 (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/dlss5-feed.addon32)
- The README comparison screenshot is 3440×1440. It shows a small crosshair in both the OFF and ON halves, and no health or ammo bars. — [docs/images/example1.png](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/docs/images/example1.png)

**Configuration knobs**
- **`dlss5-feed.cfg` (20 keys).** The installed values are:
  - `enabled=1 mode=2 hdr=-1 depth_inverted=-1 flags=-1 reset_every=0 log_frames=3`
  - `host_window=0 host_gpu_priority=0`
  - `work_resolution=100 work_upscale=0 work_sharpness=0.30 async_home=1`
  - `mv_scale_x=1.000 mv_scale_y=1.000`
  - `cast_key=45 cast_mods=0 cast_scale=100 cast_mode=0 cast_anchor=1`
  
  — [payload/dlss5-feed.cfg:1-20](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/dlss5-feed.cfg#L1-L20)
- **What the keys mean** (from the add-on's own tooltips and log text):
  - `enabled` is the master switch. `enabled=0` means "no frames are fed, no runtime is queried, no textures are created".
  - `host_window`:
    - 1 gives the helper its own separate window.
    - 2 runs the helper with no window.
    - 3 gives the helper a window anyway, for wrappers that report fullscreen.
    - Exclusive fullscreen at helper start means no window (#109).
  - `work_resolution` / `work_upscale`: below 100% the image "looks blurry". `work_upscale=1` uses FSR 1 + RCAS; `=2` uses DLSS with synthetic jitter. On OpenGL the resolution is fixed at 100%.
  - `async_home=1` means "pipelined … a present DWM defers is retired from the idle path".
  - `cast_*` controls the in-game copy of the helper's panel (the key, its modifiers, the corner).
  
  — [addon32 (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/dlss5-feed.addon32)
- **Switching it off.** `enabled=0` in `dlss5-feed.cfg` turns off only the feeder. Renaming `opengl32.dll` to `.off` turns off the whole chain. — [README.txt:301-313](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.txt#L301-L313)
- **ReShade.**
  - `ReShadePreset.ini`: `DEBUG_VIEW=0`, `MV_SCALE=1`, `MV_SIGN=1,1`, provider 3. — [ReShadePreset.ini:1-8](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/ReShadePreset.ini#L1-L8)
  - `ReShade.ini`: `AddonPath=.\`, `[DEPTH] DepthCopyBeforeClears=0`, `UseAspectRatioHeuristics=1`, `KeyEffects=222`, `KeyOverlay=36` (Home). — [payload/ReShade.ini:1-25](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/ReShade.ini#L1-L25)
  - Controls: Home opens the ReShade menu, Insert opens the helper/OptiScaler panel. — [README.md:78-84](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md#L78-L84)
- **`OptiScaler.ini` `[DlssNr]` keys and their defaults:**

  | Key | Value / default | What it does |
  |---|---|---|
  | `TransferStrength` | 1.0 | blend toward the model's picture |
  | `ColourStrength` | 1.0 | |
  | `WhitePointScale` | 1.0 | |
  | `MaxRatio` | 2.0 | "most the pass may brighten any pixel" |
  | `WorkingScale` | 1.0 | "Cost falls with the square of this"; above 1.0 supersamples (DX12/Vulkan) |
  | `ScalingDownscaler` | Lanczos3 | |
  | `DebugView` | 0–3 | |
  | `AutoCapture` | true | up to eight matched before/after frames into `dlssnr-capture` |
  | `Preset`, `Style` | | baked at model creation, so a change needs a restart |
  | `Intensity`, `LocalStructure`, `LocalTone` | 1.0 | |
  | `SkinStructure` | −1 | |
  | `AutoMask` | true | |
  | `ScanExposure` | false | |
  
  — [OptiScaler.ini:1552-1628](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/OptiScaler.ini#L1552-L1628)
- **Other OptiScaler.ini settings.**
  - Frame generation is left at `auto` (off by default). — [OptiScaler.ini:20-24](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/OptiScaler.ini#L20-L24)
  - The XeSS/FSR2/FSR3/FFX input hooks are disabled, and DLSS inputs are left at auto (true). — [OptiScaler.ini:441-485](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/OptiScaler.ini#L441-L485)
  - GPU spoofing is off (`StreamlineSpoofing=false`, `Dxgi=false`). — [OptiScaler.ini:936-940](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/OptiScaler.ini#L936-L940)
  - `LogToFile=true LogLevel=2`; `CheckForUpdate=false`. — [OptiScaler.ini:1246-1251](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/OptiScaler.ini#L1246-L1251); [OptiScaler.ini:1466](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/OptiScaler.ini#L1466)

**GPU, driver and OS requirements**
- The README lists:
  - Windows 10/11 x64
  - the x86/OpenGL game with `YOU_ARE_EMPTY.exe`
  - "An NVIDIA GeForce RTX 50 series GPU for the Neural Rendering model used"
  - a recent driver, "tested on an RTX 5090 with driver 616.92"
  - GitHub access during installation
  - write access to the game folder
  
  — [README.md:58-65](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md#L58-L65)
- OptiScaler's document: "An RTX 50 series card. The model does not run on anything older." — [READ ME - DLSS Neural Rendering.txt:35-40](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/READ%20ME%20-%20DLSS%20Neural%20Rendering.txt#L35-L40)
- The helper's own messages:
  - "DLSS 5 neural rendering is unavailable until the driver is updated to 616.56 or newer."
  - "This GPU is below the minimum architecture for DLSS 5 neural rendering … DLAA from this project still works; the neural pass will not."
  - On non-NVIDIA hardware: "NGX is NVIDIA's runtime and this is not an NVIDIA GPU".
  
  — [host64 exe (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/dlss5-feed-host64.exe)
- The installer only **warns**, and does not stop, when no "NVIDIA GeForce RTX 50" adapter is detected. — [Install-YAE-DLSS5.ps1:72-75](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Install-YAE-DLSS5.ps1#L72-L75)

**What the installer does**
- **One-command install.** The command is `irm 'https://raw.githubusercontent.com/OpenYAE/yae-dlss5/main/install.ps1' | iex`. `install.ps1` downloads the `main` branch zip from codeload into a temporary folder, runs `Setup-YAE-DLSS5.ps1`, and deletes the temporary folder. — [README.md:28-56](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md#L28-L56); [install.ps1:11-61](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/install.ps1#L11-L61)
- **Choosing the folder.** Setup opens a folder picker, or uses the script's own folder if `YOU_ARE_EMPTY.exe` is there. If the folder is not writable it asks for UAC elevation. — [Setup-YAE-DLSS5.ps1:95-130](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Setup-YAE-DLSS5.ps1#L95-L130)
- **What Setup downloads and checks:**
  - LumeniteFX from the author's `mainline` branch.
  - `nvngx_dlss.dll` from `NVIDIA/DLSS` `main/lib/Windows_x86_64/rel`.
  - The NR zip from RankFTW/rhi-repo, whose zip and DLL SHA-256 are checked.
  - Both NVIDIA DLLs must carry a valid Authenticode signature by "NVIDIA Corporation" and the right ProductName ("Deep Learning SuperSampling" / "DLSSNR").
  - An invalid existing file is preserved as `*.invalid-<stamp>`.
  
  — [Setup-YAE-DLSS5.ps1:16-20](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Setup-YAE-DLSS5.ps1#L16-L20); [Setup-YAE-DLSS5.ps1:28-45](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Setup-YAE-DLSS5.ps1#L28-L45); [Setup-YAE-DLSS5.ps1:139-188](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Setup-YAE-DLSS5.ps1#L139-L188)
- **What Install does:**
  - It requires a 64-bit OS.
  - It extracts only `lumenite_Kernel.fx`, four include headers and the blue-noise texture.
  - It copies the payload plus the NVIDIA DLLs into `host64\`.
  - It backs up every replaced file to `_DLSS5-Backups\<stamp>`, with `install-manifest.json`. The manifest records the game EXE's SHA-256 and per-file hashes, and a copy of the restore script goes beside it.
  - It prints "No registry, driver, Defender, Vulkan-layer, or system-directory changes were made".
  - It runs `Verify-DLSS5Feeder.ps1`.
  
  — [Install-YAE-DLSS5.ps1:39-41](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Install-YAE-DLSS5.ps1#L39-L41); [Install-YAE-DLSS5.ps1:83-121](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Install-YAE-DLSS5.ps1#L83-L121); [Install-YAE-DLSS5.ps1:128-185](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Install-YAE-DLSS5.ps1#L128-L185)
- **The game EXE.** Its hash is "intentionally not restricted"; modified builds are allowed if they stay 32-bit and OpenGL. — [README.md:42-43](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md#L42-L43)
- **The game folder.** The package is designed for a clean folder "without ReShade, QindieGL, dgVoodoo and other graphics wrapper/injector files" (translated from the Russian). — [README.txt:23-24](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.txt#L23-L24)
- **Restore.** By default it takes the newest backup. A file changed after installation is moved to `pre-restore-changes`, not deleted. — [README.txt:316-325](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.txt#L316-L325); [Restore-YAE-DLSS5.ps1:23-30](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/Restore-YAE-DLSS5.ps1#L23-L30)

**Known limitations and failure modes the package documents**
- It is for single-player only; do not use it in anti-cheat online games. — [README.md:91-95](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md#L91-L95)
- D3D9 is "not a target". For a D3D9 game the dgVoodoo2 wrapper must be in effect first. — [DLSS5_Feed.fx:62-70](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L62-L70)
- A local `d3dcompiler` older than Shader Model 5.1 makes the neural pass (`cs_5_1`) fail "EVERY FRAME, silently". — [Verify-DLSS5Feeder.ps1:1418-1422](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/Verify-DLSS5Feeder.ps1#L1418-L1422)
- Exclusive fullscreen:
  - Three games froze when the helper's window appeared (#109).
  - The in-game panel "Needs a windowed or borderless game".
  
  — [addon32 (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/dlss5-feed.addon32)
- Only one neural consumer is allowed in `host64\`. — [host64 exe (strings)](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/host64/dlss5-feed-host64.exe)
- On first start, shader compilation and building the model "may take a few seconds" (translated from the Russian README). — [README.txt:242-243](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.txt#L242-L243)

### Inferences
- **The HUD and the weapon are processed.** The add-on reads the completed back buffer, the shader warns about the HUD, and the add-on offers a "UI correction". It is therefore very likely that DS2's own HUD (crosshair, menus, text) and the first-person weapon go through DLAA + NR, with no mask. Only ReShade's own overlay is excluded. This is the structural opposite of the engine's NR-4 plan, which puts NR before the HUD (§3).
- **The temporal inputs are approximations.**
  - The motion vectors are 1/8-resolution optical flow cleaned by heuristics.
  - The depth is the raw buffer the HUD and the viewmodel share.
  - There is no jitter, because the OpenGL transport is fixed at native resolution.
  
  DLAA therefore works as a temporal stabiliser of a native, unjittered SDR frame. Flicker, flames, particles, disocclusions and HUD elements are where errors are expected; the shader's own validation text names exactly these cases.
- **The tested set can drift.** Only the NR DLL is hash-pinned. `nvngx_dlss.dll` (NVIDIA/DLSS `main`) and LumeniteFX (`mainline`) come from moving branches. A later install can therefore differ from the VERSIONS.txt set (`nvngx_dlss` 310.9.1.0), and the README's "pinned sources" wording ([README.md:69](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md#L69)) overstates the pinning.
- **Same network build as the engine plan.** The model build installed here (310.8.0) is the build OpenDLSS-NR re-implements (§3). yae-dlss5 frames could serve as a qualitative reference for the engine's NR-1 trial. The inputs differ, though: post-HUD SDR with optical-flow vectors here, against a pre-HUD frame with true vectors in the engine.
- **The route is Windows and NVIDIA RTX 50 only.** It does nothing for the Linux engine. It does show that the feeder pattern (GL shared textures → a separate D3D12 process → NGX) works for an OpenGL title.

### Gaps
- **Undocumented keys.** The meanings of `mode=2`, `flags=-1` and `host_gpu_priority` are not documented in the repository. The feeder's source code is not in the repository (binaries only).
- **No cost or quality numbers.** No NR frame-time numbers (ms) for YAE are committed; the cost appears only in runtime logs ("DLSS-NR cost"). There is no record of which levels were tested or of long-session stability; only two screenshots.
- **Which inputs the NR model consumes.** It is not documented whether `DLSS5_Mask` reaches the NR model or only DLAA, nor what OptiScaler's `AutoMask=true` masks (UI or something else).
- **The CPU pin.** It is not documented whether the game's CPU-0 pin (`ds2kernel.dll` calls `SetProcessAffinityMask(…,1)`, found in QindieGL, §2) is inherited by `dlss5-feed-host64.exe` and affects its performance.
- **Address space.** The package says nothing about Large Address Awareness. QindieGL needed an LAA-patched EXE for multi-location sessions (§2), and here ReShade, LumeniteFX and the feeder also live in the 32-bit process.
- **Linux.** There is no Linux/Proton guidance.

---

## 2. yae-QindieGL: what the OpenGL→D3D9 fork does, the state under RTX Remix, the blockers, the next phases, performance and NR stacking

### Takeaway
The fork translates the original game's OpenGL 1.x/ARB calls to Direct3D 9, built x86 for YAE.
- **Done:** phases A (instrumentation), B (startup), C (world rendering), D (stability and the LAA fix) and E (VBOs). The game boots, plays and survives multi-location sessions on the fixed-function path (`use_shaders=0`, HDR and normal maps off).
- **Deferred:** phase F, DS2's ARB-shader path.
- **Phase G, RTX Remix 1.5.2, merged 2026-09-27:**
  - Done: a camera split (DS2's camera sent as `D3DTS_VIEW`), a CPU-affinity fix for the bridge server, stable light positions, and a tuned `rtx.conf`. Remix ray-traces the frames.
  - Conditions: DS2's model shadows must be off, decals must be hand-tagged, DLSS frame generation must be off, and the camera split must be switched on by hand.
  - Missing: no Phase G section in `STATUS.md`, no Remix performance numbers or playthrough coverage, and no plan for a next phase.

Nothing in the repository shows NR, DLSS, ReShade or OptiScaler stacked on QindieGL.

### Cited Findings

**Purpose and inheritance**
- The fork exists to run the original game (DS2 Engine, OpenGL + Cg) "through Direct3D so that Direct3D-only tooling — RTX Remix, DLSS, frame-generation and capture tools — can be attached to it". It is separate from the engine. — [yae-QindieGL/README.md:1-12](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/README.md#L1-L12)
- Upstream (Crystice 2016, later whisperglen) emulates OpenGL "up to version 1.4". Its Remix work was camera detection and geometry-hash stabilisation for idTech titles (beta for FAKK2). Upstream notes that "RTSS interferes with proper Remix functionality". — [README.md:21-36](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/README.md#L21-L36); [README.md:46-53](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/README.md#L46-L53); [NOTICE:1-13](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/NOTICE#L1-L13)
- The workspace README lists it as an "Experiment". — [README.md:66](file:///home/alex/PetProjects/YAE-dlls/README.md#L66)

**Phases A–F (STATUS.md)**
- **Phase A — instrumentation.** Structured logs, a crash ring and per-draw dumps were added. The startup crash was traced to an unguarded call to `glGetProgramivARB` at `ds2render.dll+0x1FB7E`. — [STATUS.md:3-36](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L3-L36); [STATUS.md:98-119](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L98-L119)
- **Phase B — startup.**
  - DS2's hardware gate requires `GL_ARB_fragment_program`, `GL_ARB_vertex_program`, `GL_ARB_vertex_buffer_object` and `GL_EXT_draw_range_elements` "even with use_shaders=0". This is answered by the YAE-only `yae_fallback_compatibility=1`.
  - Test config: 1920×1080 fullscreen, `depth_bpp=24`, `stencil_bpp=0`, `hdr=0`, `use_shaders=0`, `use_normalmaps=0`, `motion_blur=false`.
  
  — [STATUS.md:197-252](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L197-L252)
- **Phase C — world rendering.** Validated: lightmap orientation, video rectangle textures, and a fixed device reset. — [STATUS.md:310-387](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L310-L387)
- **Phase D — stability.**
  - 15-minute sessions are stable.
  - The 32-bit address space ran out: the largest free block was 15 MiB against a 16 MiB atlas request. This was fixed by patching `YOU_ARE_EMPTY.EXE` with `editbin /LARGEADDRESSAWARE` (2 → 4 GiB).
  - Performance was 40–60 FPS. NVIDIA's overlay does not appear over gameplay (low priority).
  
  — [STATUS.md:389-565](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L389-L565)
- **Phase E — VBOs.** VBO data stays in CPU shadow storage and is copied into D3D9 streaming buffers at draw time. Measured 30–60 FPS. — [STATUS.md:567-619](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L567-L619)
- **Phase F — the ARB shader path.**
  - "deferred since 2026-09-26". 58 programs compile.
  - It found a DS2 bug: bone-attached weapons get fog-saturated with `use_shaders=1`. This is fixed by `yae_eye_distance_fog`, "intentionally deviates from native".
  
  — [STATUS.md:621-714](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L621-L714)
- **The fixed-function path (`use_shaders=0`).** It is the test baseline. DS2 still uses ARB fragment programs on it: the soft object shadow and the screen effects. — [STATUS.md:716-741](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L716-L741)
  - Fixed: GL spot lights emulated as D3D9 spot lights, projective texturing, texgen w, and the vertical flip of `RECT` lookups.
  - Remaining object-shadow differences are "Not investigated further, by decision". Candidate fix: GL-exact polygon-offset units. — [STATUS.md:757-778](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L757-L778)
  - Tests (`tests/QindieGL_Tests`, which renders through real D3D9) cover VBOs, lighting, projection, rectangle textures, the shadow receiver and view/HUD classification. — [STATUS.md:743-755](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L743-L755)

**Performance (without Remix)**
- The profiling setup: 1920×1080 with `VSync=0`, ending at the heaviest location (about 2150 draws and 370k vertices per frame). Two optimisations took the numbers from the baseline column to the last column:

  | | Baseline | Final |
  |---|---|---|
  | Average frame time | 7.0 ms | 4.5 ms |
  | p99 frame time | 26.9 ms | 8.0 ms |
  | Average fps | 142 | 225 |
  | Heaviest location | 37 fps | 152 fps |
  | Time inside QindieGL there | 20.4 ms | 3.6 ms |
  
  - The two changes were append-only vertex/index rings and GPU framebuffer copies.
  - All runs were CPU-bound: `Present` stayed below 0.6 ms.
  
  — [STATUS.md:780-811](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L780-L811)
- Keeping static VBOs in D3D9 buffers is deferred, because "RTX Remix accepts streamed geometry. Revisit only if Remix profiling shows the vertex copying as a bottleneck. Optimization is closed". — [STATUS.md:812-817](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L812-L817)

**Phase G — RTX Remix (tools/remix, the INI, the code, the commits)**
- **Where Phase G is documented.** `tools/remix/README.md` says "See `STATUS.md` for the current state". `STATUS.md`, however, has no Phase G section: its only Remix mentions are the Phase A/B "not ready for RTX Remix" lines and the static-VBO deferral. The remote branch `origin/feature/yae-phase-g-remix` has the same content as `main` except `NOTICE`. — [tools/remix/README.md:1-4](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L1-L4); [STATUS.md:190](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L190); [STATUS.md:307-308](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L307-L308)
- **DLL chains.**
  - `GLIntercept`: the GLIntercept 1.3.4 loader forwards to `QindieGL-traced.dll`; used for traces.
  - `Direct`: QindieGL itself is `opengl32.dll`; used for Remix runs, "fewer moving parts".
  - QindieGL loads `d3d9.dll` with `LoadLibrary`, so a Remix bridge `d3d9.dll` is picked up. It refuses a `d3d9.dll` without `D3DPERF_BeginEvent`/`EndEvent`.
  - `Set-YAEDllChain.ps1` switches the chains and parks the bridge as `d3d9.remix.dll`. It identifies DLLs by content and refuses unknown files. Its default game root is `H:\YAE\Original\You Are Empty`.
  
  — [tools/remix/README.md:6-40](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L6-L40); [Set-YAEDllChain.ps1:1-19](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/Set-YAEDllChain.ps1#L1-L19); [code/d3d_global.cpp:1011-1013](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/code/d3d_global.cpp#L1011-L1013)
- **The Remix runtime.**
  - Release `remix-1.5.2` (GitHub NVIDIAGameWorks/rtx-remix, published 2026-06-16), checked against its SHA256 list.
  - In the game folder: the x86 bridge client `d3d9.dll`, plus `.trex\` with `NvRemixBridge.exe` (the x64 bridge server) and the x64 DXVK-Remix renderer `d3d9.dll`.
  - Alt+X opens the Remix menu. Logs go to `rtx-remix\logs\` (bridge32/bridge64/remix-dxvk).
  
  — [tools/remix/README.md:42-63](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L42-L63)
- **The two builds.**
  - `ReleaseNoRemixMods` has no Remix API, ImGui or Detours.
  - `Release|Win32` links Detours. For YAE its hooks find no targets ("SurfaceSort: detouring result: 0 hint: 0").
  - The Remix API is used only with `remixapi = 1`, "which the YAE sections do not set".
  
  — [tools/remix/README.md:65-73](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L65-L73); [code/d3d_global.cpp:1037-1059](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/code/d3d_global.cpp#L1037-L1059)
- **The camera split (`yae_camera_split`).**
  - Why it is needed: "DS2 never loads a camera matrix". It multiplies the camera into the modelview at stack depth 0, so D3D9 received camera × object as WORLD with an identity VIEW, "and Remix sees no camera".
  - With the key set to 1, the first depth-0 multiply goes to `D3DTS_VIEW`, and lights and clip planes are re-expressed for the view.
  - The README says it is required for Remix. The shipped INI sets **`yae_camera_split = 0`** in both YAE sections ("Needed only for Remix; 0 keeps the previous transforms").
  - The commit `6e4444b` explains the design. Its tests require the split frame to match the unsplit one pixel for pixel without Remix.
  
  — [tools/remix/README.md:77-85](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L77-L85); [msvc/QindieGL.ini:180-187](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/msvc/QindieGL.ini#L180-L187); [msvc/QindieGL.ini:205](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/msvc/QindieGL.ini#L205); [code/d3d_state.cpp:201-224](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/code/d3d_state.cpp#L201-L224); [code/d3d_matrix.cpp:108-119](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/code/d3d_matrix.cpp#L108-L119)
- **The camera census (`d06a4d7`).** For each draw it records the reset generation, the count of depth-0 transforms, and the projection class (`P<near>-<far>`/O/I) with the view kind (none/rot/rigid/mirror/affine/proj). Each segment is compared with the frame's main camera. The projection matrices are FNV-1a hashed for diagnostics only. — [code/d3d_view_diagnostics.cpp:1-20](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/code/d3d_view_diagnostics.cpp#L1-L20); [code/d3d_view_diagnostics.cpp:83-91](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/code/d3d_view_diagnostics.cpp#L83-L91)
- **The projection fix (`3531d95`).** DS2 builds its projections as `glLoadIdentity` + `glMultMatrixf`. These were not converted to D3D depth form, so the effective near plane was ~20 instead of 10. Now they are converted. — `git log` of [yae-QindieGL](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL)
- **The CPU affinity fix (`remix_server_all_cpus = 1`).**
  - `ds2kernel.dll` pins the game to CPU 0 with `SetProcessAffinityMask(GetCurrentProcess(), 1)`.
  - `NvRemixBridge.exe`, started at `HIGH_PRIORITY_CLASS` by the bridge's `Direct3DCreate9`, inherits that pin. Its busy-waiting threads starve the game: "the game freezes at the logo … 'handshake timeout'".
  - QindieGL now widens the affinity around `Direct3DCreate9` and restores the pin afterwards.
  
  — [tools/remix/README.md:86-96](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L86-L96); [code/d3d_global.cpp:964-995](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/code/d3d_global.cpp#L964-L995); [msvc/QindieGL.ini:188-193](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/msvc/QindieGL.ini#L188-L193)
- **Light positions (`14ee4ef`).**
  - "RTX Remix tells game lights apart by their exact position". Lights reconverted through the inverse view changed in their last bits as the camera moved, so Remix treated every DS2 lamp as a moving light. It dropped each one "as soon as DS2 stopped passing it, which DS2 does when no lit model is near the lamp".
  - QindieGL now keeps the world position DS2 gives each light, computed without D3DX.
  
  — [tools/remix/README.md:80-85](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L80-L85); [code/d3d_light.cpp:32](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/code/d3d_light.cpp#L32)
- **DS2's model shadows must be off** (`r_mdl_fake_shadows 0`, `r_mdl_shadows 0`):
  - The silhouette pass (orthographic, no depth writes, into a 512×512 corner) looks like UI to Remix (`isRenderingUI`). Remix then "ray traces the frame at the first one, before the world is drawn", so the picture flickers between raster and ray traced.
  - The shadow receivers use projected textures, "which Remix does not support".
  
  — [tools/remix/README.md:98-116](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L98-L116)
- **`rtx.conf`** (the "Phase G" settings):

  | Setting | Value | Why |
  |---|---|---|
  | `rtx.dlfg.enable` | False | "the first run crashed in the NVIDIA driver (vkQueueSubmit)" |
  | `rtx.zUp` | True | |
  | `rtx.autoExposure.enabled` / `rtx.localtonemap.exposure` | False / 5.3 | a fixed exposure |
  | `rtx.skyAutoDetect` | 1 | sky drawn first with an origin-centred camera |
  | `rtx.skyBrightness` | 0.125 | overcast look |
  | `rtx.fallbackLightMode` | 0 | no fallback sun |
  | `rtx.ignoreGameDirectionalLights` | True | DS2's top-down 0.3 directional light became a zenith sun |
  | `rtx.lightConversionMaxIntensity` | 81 | DS2's GL lights have no attenuation; QindieGL passes `Range = sqrt(FLT_MAX)`, which without the cap makes ~1e38-bright lamps |
  | `rtx.antiCulling.object.enable` | True | DS2 culls walls and roofs behind the player |
  | `rtx.decalTextures` | 14 hashes | decals (multiply-blended) must be tagged by hand or "they become transparent holes" |
  
  — [tools/remix/rtx.conf:1-47](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/rtx.conf#L1-L47); [tools/remix/README.md:118-139](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L118-L139)
- **When Phase G happened.** The commits ran 2026-09-26 → 2026-09-27 (camera split, census, chain switch, affinity, settings, lighting tuning, exposure, "Drop the direct sunlight") and were merged as PR #35 (`c2f602f`). The last commit on main is `NOTICE` (2026-10-05). — `git log` of [yae-QindieGL](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL)
- **Texture hashing.** The decal tags in `rtx.conf` are Remix's own texture hashes. The fork's YAE code adds no texture- or geometry-hash stabilisation. Its FNV hashing is diagnostic only (projection classes, ARB program identity). The upstream idTech surface-sorting hooks find no targets in YAE. — [rtx.conf:47](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/rtx.conf#L47); [code/d3d_arb_program.cpp:61-63](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/code/d3d_arb_program.cpp#L61-L63); [tools/remix/README.md:70-71](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L70-L71)

**Planned next and the open blockers**
- No phase after G is recorded in `STATUS.md` or `tools/remix`. The open items are:
  - Phase F deferred.
  - The object-shadow differences, with a candidate polygon-offset fix.
  - Static VBOs, "only if Remix profiling shows" vertex copying is a bottleneck.
  
  — [STATUS.md:623-627](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L623-L627); [STATUS.md:776-778](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L776-L778); [STATUS.md:812-817](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L812-L817)
- The material catalog's Remix exporter (M4) is planned and "depends on yae-qindieGL" (§4). — [yae-materials/PLAN.md:159-167](file:///home/alex/PetProjects/YAE-dlls/yae-materials/PLAN.md#L159-L167)

**Stacking NR, DLSS or ReShade on QindieGL**
- Nothing in the files or commits mentions DLSS (other than Remix's DLFG), ReShade, OptiScaler or NR. — `grep` of [yae-QindieGL](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL)
- yae-dlss5 expects a folder without QindieGL, and its shader refuses ReShade's D3D9 backend. — [yae-dlss5/README.txt:23-24](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.txt#L23-L24); [DLSS5_Feed.fx:62-70](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/payload/reshade-shaders/Shaders/DLSS5_Feed.fx#L62-L70)

**Platform and build**
- Windows only (D3D9, Detours, MSVC; built with Visual Studio 18, toolset v145). The YAE build is x86; CI builds Win32 and x64 on `windows-latest`. — [STATUS.md:142-151](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L142-L151); [README.md:56-60](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/README.md#L56-L60)
- The Remix renderer is a Vulkan DXVK-Remix process (the DLFG crash was in `vkQueueSubmit`). — [tools/remix/README.md:51-52](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L51-L52); [tools/remix/rtx.conf:5-7](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/rtx.conf#L5-L7)

### Inferences
- **What Remix lights the world with.** Remix shows the game ray-traced, but with DS2's baked lighting replaced:
  - lighting comes from the sky plus the converted GL lamps, which DS2 passes only for lit models;
  - the exposure and the light caps are hand-tuned;
  - there are no authored PBR materials (the yae-materials Remix exporter is not started).
  
  The engine's RE notes that DS2's level lamps do not light static geometry: "`glDisable(GL_LIGHTING)`" ([yae-engine/docs/Roadmap.md:262-263](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L262-L263)). The light set Remix receives is therefore partial by construction.
- **NR cannot easily be stacked on Remix.** The DLSS5-Feeder can't attach to the D3D9 client, Remix renders in a separate x64 Vulkan process, and Remix's own DLSS features (FG already crashed) are internal. Nothing in either repository addresses this.
- **Scrolling materials may break Remix hashes.** QindieGL folds DS2's animated affine texture matrices into the copied vertex texcoords for YAE ([STATUS.md:442-451](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L442-L451)). Those draws' vertex data change every frame, which could destabilise Remix's per-draw hashes for scrolling materials. This is unverified.
- **Easy to get wrong.** The Remix route needs a manual setup: the LAA patch, `.exe.local`, the chain script, `yae_camera_split=1`, DS2 shadows off, and decal tagging.

### Gaps
- There are no performance figures under Remix: no frame time, GPU, resolution, or bridge overhead. It is not stated which levels were run under Remix, for how long, or whether the result is playable or stable.
- It is not documented whether Remix uses or ignores DS2's lightmaps, nor how the ARB screen effects (pickup blur), the HUD and the films look under Remix.
- Nothing records whether Remix's DLSS-SR or Ray Reconstruction were enabled, and nothing records a Phase G status in `STATUS.md`.
- There is no recorded plan for Phase H, or for running the shader path (`use_shaders=1`) under Remix.

---

## 3. yae-engine: renderer architecture, NR/PT plans (RTGL1, NR-0…NR-5), Release 1 scope and when NR and RT may start

### Takeaway
The engine is a C++20/SDL3 **OpenGL 4.5 core** forward renderer (Linux first; Windows cross-built with llvm-mingw and run only under wine so far).

The frame is:
1. An HDR scene in `RGBA16F`, with MRT 1 = view normal + linear depth (`RGBA16F`), MRT 2 = indirect-light share (`R8`), and `DEPTH24_STENCIL8` depth.
2. The post chain: horizon-based SSAO → bloom → god rays → (DoF, off) → composite (exposure, GT tone curve by default, a single encode, LUT, vignette, grain) → FXAA → screen effects.
3. HUD → video/comics → UI → display gamma → swap.

There is **no TAA, no jitter and no velocity buffer**. `prevViewProj` and per-instance `prevWorld` are already filled but read by nobody. There is no Vulkan code.

Ray tracing (RTGL1) is an optional branch that may start only after a finished, playable GL build. Its Phase 1 seam (`RenderScene`) and the GPU-resident material table already exist in mainline.

Neural rendering (OpenDLSS-NR) is an experimental branch, added 2026-09-25 and not approved into the phase order:
- NR-0/NR-1 (clearance, benchmark, offline trial) may run at any time.
- NR-2 is the motion vectors, shared with TAA 40.6.3, in the main branch.
- NR-3…NR-5 come after Release 1.
- It needs Ada or newer, so the D10 mid-range target (RTX 3060 Ti) cannot run it.

Release 1 is the pilot on original assets. It is in preparation: K4 (the mid-range budget) is unmeasured, and Phase 53 (playtest bugs) is the current work.

### Cited Findings

**Stack, platforms and build**
- The stack is C++20, SDL3, OpenGL 4.5, Jolt and Lua 5.4, with libavcodec for films. — [yae-engine/CLAUDE.md:17-18](file:///home/alex/PetProjects/YAE-dlls/yae-engine/CLAUDE.md#L17-L18)
- The context is created as 4.5 core, and the shaders use `#version 450 core`. — [app/main.cpp:235-237](file:///home/alex/PetProjects/YAE-dlls/yae-engine/app/main.cpp#L235-L237); [shaders/depth.vert:1](file:///home/alex/PetProjects/YAE-dlls/yae-engine/shaders/depth.vert#L1)
- Presets: `dev`, `release`, `asan`, `mingw` and `mingw-release` (Windows cross-builds with llvm-mingw 20, run under wine). CI runs `build.sh --check` on Ubuntu and builds the Linux and Windows packages, checking `--version` under wine. — [CLAUDE.md:87-94](file:///home/alex/PetProjects/YAE-dlls/yae-engine/CLAUDE.md#L87-L94)
- The engine "has not run on a real Windows yet". Requirements: OpenGL 4.5 core on "NVIDIA and AMD with current drivers"; bindless textures desirable, not required; "Intel integrated graphics has not been tested". — [docs/WindowsBuild.md:129-133](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/WindowsBuild.md#L129-L133); [docs/WindowsBuild.md:230-236](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/WindowsBuild.md#L230-L236)
- Mesa (radeonsi/iris) is unchecked: "Mesa на этой машине нет (NVIDIA 590, RTX 5090)" ("there is no Mesa on this machine"). — [docs/Phase39_EngineHardening.md:871-873](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase39_EngineHardening.md#L871-L873)
- The project version is 0.1.0. The CMake options are `YAE_FETCH_DEPS`, `YAE_DEV`, `YAE_BUILD_TESTS`, `YAE_SANITIZE` and `YAE_PORTABLE_PATHS`. There is no `YAE_NR` or RT option. Searching `src/`, `app/` and `cmake/` for Vulkan, RTGL or NR finds only comments. — [CMakeLists.txt:2](file:///home/alex/PetProjects/YAE-dlls/yae-engine/CMakeLists.txt#L2); [CMakeLists.txt:17-21](file:///home/alex/PetProjects/YAE-dlls/yae-engine/CMakeLists.txt#L17-L21)

**The frame: passes and their order**
- `FramePipeline::renderFrame` runs, in order:
  1. `setupCamera`
  2. `beginSceneCapture` (into the HDR FBO)
  3. `beginFrame`, `cullVisible`, `buildScene`
  4. `sky`, `lightsAndShadows`, `submitScene`, `flushWorld`
  5. `water`, `decals`, `particles`, `ropes`, `flares`, `firstPerson`
  6. `endFrame`, `debugOverlays`
  7. `postProcess`, `screenEffects`
  8. **`hud`**, `videoAndComics`, `ui`
  
  The main loop then applies `displayGamma` (gamma over the whole frame, menus included) and swaps. — [app/FramePipeline.cpp:32-65](file:///home/alex/PetProjects/YAE-dlls/yae-engine/app/FramePipeline.cpp#L32-L65); [app/main.cpp:681-682](file:///home/alex/PetProjects/YAE-dlls/yae-engine/app/main.cpp#L681-L682)
- **The HDR target and the G-buffer:**

  | Target | Format | Content |
  |---|---|---|
  | HDR FBO, attachment 0 | `GL_RGBA16F` | the HDR scene; its depth is sampleable |
  | Attachment 1 | `RGBA16F` | view-space normal (rgb) and linear view depth (a) |
  | Attachment 2 | `R8` | "the share of the lit pixel that is indirect light" |
  | Depth | `GL_DEPTH24_STENCIL8` | |
  
  — [src/render/PostProcess.cpp:20](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/PostProcess.cpp#L20); [src/render/PostProcess.cpp:534-569](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/PostProcess.cpp#L534-L569); [shaders/normal_depth.glsl:1-25](file:///home/alex/PetProjects/YAE-dlls/yae-engine/shaders/normal_depth.glsl#L1-L25); [src/render/Framebuffer.h:59](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/Framebuffer.h#L59)
- **The post chain** (`endSceneCapture`):
  1. SSAO: half resolution, horizon-based (40.2.3), with a bilateral blur.
  2. Bloom: bright extract after exposure, then a Gaussian ping-pong.
  3. God rays: half resolution.
  4. DoF: Poisson, off by default.
  5. Composite: exposure, tone map mode, bloom, AO on the indirect share, LUT, vignette. It writes to the FXAA FBO or to the screen.
  
  — [src/render/PostProcess.cpp:184-400](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/PostProcess.cpp#L184-L400); [render.cfg:13-19](file:///home/alex/PetProjects/YAE-dlls/yae-engine/render.cfg#L13-L19); [render.cfg:45-56](file:///home/alex/PetProjects/YAE-dlls/yae-engine/render.cfg#L45-L56); [render.cfg:86-91](file:///home/alex/PetProjects/YAE-dlls/yae-engine/render.cfg#L86-L91)
- **The colour contract.**
  - Every authored 8-bit colour is a display value under a pure power γ = 2.2, decoded in the shader. There is no hardware sRGB.
  - "The frame is encoded once": OETF after the tone map, then LUT/vignette/grain in display space.
  - "UI, HUD, video and comics never see a linear value."
  
  — [docs/Invariants.md:5163-5198](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Invariants.md#L5163-L5198)
- **Picture defaults:**
  - `linear` colour pipeline
  - `r_exposure 3`
  - tone curve GT (`r_tonemap 4`)
  - `r_env_spec` on
  - 15 live shadows
  - `r_retail_frame 0`: "the goal is a better picture, not retail's"
  
  — [CLAUDE.md:119-128](file:///home/alex/PetProjects/YAE-dlls/yae-engine/CLAUDE.md#L119-L128); [docs/Decisions.md:29](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Decisions.md#L29); [docs/Decisions.md:47](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Decisions.md#L47)
- **The first-person weapon.** It is drawn with `glDepthRange(0, kViewmodelDepthRange)` over the world's depth, with its own projection, and depth is not cleared. "Every pass that reads depth reads it as is." — [docs/Invariants.md:5507-5520](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Invariants.md#L5507-L5520)

**Anti-aliasing, motion vectors and jitter today**
- "**AA — только FXAA**; motion-векторов нет, истории нет" ("AA is FXAA only; no motion vectors, no history"). — [docs/Phase40_GraphicsRealism.md:64](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase40_GraphicsRealism.md#L64)
- **The TAA plan (40.6.3, not started ⬜).** It depends on 39.2.2 (`prevWorld`) and 39.3.1 (jitter):
  - projection jitter through the per-frame UBO;
  - motion vectors from `prevWorld` and the previous bone palette;
  - history reset on load, teleport and cutscene camera change;
  - flares, particles and the first-person weapon handled by a stencil mask;
  - FXAA stays as the fallback;
  - SSAO and SSR get temporal accumulation from it.
  
  — [Phase40_GraphicsRealism.md:134](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase40_GraphicsRealism.md#L134); [Phase40_GraphicsRealism.md:1082-1088](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase40_GraphicsRealism.md#L1082-L1088)
- **What is already filled but unread.**
  - `FrameConstants` has `viewProj`, `prevViewProj` and `timeJitter` ("s, ms, jitter x, jitter y").
  - The renderer fills `prevViewProj` at `GLRenderer.cpp:498` and writes the jitter as zero at `:504`. The Roadmap cites `GLRenderer.cpp:464`; the line has moved.
  - The GLSL side declares `uPrevViewProj` "for motion vectors (40.6.3)".
  - `InstanceHistory` fills `prevWorld` per stable `instanceId` ("nobody reads it").
  
  — [src/render/FrameConstants.h:20-34](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/FrameConstants.h#L20-L34); [src/render/GLRenderer.cpp:498-504](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/GLRenderer.cpp#L498-L504); [docs/Roadmap.md:378-379](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L378-L379); [shaders/frame_constants.glsl:13](file:///home/alex/PetProjects/YAE-dlls/yae-engine/shaders/frame_constants.glsl#L13); [src/render/RenderScene.h:17-19](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/RenderScene.h#L17-L19); [src/render/RenderScene.h:127-149](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/RenderScene.h#L127-L149)
- **What is missing for NR:** "a velocity attachment, the previous bone palette, a 'no history' flag, a history reset on events". — [Roadmap.md:381-383](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L381-L383)

**The backend-neutral seam and GPU-resident data (RT readiness)**
- **`RenderScene`** describes one frame without a backend: camera, instances, lights, fog, time. Each instance carries mesh and material ids, a bone-palette handle, flags, `world` and `prevWorld`. "Nothing in it names a GL object … A second backend would read the same container (docs/RTGL1_Integration_Plan.md, Phase 1)." — [src/render/RenderScene.h:1-19](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/RenderScene.h#L1-L19); [src/render/RenderScene.h:35-111](file:///home/alex/PetProjects/YAE-dlls/yae-engine/src/render/RenderScene.h#L35-L111)
- **GPU-resident data (Phase 39.3).** The frame block (binding 2), the material table (binding 3, std430, 128 bytes per material) and bindless texture handles in the records. — [docs/Invariants.md:4998-5020](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Invariants.md#L4998-L5020)
- **The material system.** It names "uniform calls in `flush()`" as "the real blocker for RT and compute": a hit shader must fetch materials "from a GPU-resident table by index". It lists the fields RT needs: explicit `alpha_mode`, `emissive_is_light`, two-sidedness as a shading property, separate cast/receive shadow, IOR/transmission/thickness. — [docs/MaterialSystem.md:103-120](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/MaterialSystem.md#L103-L120); [docs/MaterialSystem.md:220-235](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/MaterialSystem.md#L220-L235)

**Phase 40 (graphics realism) and how it treats RT, DLSS and FSR**
- The goal is a physically consistent picture "на текущем GL 4.5, без нового бэкенда" ("on the current GL 4.5, without a new backend"). "**трассировка лучей в фазу не входит** — по решению" ("ray tracing is not part of the phase, by decision"). — [Phase40_GraphicsRealism.md:6-21](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase40_GraphicsRealism.md#L6-L21)
- Its "deliberately deferred" table:
  - "Ray tracing, RTGL1, any RT backend — not included, by decision".
  - "DLSS/FSR — После TAA; вендорские SDK; на этой стоимости кадра не нужны" ("after TAA; vendor SDKs; not needed at this frame cost").
  - "DDGI requires RT".
  
  — [Phase40_GraphicsRealism.md:1142-1152](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase40_GraphicsRealism.md#L1142-L1152)
- **Status.** 40.0–40.2 are done, and 40.1b and 40.4.1 were done in Phase 48. 40.3–40.7 come "after 49/50". — [docs/Phases.md:32](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phases.md#L32)
- **The order of part 2:**
  1. 40.3: the material bundle.
  2. 40.4: probes, reflections.
  3. 40.6: clustered forward, shadow atlas, **TAA**, volumetric fog, bloom.
  4. 40.5: GI v2 (needs the SDK baker).
  5. 40.7: hero assets.
  
  — [Roadmap.md:277-291](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L277-L291)
- An older ideas note: "Ray-traced GI — Very high — Requires an RTX pipeline (VK_KHR_ray_tracing or DXR)". — [docs/Lighting_Ideas.md:42](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Lighting_Ideas.md#L42)

**Performance budget numbers**
- **40.0.3, RTX 5090 + Ryzen 9 9950X3D, 2560×1440, 240 frames, medians.**

  | | Range |
  |---|---|
  | CPU frame | 3.28–6.29 ms |
  | GPU frame | 0.77–2.92 ms |
  | Budget | 16.7 ms |
  
  - Shadows are the costliest GPU part (2.0 ms of 2.9 in `shop`).
  - The mid-range card: "не измерено" ("not measured").
  
  — [Phase40_GraphicsRealism.md:252-270](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase40_GraphicsRealism.md#L252-L270)
- **47.8, RTX 5090, 3440×1440.**

  | | Range |
  |---|---|
  | CPU, `release` | 3.66–5.58 ms |
  | GPU | 0.67–2.72 ms |
  | Worst frame | 5.9 ms CPU |
  
  The RTX 3060 Ti GPU frame "~8–11 мс" at 3440×1440 is "an estimate, not a measurement". — [docs/Phase47_Release1Readiness.md:1249-1270](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase47_Release1Readiness.md#L1249-L1270)
- The NR section quotes: "Our whole `med1` frame at 3440×1440 is 3.7 ms". — [Roadmap.md:369-371](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L369-L371)

**RTGL1 integration plan and status**
- **The decision.** "`OpenGL` remains the shipping renderer and the only path that may block release. `RTGL1` is an optional late-stage branch … after the project reaches a stable, finishable, playable build". — [docs/RTGL1_Integration_Plan.md:3-9](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/RTGL1_Integration_Plan.md#L3-L9)
- **The rules.** A `--renderer gl|rt` switch. "Any refactor required by RTGL1 is acceptable only if it also improves the OpenGL mainline". — [RTGL1_Integration_Plan.md:48-61](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/RTGL1_Integration_Plan.md#L48-L61)
- **The rollout:**
  - Phase 0: finish the playable GL build.
  - Phase 1: a backend-neutral render scene.
  - Phase 2: RTGL1 for the static world only, one level, one platform.
  - Phase 3: go/no-go.
  - Phase 4: limited gameplay parity. Skinned actors and viewmodels are "the main complexity wall".
  
  — [RTGL1_Integration_Plan.md:63-153](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/RTGL1_Integration_Plan.md#L63-L153)
- **The first milestone's support matrix and the kill criteria.** — [RTGL1_Integration_Plan.md:155-179](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/RTGL1_Integration_Plan.md#L155-L179); [RTGL1_Integration_Plan.md:213-221](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/RTGL1_Integration_Plan.md#L213-L221)
- **The final recommendation:** "Do not treat RTGL1 as the future foundation of YAE". The plan carries no date. — [RTGL1_Integration_Plan.md:238-242](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/RTGL1_Integration_Plan.md#L238-L242)
- **Status.** Only Phase 1 exists: `RenderScene`, Phase 39.2.2, "is what MaterialSystem.md builds". The phase index lists the plan as an "experimental branch". No RTGL1 or Vulkan code exists. — [docs/Phases.md:48](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phases.md#L48); [docs/Phases.md:99-100](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phases.md#L99-L100)
- **What RTGL1 is, upstream.** "a library that aims to simplify the process of porting 3D applications to real-time path tracing, via hardware accelerated ray tracing". It is Vulkan, uses A-SVGF denoising and ReSTIR / ReSTIR GI, runs on Windows and Linux, and is MIT. It is used by Serious-Engine-RT, prboom-plus-rt, vkquake-rt and xash-rt. — [github.com/sultim-t/RayTracedGL1](https://github.com/sultim-t/RayTracedGL1)

**The NR branch (Roadmap § "Exp. — neural rendering (OpenDLSS-NR)")**
- **Status.** "Added on 2026-09-25 at the user's suggestion; not approved into the phase order". GL stays the only renderer of the release, and the branch "may stay unfinished and blocks nothing". The analysis was made from OpenDLSS-NR HEAD `9d08f41` (2026-09-21, 4 commits, MIT). — [Roadmap.md:315-321](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L315-L321)
- **What the network is.**
  - A Vulkan re-implementation of the DLSS 5 NR network, build 310.8.0: a U-net of 71 blocks, FP8, 141 MiB of weights.
  - "It is not an upscaler and not TAA": input and output have the same resolution.
  - It repaints the finished frame, "generating details from noise", with a style setting (off/natural/cinematic/custom).
  - Its input is 16 channels: an LDR proxy of the frame (`scene / paperWhite`), three Gaussian-noise channels, the previous **output** reprojected, and five scalars.
  - Its output is an RGB residual plus a history-blend logit.
  
  — [Roadmap.md:323-335](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L323-L335)
- **What the OpenDLSS-NR repository has.**
  - The temporal loop exists only in the demo.
  - The per-object motion vectors come from a 2164-line Filament patch. The engine would take "the contract and the method of checking", not the code.
  - The demo is "Windows only".
  - The bit-exactness fixtures are not public.
  
  — [Roadmap.md:336-352](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L336-L352)
- **The hard constraints.**
  - "There are no weights", and the licence is "a question for the user **before NR-1**". The weights never go into git, CI or a release.
  - "DLSS" is a trademark and must not appear in the UI or cvars.
  - Hardware: "NVIDIA Ada and newer only (FP8)", with `VK_KHR_cooperative_matrix`, `VK_NV_cooperative_matrix2`, `VK_EXT_shader_float8` and `VK_NV_cuda_kernel_launch`.
  - "The release's mid-range GPU (D10, RTX 3060 Ti, Ampere) will not run it." The WebGPU port takes 72 ms at 512² and "is not a fallback".
  - The dev 5090 (driver 590.48.01, Linux) reports all four extensions plus `GL_EXT_memory_object_fd`/`GL_EXT_semaphore_fd`, checked 2026-09-25.
  
  — [Roadmap.md:354-368](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L354-L368)
- **Cost and the faithfulness rule.**
  - On an RTX 4070 SUPER the network costs 7.8 ms at 1080p, 12.6 at 1440p, 29.3 at 4K.
  - "Against 'faithful by default'": it may only be an opt-in "neural remaster", never in the gate baselines, with the noise seeded from the `--fixed-dt` frame index.
  
  — [Roadmap.md:369-376](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L369-L376)
- **The NR steps:**

  | Step | Content | Gate |
  |---|---|---|
  | NR-0 | Clearance and measurement: build under Linux, bench at 1080p/1440p/3440×1440 on the 5090, pick the PTX `sm_89`-JIT or unfused GLSL route, validation | |
  | NR-1 | An offline image→image trial on the reference scenes, retail slots and gate levels | "go/no-go #1 — the user's verdict" |
  | NR-2 | Motion vectors in the main branch, "half of 40.6.3": velocity from `prevWorld`, the previous bone palette and `uPrevViewProj`; sky by rotation; a no-history flag; resets; masks for the first-person weapon, particles, flares, decals and water | reprojection-error test; gate 25/25 at 0.000 |
  | NR-3 | A GL↔Vulkan bridge behind CMake option `YAE_NR` (OFF), via `GL_EXT_memory_object_fd`/`GL_EXT_semaphore_fd` | |
  | NR-4 | The temporal loop in the frame. "The insertion point is after the scene, before HUD/UI/console/menu/video"; the input (linear HDR or finished LDR) is decided by NR-1; cvars `r_nr*` | `render:nr` in `perf gpu` |
  | NR-5 | The decision: keep it as an opt-in mode (Ada+) or freeze it | |
  
  — [Roadmap.md:385-392](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L385-L392)
- **When.** "NR-0 and NR-1 — at any moment, in parallel with 47". "NR-2 — together with 40.6.3 or before it, and only in the main branch". "NR-3…NR-5 — after Release 1, like RTGL1". On "no-go" the branch closes, and NR-2 stays part of 40.6.3. — [Roadmap.md:394-398](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L394-L398); [Roadmap.md:39-42](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L39-L42)
- **Dependencies:** OpenDLSS-NR, the NVIDIA weights ("the clearance is the user's call in NR-0"), and an Ada-or-newer GPU. — [Roadmap.md:410-412](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L410-L412)
- **Progress so far.** None recorded: no `NeuralRendering_Experimental.md` exists in `docs/`, and no `r_nr` or `YAE_NR` exists in the code. — [yae-engine/docs/](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs)
- **The upstream page (fetched 2026-10-07)** still shows 4 commits. It says "Windows, an NVIDIA Ada (or newer) GPU". About the weights: "You supply the weights, as a model directory … contains no NVIDIA software, weights, headers, or instructions for obtaining them". It also gives 768×768 at 2.8 ms on a 4070 SUPER. — [github.com/maanHimself/OpenDLSS-NR](https://github.com/maanHimself/OpenDLSS-NR)

**Release 1: scope, status, and when NR and RT may start**
- **The principle.** One declared goal, "**a pilot release on the original assets**". Everything the plans mark "after the playable version" comes after the milestone. — [Roadmap.md:9-18](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L9-L18)
- **The goal of Phase 47:** the campaign `med1` → credits in one build, save/load anywhere, Windows with assets. — [Roadmap.md:46-60](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L46-L60)
- **The readiness criteria:**
  - K1: the campaign by name
  - K2: saves
  - K3: release-build smoke
  - K4: the frame budget on the mid-range GPU (D10)
  - K5: Windows with assets
  - K6: `pl_sprint` in place
  - K7: the gates green
  
  — [docs/Decisions.md:94-106](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Decisions.md#L94-L106)
- **The status of the criteria.** K4 is "**не мерено**" ("not measured"). K5 has run under wine only. Phase 47 is open "with the user: mid-range card (K4), `windows.yml` (K5), the ZIL recording". — [docs/Phase47_Release1Readiness.md:197-205](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase47_Release1Readiness.md#L197-L205); [docs/Phases.md:40](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phases.md#L40)
- **Where the engine is (2026-10-06).**
  - Phase 50 (cleaning for publication): 50.0–50.4 and 50.6 done, 50.5 prepared locally.
  - Phase 47b and Phase 49: closed.
  - Phase 53 (the first playthrough's bugs after the public build): a plan, in progress at 53.0.
  
  The latest engine commits (10-06/10-07) are about physics, projectiles and navigation. — [CLAUDE.md:170-183](file:///home/alex/PetProjects/YAE-dlls/yae-engine/CLAUDE.md#L170-L183); [docs/Phases.md:47](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phases.md#L47); [docs/Phase53_PlaytestBugs.md:1-10](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase53_PlaytestBugs.md#L1-L10)
- **Decisions that shape Release 1.**
  - D7: "Publication is tied to Release 1".
  - D29: Release 1 ships without the yae-materials maps; the player bakes them from their own copy.
  - D31: which repositories Release 1 publishes.
  
  The workspace README says "Release 1 in preparation". — [docs/Decisions.md:33](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Decisions.md#L33); [docs/Decisions.md:55-57](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Decisions.md#L55-L57); [README.md:58](file:///home/alex/PetProjects/YAE-dlls/README.md#L58)
- **The roadmap's order of phases:** retail session → 47 → 48 → 49 → 47b → 52 → 50 → 53 → 40.3–40.7 → 51, with "exp." NR alongside. No dates are given for 40.3+. — [Roadmap.md:21-33](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L21-L33)

### Inferences
- **NR-2 is the most leveraged next step.** It is allowed before Release 1 in the main branch, "together with 40.6.3 or before it". The velocity attachment, the previous bone palette, the resets and the masks for the weapon, particles and flares are the shared prerequisite for TAA, for the NR temporal loop, and for any temporal PT denoiser in a future RT backend.
- **The engine can give NR what yae-dlss5 cannot.** HUD, video and UI are drawn after `postProcess`, so an NR pass at NR-4's insertion point naturally excludes the HUD. The engine can also provide true per-object motion vectors and an HDR or LDR proxy chosen by measurement.
- **The weapon needs special handling.** It shares the depth buffer in its own depth band, with its own projection. Its motion vectors and depth cannot be derived like the world's, which is why NR-2/40.6.3 list it for its own motion or a mask.
- **Cost.** The NR network (≥ 7.8 ms at 1080p on a 4070 SUPER) would be several times the current GPU frame (0.7–2.9 ms on the 5090). It is an opt-in for Ada+ cards and cannot fit D10.
- **The RT seams already exist in mainline:** the backend-neutral `RenderScene`, the GPU-resident material table with bindless handles, `prevWorld`, and the CPU-side level and model data. What is missing:
  - any Vulkan device or RT backend;
  - the RT material fields;
  - skinned and viewmodel parity, which the plan names "the main complexity wall".

### Gaps
- Nothing records an NR-0 measurement, a licence decision on the weights, or a build of OpenDLSS-NR under Linux.
- It is not documented whether OpenDLSS-NR's "model directory" can be filled from the `nvngx_dlssnr.dll` 310.8.0 that yae-dlss5 installs.
- No date or owner is given for 40.6.3 (TAA) or 40.3+. The RTGL1 plan is undated and has no recorded go/no-go, and no RT experiments are recorded in the engine docs.
- The mid-range (D10) budget is unmeasured, and nothing is measured on AMD or Intel.

---

## 4. Cross-project links: the shared asset/material pipeline, shared tooling, and getting geometry and materials into a path tracer

### Takeaway
`yae-materials` is meant as the single material source for three consumers: the engine, RTX Remix through QindieGL, and the SDK's glTF export. Only the engine exporter works today (`catalog.yaemat` and `.yaepak` packs).
- The glTF exporter (M3) and the Remix `.usda` exporter (M4, which "depends on yae-qindieGL") are not started.
- The AI generation pipeline is provider-neutral and has only the deterministic backend; a local AI provider is backlog. AI base colour is forbidden by default.

The SDK has:
- format parsers;
- level → OBJ and model → glTF/GLB export (textures not embedded);
- a lightmap baker with direct light + AO only (its old path-tracing baker was removed after producing black atlases).

`yae-level-converter` exports OBJ. yae-dlss5 and yae-QindieGL are "graphics mods for the original" outside the Release 1 core.

### Cited Findings

**The workspace**
- The workspace README lists the pillars: the new engine; the SDK; the format specs; the PBR catalog, whose work "results in the native renderer and in RTX Remix alike"; and graphics mods for the original game, "yae-dlss5 brings DLSS 5 Neural Rendering to the original". — [README.md:26-33](file:///home/alex/PetProjects/YAE-dlls/README.md#L26-L33)
- The state table (2026-10-05) gives the materials catalog "MVP", QindieGL "Experiment", and yae-dlss5 "Experiment, public". — [README.md:56-67](file:///home/alex/PetProjects/YAE-dlls/README.md#L56-L67)
- `bootstrap.sh` clones the Release 1 core (`yae-engine yae-sdk yae-materials yae-docs yae-research yae-viewer`). It clones `yae-QindieGL yae-dcc-plugins yae-level-converter yae-dlss5` only with `--all`. — [bootstrap.sh:15-16](file:///home/alex/PetProjects/YAE-dlls/bootstrap.sh#L15-L16); [bootstrap.sh:37-38](file:///home/alex/PetProjects/YAE-dlls/bootstrap.sh#L37-L38)
- The engine finds its neighbours itself (`../yae-game/gameres`, `../yae-materials/export/engine/catalog.yaemat`, `../yae-sdk/sdk-desktop`). — [README.md:73-77](file:///home/alex/PetProjects/YAE-dlls/README.md#L73-L77)

**yae-materials**
- **Purpose.** It is "a neutral, engine-independent description 'texture → material' … the YAE Engine renderer, RTX Remix (through the shim) and the SDK's glTF export. One source of truth, three targets". It exists because "Post-processing (ReShade) therefore stops at 'colour grading plus reflections on everything'". — [yae-materials/README.md:5-16](file:///home/alex/PetProjects/YAE-dlls/yae-materials/README.md#L5-L16)
- **How it works.**
  - Schema v2 records hold the PBR slots `off | original | constant | recipe | artifact`.
  - Derived maps are baked deterministically: a height map from luminance → a normal map, OpenGL Y+.
  - The exporters:
    - `engine` (`catalog.yaemat`, "a development-only compatibility export until Phase 5")
    - `gltf` (planned)
    - `remix` (planned)
    - `unity` (planned)
  
  — [README.md:18-38](file:///home/alex/PetProjects/YAE-dlls/yae-materials/README.md#L18-L38)
- **Coverage.** 942 records, covering **98.1%** (885 of 902) of the textures the golden levels actually draw. — [PLAN.md:147-149](file:///home/alex/PetProjects/YAE-dlls/yae-materials/PLAN.md#L147-L149); [PLAN.md:325-326](file:///home/alex/PetProjects/YAE-dlls/yae-materials/PLAN.md#L325-L326)
- **M3, the glTF exporter (`[ ]`):** `KHR_materials_*` in the `.ds2md` → glTF/GLB export, maps beside the glb, Blender presets. — [PLAN.md:151-157](file:///home/alex/PetProjects/YAE-dlls/yae-materials/PLAN.md#L151-L157)
- **M4, the RTX Remix exporter (`[ ]`, "depends on yae-qindieGL"):**
  - map texture paths to the IDs Remix sees through the shim;
  - generate a `.usda` asset database with PBR parameters, normal maps and a "policy for baked light";
  - an importer from Remix's own AI generator back into the catalog.
  
  Its acceptance test: "one test room in the original game through the shim + Remix looks better than the base pass". — [PLAN.md:159-167](file:///home/alex/PetProjects/YAE-dlls/yae-materials/PLAN.md#L159-L167)
- **Delivery status.**
  - Phase 2 (the local artifact pipeline) is complete.
  - Phase 3 is implementation-complete, with pilot acceptance pending.
  - Phase 4 (Kitsu) is in work.
  - Phase 5 (production engine delivery): the `.yaepak` one-file pack was done 2026-10-05.
  
  — [PLAN.md:10-21](file:///home/alex/PetProjects/YAE-dlls/yae-materials/PLAN.md#L10-L21)
- **The AI backend.**
  - The local provider-neutral pipeline is implemented (P2-00–P2-09). The deterministic backend is the first adapter. "local/cloud AI adapters remain a separate generation backlog M5".
  - The planned backends: deterministic normal ("no GPU, synthetic E2E in CI"), local AI ("ComfyUI etc.", the default for a person), and cloud AI ("only with explicit consent").
  - The default mode is `faithful`, and "baseColor from AI is forbidden by default".
  - The choice of one local AI provider is backlog item 6.
  
  — [docs/GenerationPipeline.md:1-35](file:///home/alex/PetProjects/YAE-dlls/yae-materials/docs/GenerationPipeline.md#L1-L35); [GenerationPipeline.md:138-153](file:///home/alex/PetProjects/YAE-dlls/yae-materials/docs/GenerationPipeline.md#L138-L153); [GenerationPipeline.md:350-356](file:///home/alex/PetProjects/YAE-dlls/yae-materials/docs/GenerationPipeline.md#L350-L356)
- **How the engine consumes it.**
  - `--materials-catalog`, else `render.cfg` `materials_catalog`, else the Workbench `current.json`, else `export/engine/catalog.yaemat`.
  - `.yaepak` packs are layered on top.
  - `--no-materials-catalog` or `mat_catalog 0` loads levels vanilla.
  
  — [yae-engine/CLAUDE.md:36-43](file:///home/alex/PetProjects/YAE-dlls/yae-engine/CLAUDE.md#L36-L43)
- **The material contract** with yae-materials is at version 1.0 (shader sha256s, `matball.json`). — [Roadmap.md:151-158](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L151-L158)
- **Shaders vendored the other way.** The engine shaders copied into `yae-materials/vendor/engine-shaders/` stay GPL-3.0-or-later (D34). — [docs/Decisions.md:60](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Decisions.md#L60)

**yae-sdk and yae-level-converter**
- **The SDK's parts:**
  - a format library: `.ds2`, `.ds2md`, `.ds2edf`, collisions, `.mat`, …
  - a desktop editor (Electron/React/Three.js) that bakes lightmaps on the GPU;
  - a CLI: "Level → OBJ, model → OBJ/glTF/GLB".
  
  — [yae-sdk/README.md:19-22](file:///home/alex/PetProjects/YAE-dlls/yae-sdk/README.md#L19-L22)
- **The glTF export's limits.** In the model glTF export, "textures are not embedded or converted to Blender-ready glTF images yet". No level → glTF path is listed (levels go to OBJ). — [sdk-desktop/docs/DS2MD_GLTF_EXPORT.md:91](file:///home/alex/PetProjects/YAE-dlls/yae-sdk/sdk-desktop/docs/DS2MD_GLTF_EXPORT.md#L91)
- **The lightmap baker today.** It is v2 (`three-mesh-bvh`): direct light + AO, "Полного GI … движок не считает" ("the engine does not compute full GI"). The legacy v1 "полный path tracing через `three-gpu-pathtracer`" ("full path tracing through three-gpu-pathtracer") was removed, because it "выдавал полностью чёрные атласы и падал" ("produced completely black atlases and crashed").
  - `three-gpu-pathtracer ^0.0.23` is still a dependency of `engine-three`. — [sdk-desktop/docs/LIGHTMAP_BAKER.md:10-26](file:///home/alex/PetProjects/YAE-dlls/yae-sdk/sdk-desktop/docs/LIGHTMAP_BAKER.md#L10-L26); [sdk-desktop/packages/engine-three/package.json:13](file:///home/alex/PetProjects/YAE-dlls/yae-sdk/sdk-desktop/packages/engine-three/package.json#L13)
  - The engine's Phase 40 document still describes the SDK baker as `three-gpu-pathtracer` with 2 bounces, so it is out of date. — [yae-engine/docs/Phase40_GraphicsRealism.md:72](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase40_GraphicsRealism.md#L72)
- **The SDK's build state is uncertain.** The engine Roadmap says the SDK "build is red, the fixtures are missing" and must be fixed before 40.5. The SDK, however, has commits through 2026-10-07 ("Refactor2 (#34)", new tests), so that statement may be stale. — [Roadmap.md:404-406](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L404-L406); `git log` of [yae-sdk](file:///home/alex/PetProjects/YAE-dlls/yae-sdk)
- **`yae-level-converter`** is a C++17 command-line tool, from 2013 with a Linux build in 2026. It exports level geometry, materials and model instances to OBJ. — [yae-level-converter/README.md:5-9](file:///home/alex/PetProjects/YAE-dlls/yae-level-converter/README.md#L5-L9)

**The private RE repository (README only)**
- `yae-research-private` holds the decompiler output, the Ghidra project and the game binaries. Only conclusions leave it, into the public `yae-research`. — [yae-research-private/README.md:1-14](file:///home/alex/PetProjects/YAE-dlls/yae-research-private/README.md#L1-L14)
- Not all binaries are one build. `ds2kernel.dll`, `sv_game.dll`, `ds2NavSystem.dll` and `you_are_empty.exe` are 2019 community rebuilds. — [yae-research-private/README.md:32-40](file:///home/alex/PetProjects/YAE-dlls/yae-research-private/README.md#L32-L40)

### Inferences
- **The catalog is the natural bridge to any PT route.** That can be an engine RT backend's material table, or Remix USD replacements. But the RT-specific fields the engine lists (`alpha_mode`, `emissive_is_light`, two-sidedness, IOR/transmission) would have to exist in the catalog schema. That was not verified here.
- **Remix route dependencies.** M4 depends on QindieGL's draw and texture stream, and on Remix's own texture hashes (as used in `rtx.decalTextures`). A stable texture-ID mapping is therefore a QindieGL-side prerequisite.
- **Where PT geometry would come from.** For an engine-side path tracer, geometry and materials would come from the engine's own CPU-side `LevelData`/`ModelData` and `RenderScene`, not from SDK exports. The SDK and level-converter are export tools for DCCs (Blender, 3ds Max, Maya).
- **About the CPU-0 pin.** `ds2kernel.dll`, which pins the game to CPU 0 (§2), is one of the 2019 community rebuilds. Whether the 2006 retail kernel also pins the CPU is not stated.

### Gaps
- It was not checked whether the yae-materials schema v2 carries RT fields.
- There is no USD exporter, and no level → glTF export with materials.
- No owner or date is set for M3/M4. It is unclear whether the SDK's "red build" is still true.

---

## 5. Hardware and development environment

### Takeaway
- **Development machine:** Linux with an **RTX 5090** (32 GB), driver **590.48.01**, and a Ryzen 9 9950X3D. Today it reports OpenGL 4.6 and Vulkan 1.4.325. It qualifies for OpenDLSS-NR. No Mesa or AMD/Intel GPU is available on it.
- **A Windows environment with an RTX 5090 on driver 616.92** was used to test yae-dlss5. The QindieGL work runs from `H:\YAE\Original\You Are Empty` at 1920×1080, because 3440×1440 failed DS2's mode init. The engine has not yet run on real Windows (wine only).
- **The release's mid-range target (D10)** is an **RTX 3060 Ti or its AMD equivalent**. It has never been measured (K4), and it cannot run either NR path: yae-dlss5 needs RTX 50, the engine's NR branch needs Ada+.

### Cited Findings
- **The local query (2026-10-07):** `NVIDIA GeForce RTX 5090, 590.48.01, 32607 MiB`; "OpenGL core profile version string: 4.6.0 NVIDIA 590.48.01"; Vulkan `apiVersion = 1.4.325`, `driverVersion = 590.48.1.0`. — [local nvidia-smi / glxinfo -B / vulkaninfo --summary, run 2026-10-07](file:///usr/bin/nvidia-smi)
- **The reference machine** for the frame budgets is the "RTX 5090, Ryzen 9 9950X3D". — [yae-engine/docs/Phase40_GraphicsRealism.md:252-254](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase40_GraphicsRealism.md#L252-L254)
- **The NR extensions on the dev machine.** "The development machine qualifies: an RTX 5090 with driver 590.48.01 under Linux reports all four extensions, plus `GL_EXT_memory_object_fd` and `GL_EXT_semaphore_fd`" (checked 2026-09-25). — [yae-engine/docs/Roadmap.md:365-368](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L365-L368)
- **The Windows side, for the original game.**
  - yae-dlss5 was tested on an RTX 5090 with driver 616.92.
  - Its README comparison images are 3440×1440 PNGs.
  
  — [yae-dlss5/README.md:63](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/README.md#L63); [yae-dlss5/VERSIONS.txt:13-14](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/VERSIONS.txt#L13-L14); [docs/images/example1.png](file:///home/alex/PetProjects/YAE-dlls/yae-dlss5/docs/images/example1.png)
- **The QindieGL test setup.**
  - Game path `H:\YAE\Original\You Are Empty\YOU_ARE_EMPTY.EXE`.
  - "The 3440x1440 attempt failed before renderer initialization with `Can't Initialize Screen Resolution`", so 1920×1080 is used.
  - The profiling runs are 1920×1080.
  
  — [yae-QindieGL/STATUS.md:65-96](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L65-L96); [STATUS.md:782-784](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/STATUS.md#L782-L784)
- **The engine on Windows** has been checked "only under wine … It has not run on a real Windows yet". — [yae-engine/docs/WindowsBuild.md:129-133](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/WindowsBuild.md#L129-L133)
- **D10.** "The mid-range GPU for the frame budget is an RTX 3060 Ti or its AMD equivalent" (2026-09-23). — [yae-engine/docs/Decisions.md:36](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Decisions.md#L36)
  - The retail-session note adds that "with graphics features (40.3+, 51) the bar can be raised to higher models" (translated). — [yae-engine/docs/RetailSession.md:372](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/RetailSession.md#L372)
  - K4 is "не мерено" ("not measured"); the measurement is "on the user's hardware". — [docs/Phase47_Release1Readiness.md:202](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase47_Release1Readiness.md#L202); [docs/Phase47_Release1Readiness.md:1268-1270](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase47_Release1Readiness.md#L1268-L1270)
  - The shadow memory fits the 8 GB RTX 3060 Ti. — [docs/Phase47b_ReleaseBlockers.md:1030](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase47b_ReleaseBlockers.md#L1030)
- **The NR branch and D10.** "The release's mid-range GPU (D10, RTX 3060 Ti, Ampere) will not run it." The cost figures quoted there are an RTX 4070 SUPER's, from the external project, not project hardware. — [Roadmap.md:364](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L364); [Roadmap.md:369](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Roadmap.md#L369)
- **AMD and Intel.** "NVIDIA and AMD with current drivers" are the stated targets, and "Intel integrated graphics has not been tested". There is no Mesa on the dev machine. No AMD or Intel test hardware is named in any document read. — [WindowsBuild.md:230-236](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/WindowsBuild.md#L230-L236); [Phase39_EngineHardening.md:871-873](file:///home/alex/PetProjects/YAE-dlls/yae-engine/docs/Phase39_EngineHardening.md#L871-L873)
- **The Remix GPU.** The Remix runtime used is 1.5.2. The QindieGL repository does not name the GPU used for Remix runs. — [yae-QindieGL/tools/remix/README.md:42-56](file:///home/alex/PetProjects/YAE-dlls/yae-QindieGL/tools/remix/README.md#L42-L56)

### Inferences
- The Windows runs (dlss5 on an RTX 5090, QindieGL/Remix on `H:\`) and the Linux dev box may be one dual-boot machine; both have an RTX 5090. Nothing records this.
- Every NR route the projects have is gated to high-end NVIDIA hardware: RTX 50 for yae-dlss5, Ada+ for the engine's NR. The only hardware actually present is an RTX 5090, so NR and PT results will not say anything about the D10 target.

### Gaps
- It is not recorded whether the Windows test system is the same physical machine as the Linux dev box, or what its CPU and display are (only the 3440×1440 screenshots hint at an ultrawide).
- The GPU used for the QindieGL/Remix runs is not stated.
- No AMD, Intel or mid-range NVIDIA hardware is recorded as available for testing.
