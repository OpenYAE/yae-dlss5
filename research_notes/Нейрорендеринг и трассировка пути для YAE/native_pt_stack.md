# Native path tracing stack for yae-engine: cross-vendor routes as of 2026-10-07

Conventions: "GH" means I checked the repository with the `gh` CLI on 2026-10-07 (push dates, releases, file trees, READMEs). Dates are ISO. "(snippet)" means the claim came from a search-engine summary and I could not retrieve the article text, so treat it as unverified. Licences are given only as plain facts. Neural shading (cooperative vectors, NTC, neural materials, DLSS 5) is out of scope; NRC and the ML denoisers appear only as parts of the path tracing stack.

## 1. API route: Vulkan RT, D3D12 DXR, GL 4.5 plus a Vulkan RT pass, or an RHI

### Takeaway
Vulkan (`VK_KHR_ray_query` / `VK_KHR_ray_tracing_pipeline`) is the only API that keeps Linux and reaches every RT-capable GPU: RTX 20+, RDNA2+ and Arc Alchemist+. You can use it as your own backend or through NVRHI, NRI or Diligent. D3D12 alone gives up native Linux, but it is the only API where AMD FSR 4/Redstone, Intel XeSS-FG/MFG and Intel's working SER exist. GL 4.5 plus a Vulkan RT pass shared through `GL_EXT_memory_object`/`GL_EXT_semaphore` is proven on NVIDIA and is supported by Mesa radeonsi/iris. Frame generation and latency features still need Vulkan (or D3D) to own presentation. SDL3's GPU API has no ray tracing, and none is planned.

### Cited Findings
**Vulkan on Linux and in production**
- Mesa `docs/features.txt` (latest commit 2026-10-06):
  - `VK_KHR_ray_tracing_pipeline` is DONE on `anv/gfx12.5+` (Intel Arc Alchemist and newer), `radv/gfx10.3+` (RDNA2 and newer), `lvp` (lavapipe, CPU) and `vn`.
  - `VK_KHR_ray_query` and `VK_KHR_acceleration_structure` are DONE on the same drivers plus `tu/a740+`.
  - NVK (the open NVIDIA driver) is not listed for any KHR ray tracing extension.
  - Source: [Mesa features.txt](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/docs/features.txt)
- The same file lists no Mesa driver for `VK_EXT_opacity_micromap` or `VK_EXT_ray_tracing_invocation_reorder`. Other entries:
  - `VK_KHR_ray_tracing_position_fetch`: anv and radv/gfx10.3+.
  - `VK_KHR_cooperative_matrix`: anv, nvk/Turing+ and radv/gfx11+.
  - `VK_EXT_present_timing`: anv, nvk, radv and others.
  - Source: [Mesa features.txt](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/docs/features.txt)
- Mesa 26.0 RADV gave RDNA3/3.5/4 an average RT gain of about +25–35%, about +75% in Desordre and about +50% in Silent Hill 2 Remake — [igor'sLAB](https://www.igorslab.de/en/mesa-26-0-radv-catapults-radeon-raytracing-forward-under-linux/).
  - Older Phoronix testing (snippet) still had Windows ahead in Quake II RTX on RDNA3.5, while RADV on Strix Halo came out narrowly ahead with Mesa 25.0 — [Phoronix](https://www.phoronix.com/review/amd-strix-halo-windows-linux/2).
- Shipped Vulkan path tracing runs on other vendors:
  - Doom: The Dark Ages (id Tech 8, Vulkan) got path tracing in an update on 2025-06-18 ([igor'sLAB](https://www.igorslab.de/en/path-tracing-in-doom-the-dark-ages-six-months-of-development-and-outlook/)). It was benchmarked on RX 9070/9070 XT ([PCGamesN, 2025-06-28](https://www.pcgamesn.com/doom-the-dark-ages/nvidia-amd-path-tracing-benchmarks)).
  - Indiana Jones and the Great Circle allows path tracing on Arc/Radeon cards with ≥16 GB and on GeForce cards with ≥11 GB ([PCGH, 2025-06-04](https://www.pcgameshardware.de/Radeon-RX-9060-XT-16GB-Grafikkarte-281275/Tests/Release-Benchmark-Preis-Specs-1473547/5/)).
- AMD announced Vulkan ray tracing extensions in its Windows driver in 2020 for RDNA2 — [GPUOpen](https://gpuopen.com/?p=15574) (search result, dated 2020).
- Vulkan SER became multi-vendor as `VK_EXT_ray_tracing_invocation_reorder`, released 2025-11-12 in Vulkan 1.4.333. Contributors included NVIDIA, AMD, Intel, Qualcomm, Arm and others. Khronos cites up to 47% gains in the Vulkan glTF path tracer — [Phoronix](https://www.phoronix.com/news/Vulkan-1.4.333-Released), [Khronos proposal](https://docs.vulkan.org/features/latest/features/proposals/VK_EXT_ray_tracing_invocation_reorder.html).
- Mega Geometry-class features on Vulkan are still NVIDIA-only extensions: `VK_NV_cluster_acceleration_structure` and `VK_NV_partitioned_acceleration_structure` — [Vulkan docs](https://docs.vulkan.org/features/latest/features/proposals/VK_NV_cluster_acceleration_structure.html), [Vulkan docs](https://docs.vulkan.org/features/latest/features/proposals/VK_NV_partitioned_acceleration_structure.html).

**D3D12 DXR**
- DXR 1.2 shipped in retail form with Shader Model 6.9 and Agility SDK 1.619 on 2026-02-26 — [DirectX blog](https://devblogs.microsoft.com/directx/shader-model-6-9-retail-and-more/). The blog's vendor table:
  - **OMM:** "All RTX hardware. Hardware-accelerated on RTX 4xxx+ GPUs, software-emulated on older." AMD and Intel are both marked "–".
  - **SER:** AMD RX 9000 "supports API but doesn't reorder"; Intel Arc B-Series "support API and do reordering"; NVIDIA RTX 4xxx+ "support API and do reordering".
  - **Drivers:** AMD Adrenalin 26.2.1; NVIDIA 595+.
  - **Cooperative Vector** is deprecated in favour of a unified matrix design in SM 6.10.
  - **Conflict:** a search-engine summary that cited wccftech claimed AMD RX 9000 and Arc B-series support OMM. The primary Microsoft table marks both "–".
- On 2026-03-17 Microsoft published specs for the next DXR features: clustered geometry, partitioned TLAS and indirect AS operations. A preview was planned for summer 2026 — [Notebookcheck](https://www.notebookcheck.net/Microsoft-reveals-next-gen-DirectX-ray-tracing-specifications-launching-summer-2026.1253423.0.html) (snippet). PCGH headlines it "DXR 2.0" — [PCGH](https://www.pcgameshardware.de/Raytracing-Hardware-255905/Specials/DirectX-Update-mit-DXR-2-0-1522640/).
- Features that exist only on D3D12 in October 2026:
  - AMD FSR 4, FSR FG 4, Ray Regeneration and Radiance Cache (FSR SDK 2.x ships only `_dx12.dll`s).
  - Intel XeSS-FG/MFG (DX12-only).
  - Details in sections 4–5.

**GL 4.5 plus a Vulkan pass through interop**
- Mesa:
  - `GL_EXT_memory_object` is DONE on freedreno, radeonsi, llvmpipe, zink, d3d12, iris and crocus/gen7+. `GL_EXT_memory_object_fd` is the same list minus d3d12.
  - `GL_EXT_semaphore` and `GL_EXT_semaphore_fd` are DONE on radeonsi, zink, iris and crocus.
  - The `_win32` variants exist only in zink and d3d12.
  - Source: [Mesa features.txt](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/docs/features.txt)
- NVIDIA's `nvpro-samples/gl_vk_raytrace_interop` adds ray-traced AO computed with Vulkan ray tracing to an OpenGL renderer. Its rule is that "all shared objects must be allocated by Vulkan", and it covers G-buffers, semaphores and compositing. Last push 2024-01-17. The sibling `gl_vk_simple_interop` is still active (pushed 2026-10-06) — [gl_vk_raytrace_interop](https://github.com/nvpro-samples/gl_vk_raytrace_interop), [gl_vk_simple_interop](https://github.com/nvpro-samples/gl_vk_simple_interop) (GH).
- DLSS Frame Generation through direct NGX integration:
  - Supported APIs: DirectX 11, DirectX 12, Vulkan 1.1+ and CUDA. OpenGL is not listed.
  - "The DLSS-FG feature itself does not handle timing or presentation; this is the responsibility of your application."
  - Source: [DLSS-FG Programming Guide 310.7.0](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS-FG%20Programming%20Guide.pdf)
- `RgInstanceCreateInfo` in RTGL1 takes only Win32, Metal, Wayland, XCB and Xlib surface descriptions. It has no fields for importing an external VkInstance or VkDevice, so the library owns its device and swapchain — [RTGL1.h](https://github.com/vs-shirokii/RTGL/blob/main/Include/RTGL1/RTGL1.h) (GH).

**RHIs**
- **NVRHI**
  - D3D11, D3D12 and Vulkan 1.3, on Windows and Linux (x64/ARM64).
  - "Supports all types of pipelines: Graphics, Compute, Ray Tracing, and Meshlet."
  - MIT; pushed 2026-10-05.
  - RTXDI's samples run on D3D12 or Vulkan through NVRHI (`--device.vk`).
  - Sources: [NVRHI](https://github.com/NVIDIA-RTX/NVRHI), [RTXDI README](https://github.com/NVIDIA-RTX/RTXDI) (GH)
- **NRI** (NVIDIA Rendering Interface)
  - D3D11, D3D12 and Vulkan; MIT; v180 released 2026-06-22.
  - NRD's integration layer is built on it.
  - Sources: [NRI](https://github.com/NVIDIA-RTX/NRI), [NRD README](https://github.com/NVIDIA-RTX/NRD) (GH)
- **Diligent Engine**
  - D3D11, D3D12, OpenGL/GLES, Vulkan, Metal and WebGPU. On Linux: OpenGL, Vulkan and WebGPU (WebGPU needs Dawn).
  - Samples include "Tutorial 21 – Ray Tracing", "Tutorial 22 – Hybrid Rendering" and path tracing tutorials.
  - Apache-2.0. The last tagged release is v2.5.6 (2024-09-02), but master was pushed 2026-10-05.
  - Sources: [DiligentEngine](https://github.com/DiligentGraphics/DiligentEngine), [DiligentSamples](https://github.com/DiligentGraphics/DiligentSamples) (GH)
- **The Forge**
  - Apache-2.0. Supports "Steam Deck with Vulkan 1.1 with VK_KHR_ray_query" and has Linux CI.
  - Release 1.63 (2025-03-21) added "Advanced RTX Global Illumination Middleware". Release 1.62 was a C99 Vulkan/DirectX rewrite. Repo pushed 2026-08-27.
  - Source: [The-Forge](https://github.com/ConfettiFX/The-Forge) (GH)
- **wgpu**
  - Ray tracing is "experimental", "may have major bugs" and is "subject to breaking changes". It sits behind `Features::EXPERIMENTAL_RAY_QUERY` — [wgpu docs](https://wgpu.rs/doc/wgpu/documentation/extensions/ray_tracing/index.html).
  - Ray tracing pipelines are arriving piece by piece — [wgpu CHANGELOG](https://github.com/gfx-rs/wgpu/blob/trunk/CHANGELOG.md):
    - v29.0.0 (2026-03-18): WGSL-in ray tracing pipelines.
    - v30.0.0 (2026-07-01): SPIR-V-out ray tracing pipelines.
    - Unreleased: `EXPERIMENTAL_RAY_TRACING_PIPELINES`, `hit_barycentrics`, and raw `VkAccelerationStructureKHR` handles so apps can use `VK_NV_cluster_acceleration_structure`.
- **SDL3 GPU API**
  - Issue #15986, "Will someday add ray tracing and mesh shader?", was closed as not_planned on 2026-07-13. Maintainer reply: "Maybe some day, but we have no immediate plans to do this" — [SDL #15986](https://github.com/libsdl-org/SDL/issues/15986).
  - The 2024 policy is that new GPU features must come as PRs covering all supported backends, consoles included — [SDL #11147](https://github.com/libsdl-org/SDL/issues/11147).
  - Latest SDL release: 3.4.18 (2026-10-02) (GH).
- **Godot**
  - "Vulkan raytracing plumbing" was merged on 2026-01-27 (milestone 4.7) — [PR #99119](https://github.com/godotengine/godot/pull/99119).
  - All ray tracing functionality was marked experimental on 2026-04-13 — [PR #118377](https://github.com/godotengine/godot/pull/118377).
  - Ray query was wired on Vulkan on 2026-08-04 — [PR #122051](https://github.com/godotengine/godot/pull/122051), [PR #123093](https://github.com/godotengine/godot/pull/123093).

### Inferences
- **Vulkan should be the core of the RT path.** No other single API reaches RTX 20–50, RDNA2–4 and Arc on both Windows and Linux. The API itself costs no coverage. The price is engineering: device/memory/descriptor/swapchain code plus a second set of shaders, or an RHI that hides them.
- **The GL-plus-Vulkan-pass route is the cheapest prototype.** It works for RT shadows, AO, GI or reflections composited into GL, and for running DLSS-SR/RR, FSR 3.1 or NRD on Vulkan images shared with GL. The bridge that is already planned for the neural pass can be reused.
  - It cannot host frame generation or latency SDKs while GL presents.
  - Inverting the bridge would fix that: Vulkan owns the swapchain, and GL renders into Vulkan-allocated images (allocation ownership as in NVIDIA's sample).
  - Every piece of geometry also has to live in Vulkan buffers to build the BVH.
- **D3D12 is worth a separate backend only for FSR 4/Redstone or XeSS-FG on Windows.** It cannot replace Vulkan for YAE because Linux is a requirement.
- **NVRHI gives the most leverage** for reusing RTX Kit sample code (RTXDI, RTXPT and Donut are written against it). Diligent is the only C++ RHI here that also keeps a desktop OpenGL backend, so the GL renderer could move onto it first and switch to Vulkan later. wgpu also has a GL/GLES backend, but it is Rust and its ray tracing is experimental. SDL3 GPU is out for ray tracing.
- Because lavapipe implements the KHR ray tracing extensions, RT code could run on the CPU in headless CI gates. It would be slow, but it would not need a GPU.

### Gaps
- I could not verify Windows AMD and Intel OpenGL driver support for `GL_EXT_memory_object_win32` / `GL_EXT_semaphore_win32`. The gpuinfo.org tables load over AJAX and were not retrievable. This matters for the interop route on Windows non-NVIDIA cards.
- I did not verify proprietary-driver support for `VK_EXT_opacity_micromap` and `VK_EXT_ray_tracing_invocation_reorder` on AMD/Intel Windows, or on the NVIDIA Linux driver.
- I could not verify whether the summer-2026 DXR preview (clustered geometry, partitioned TLAS) shipped, or which vendors support it.
- No third-party estimate of engineering cost per route exists. The cost statements above are my judgement.

## 2. RTGL1: maintenance status, features, shipped games, cross-vendor behaviour, Linux, API shape

### Takeaway
RTGL1 (MIT) is effectively unmaintained:
- **Upstream** (`sultim-t/RayTracedGL1`; the `sultim-t/RTGL1` name returns 404): last commit 2023-11-26.
- **Author's continuation** (`vs-shirokii/RTGL`): last push 2024-08-27; last release 1.6.3 (2024-08-03).

It is a complete path tracer for retro games: ReSTIR DI and GI, A-SVGF denoising, volumetrics, decals, portals, a lightmap UV layer, and texture and glTF replacement. Upscaling is DLSS or FSR 2/3; there is no XeSS and no NRD or DLSS-RR. Frame generation exists only through a Windows D3D12 interop path. AMD has been supported since 2022, and Linux build fixes landed in November 2023. It is a fast way to get an experimental branch, but YAE would effectively own a fork.

### Cited Findings
- `sultim-t/RTGL1` returns 404. The real repository is [`sultim-t/RayTracedGL1`](https://github.com/sultim-t/RayTracedGL1) (GH):
  - Created 2020-11-03; MIT; default branch `hl1` (branches `doom`, `hl1`, `quake`); 158 stars, 57 forks, 23 open issues.
  - Last commits 2023-11-26: the merged "linux-build" PR from pixelcluster ("Fix various build errors on Linux", "Make FSR2 optional", "Use CMake to automatically generate shaders").
  - Releases: v1.1.0/v1.1.1 (2022-04), v2.0.1 (2022-10-01), hl1-dev (2023-02-05).
- README description: a library to simplify "porting 3D applications to real-time path tracing, via hardware accelerated ray tracing, denoising algorithms (A-SVGF) and sampling algorithms (ReSTIR, ReSTIR GI)" — [README](https://github.com/sultim-t/RayTracedGL1). It also documents:
  - CMake surface options for Win32, Metal, Wayland, XCB and Xlib.
  - Shader hot-reload.
  - "Texture overriding": loading PBR maps by texture name, in KTX2 produced with Compressonator, through `pOverridenTexturesFolderPath`.
- The author's continuation is [`vs-shirokii/RTGL`](https://github.com/vs-shirokii/RTGL) (GH):
  - A fork of RayTracedGL1 created 2023-12-02, the same day the account was created; MIT; branches `main` and `remix`.
  - Last commits:
    - 2024-08-09: "Remove native DLSS from a standalone build, use Streamline" and "Custom DLL paths".
    - 2024-08-27: "Add compiled binaries for FSR2/FSR3".
  - Release "RTGL1 Renderer 1.6.3" (2024-08-03) "Added RTX Remix as an additional renderer". The README adds a requirement of Windows SDK ≥ 10.0.22621.0.
- API shape, from [`Include/RTGL1/RTGL1.h`](https://github.com/vs-shirokii/RTGL/blob/main/Include/RTGL1/RTGL1.h) (1,364 lines, GH):
  - **Entry points.** A C API loaded through a function table: `rgCreateInstance`/`rgDestroyInstance`, `rgStartFrame`, `rgUploadCamera`, `rgUploadMeshPrimitive`, `rgUploadLight`, `rgUploadLensFlare`, `rgSpawnFluid`, `rgProvideOriginalTexture`, `rgMarkOriginalTextureAsDeleted` and `rgDrawFrame`. There are also utility calls, including `rgUtilIsUpscaleTechniqueAvailable` and `rgUtilIsDXGIAvailable`.
  - **Light types.** Directional, spherical, polygonal and spot.
  - **Create-info fields.**
    - Surface descriptions only.
    - `lightmapTexCoordLayerIndex`, up to three extra texcoord layers, `rasterizedSkyCubemapSize`.
    - `pbrTextureSwizzling`, `worldUp`/`worldForward`/`worldScale`.
    - Imported light intensity scales.
  - **Rendering options.**
    - `RgRenderUpscaleTechnique` = {LINEAR, NEAREST, AMD_FSR2, NVIDIA_DLSS}.
    - `RgFrameGenerationMode` = {OFF, WITHOUT_GENERATED, ON}.
    - Sharpening {NONE, NAIVE, AMD_CAS}.
    - Resolution modes ULTRA_PERFORMANCE through QUALITY, plus NATIVE_AA and CUSTOM.
  - **D3D12.** A `RG_D3D12CORE_HELPER` macro exports `D3D12SDKVersion = 611`.
- Source tree of `vs-shirokii/RTGL`, `main` branch (GH):
  - **Upscaling and frame generation:** `DLSS2.cpp`, `DLSS3_DX12.cpp`, `FSR2.cpp`, `FSR3_DX12.cpp`, `DX12_Interop.h`, `DX12_Swapchain.cpp`, `DX12_Vulkan.cpp`, and FidelityFX headers including `ffx_fsr3upscaler.h` and `FrameInterpolationSwapchainDX12.cpp`.
  - **Lighting and effects:** `RestirBuffers`, `LightGrid`, `Volumetric`, `PortalList`, `DecalManager`, `LensFlares`, `Fluid`.
  - **Assets and denoiser:** `GltfImporter`/`GltfExporter`, `TextureOverrides`, and SVGF/A-SVGF compute shaders.
  - **Pipeline:** shaders are `.rgen/.rchit/.rahit/.rmiss`, which means `VK_KHR_ray_tracing_pipeline`. There is also a classic raster path (`RsWorld_Classic.frag`).
- Workflow commits in the history (GH):
  - 2023-09-30: "Export recorder through multiple frames", "'replace' folder: last (by alphabetical order) gltf files are loaded first", "Don't export if replacements exist".
  - 2023-11-10/12: first-person and viewer flags per instance, "Compressed vertex from 64 to 32 bytes".
  - So scene geometry can be exported to glTF, hand-edited, and loaded back as replacements.
- Shipped projects (GH releases):
  - Serious Sam TFE: Ray Traced v1.5 (2022-04-20): "RTGL1 with AMD support: thanks to kd-11". DLSS is optional (drop in `nvngx_dlss.dll` plus a DLSS build of `RayTracedGL1.dll`) — [Serious-Engine-RT v1.5](https://github.com/sultim-t/Serious-Engine-RT/releases/tag/v1.5)
  - PrBoom: Ray Traced 1.0.7 (2022-04-26) — [prboom-plus-rt](https://github.com/sultim-t/prboom-plus-rt/releases)
  - Quake 1: Ray Traced 1.0.2 "AMD" (2022-10-06) — [vkquake-rt](https://github.com/sultim-t/vkquake-rt/releases)
  - Half-Life 1: Ray Traced 1.0.5a (2023-03-04; 1,180 stars; optional DLSS bundle) — [xash-rt](https://github.com/sultim-t/xash-rt/releases)
  - Doom II: Ray Traced (GZDoom RT) 1.0.2a (2024-08-11): DLSS and NVIDIA Frame Generation through the custom RTGL 1.6.3, with RTX Remix as an experimental alternative renderer — [gzdoom-rt](https://github.com/vs-shirokii/gzdoom-rt/releases)
- Community use in 2026 (GH):
  - [`ocolunga/gzdoom-rt`](https://github.com/ocolunga/gzdoom-rt) (pushed 2026-01-31) says "Ray tracing (HAVE_RT) requires the RTGL1 SDK and is Windows-only for now. Linux builds fall back…" and "Linux and macOS compile but without ray tracing".
  - [`gonzaloberteri/counter-strike-rt`](https://github.com/gonzaloberteri/counter-strike-rt) (pushed 2026-07-06) runs CS 1.6 and Half-Life on Xash3D-RT with "RTGL1 (Vulkan path tracing) + NVIDIA DLSS".
  - Several RayTracedGL1 forks were pushed in 2026 (latest 2026-09-25), all with 0 stars.
- PCGH's 2025 path tracing GPU suite includes Half-Life: Ray Traced (alongside Q2RTX and Portal RTX) — [PCGH](https://www.pcgameshardware.de/Radeon-RX-9060-XT-16GB-Grafikkarte-281275/Tests/Release-Benchmark-Preis-Specs-1473547/5/).

### Inferences
- **Fit with YAE.** RTGL1's content model suits YAE closely:
  - Texture overrides by name suit the PBR upgrade of legacy materials.
  - A dedicated lightmap UV layer suits lightmapped legacy content.
  - glTF export/replace suits hand-placed RT lights, as GZDoom RT did.
  - Per-frame immediate submission plus static scene caching suits the planned `RenderScene` extraction seam.
- **Integration shape.** RTGL1 owns its Vulkan device and swapchain, so in YAE it fits as an alternative renderer chosen at startup (`--renderer rt`), not as a pass inside GL. SDL3 can supply the native Win32, Wayland or X11 handles it needs.
- **Vendor coverage.**
  - NVIDIA: DLSS (SR only, no RR).
  - Everyone: FSR 2/3 and A-SVGF.
  - Arc users get no XeSS.
  - Frame generation (DLSS-FG or FSR3-FG) works only on Windows through DXGI/D3D12 interop. On Linux, RTGL1 gives path tracing plus FSR2/3 or DLSS-SR at best.
- **Maintenance risk is high.** There has been no upstream activity for over two years. Commits such as "Strange fix for new drivers" (2023-06-23) point to drift with new drivers and the Vulkan SDK.
  - Plan to vendor it, own it, and fix Linux and modern-driver issues yourself.
  - Treat its denoiser and upscaler as replaceable by NRD, DLSS-RR or FSR 3.1 later if it proves itself.

### Gaps
- I found no measured fps for any RTGL1 game on specific GPUs (the PCGH Half-Life RT charts are images).
- I found no reports of RTGL1 behaviour on Intel Arc.
- I did not verify whether `vs-shirokii/RTGL` (with its D3D12 interop additions) still builds on Linux. The upstream `hl1` branch has the 2023-11 Linux fixes.

## 3. NVIDIA RTX Kit components and their cross-vendor status

### Takeaway
- **Cross-vendor and usable on Linux:**
  - RTXDI: ReSTIR DI, GI and, since v3.0 (2026-03), ReSTIR PT. D3D12 or Vulkan; Linux build.
  - NRD: ReBLUR, ReLAX and SIGMA compute denoisers. D3D11/12/Vulkan; Windows and Linux scripts.
  - SHARC: shader-only, any DXR GPU.
- **Cross-vendor tool, NVIDIA-only runtime:** the OMM SDK baker is cross-vendor, but OMM itself runs only on NVIDIA under DXR 1.2 and on no Mesa driver.
- **NVIDIA-only:**
  - DLSS SR/RR/FG (Linux libraries do exist).
  - NRC (Tensor Cores plus CUDA; Windows binaries only).
  - RTX Mega Geometry (`NV_` extensions).
- **RTXPT** is a Windows-only reference sample with known AMD/Vulkan issues.

### Cited Findings
- **RTX Kit 2026.3** (2026-09-09) bundles DLSS 310.9.1 (RR Transformer Preset F), NRD 4.17.3, OMM 1.9.2, RTXDI 3.1.0 ("Adds DLSS RR… ReSTIR PT improvements"), RTXMG 2.0.0 (Cluster LOD) and Streamline 2.14.1 — [RTX-Kit releases](https://github.com/NVIDIA-RTX/RTX-Kit/releases).
  - 2026.2 (2026-03-11) had RTXDI 3.0 ("Added ReSTIR PT algorithm"), RTXPT 1.8.1 and RTXGI 2.7.
  - Kit baseline: Windows 10 20H1+, a "DXR 1.1… capable GPU", driver 572.16+ and Vulkan SDK 1.3.296+.
  - The kit notes that repo URLs changed (NVIDIAGameWorks moved to NVIDIA-RTX) — [RTX-Kit](https://github.com/NVIDIA-RTX/RTX-Kit).
  - *Superseded:* old `NVIDIAGameWorks/RayTracingDenoiser`, `nvrhi` and `donut` URLs now redirect to `NVIDIA-RTX`.
- **RTXPT v1.8.1** (2026-03-05) — [RTXPT](https://github.com/NVIDIA-RTX/RTXPT) (GH):
  - **Features:**
    - DX12 and Vulkan back-ends; reference and real-time modes; NEE with "temporally adaptive guided importance sampling".
    - RTXDI ReSTIR DI/GI; NRD ReLAX and ReBLUR "with up to 3-layer path space decomposition"; OMM; SER.
    - Streamline DLSS (RR/SR/AA/FG/MFG).
  - **1.8.x changes:** 25–30% faster than 1.7.x; new presets "for better scaling from low end to high end GPUs"; DXR 1.2 SER/OMM via Agility SDK 1.619.
  - **Requirements:** Windows 10, a DXR 1.1 GPU and driver 595.71+.
  - **Known issues:**
    - "only Windows builds are fully supported. We are going to add Linux support in the future."
    - Vulkan needs manual steps.
    - "SER and OMM support on Vulkan is currently work in progress."
    - "Running Vulkan on AMD GPUs may trigger a TDR during TLAS building in scenes with null TLAS instances."
    - Black or incorrect transparencies "on some AMD systems with latest drivers".
- **RTXDI** — [RTXDI releases](https://github.com/NVIDIA-RTX/RTXDI/releases), [README](https://github.com/NVIDIA-RTX/RTXDI):
  - v3.0.0 (2026-03-10) added ReSTIR PT resampling functions and Full Sample integration, shader debug print and reservoir visualisers.
  - v3.1.0 (2026-09-03) added DLSS-RR to the sample, PT "stagnancy-driven decorrelation" for DLSS-RR, and compatibility-guided spatial neighbour selection. Identifiers were renamed, which is a breaking change.
  - The samples run on D3D12 or Vulkan through NVRHI with DXC to SPIR-V, and the README has Linux build steps.
- **NRD** v4.17.3 (2026-04-30; repo pushed 2026-10-06) — [NRD](https://github.com/NVIDIA-RTX/NRD) (GH):
  - "can be integrated into any D3D12, Vulkan or D3D11 engine". Build scripts exist for `Windows` and `Linux`.
  - Timings on an RTX 4080 at native 1440p:
    - `REBLUR_DIFFUSE_SPECULAR`: 2.55 ms (3.40 ms in SH mode)
    - `RELAX_DIFFUSE_SPECULAR`: 3.25 ms (4.80 ms in SH mode)
    - `SIGMA_SHADOW`: 0.40 ms
- **SHARC** v1.6.5.0 (2026-02-28) — [SHARC](https://github.com/NVIDIA-RTX/SHARC), [RTXGI README](https://github.com/NVIDIA-RTX/RTXGI), [SharcGuide](https://github.com/NVIDIA-RTX/RTXGI/blob/main/Docs/SharcGuide.md):
  - "a set of shader-only sources". RTXGI's requirements line reads "Any DXR GPU for SHaRC | NV GPUs ≥ Turing (arch 70) for NRC".
  - The update pass traces about 4% of paths: one random pixel per 5×5 block.
  - Memory is 40 bytes per voxel, so 2²² entries take 160 MiB.
- **NRC** v0.16.0.0 (2026-10-03, adds Windows ARM64) — [NRC](https://github.com/NVIDIA-RTX/NRC) (GH), [NrcGuide](https://github.com/NVIDIA-RTX/RTXGI/blob/main/Docs/NrcGuide.md):
  - Ships only `NRC_D3D12.dll`, `NRC_Vulkan.dll`, `cudart64_13.dll` and nvrtc DLLs for x64 and arm64. There are no Linux libraries.
  - The guide: "supports D3D12 and Vulkan rendering APIs while relying on Tensor Cores to train the neural network each frame".
- **RTXGI 2.7.0** (2026-03-01) hosts the NRC and SHARC samples (DX12 and Vulkan) and adds DLSS-RR — [Changelog](https://github.com/NVIDIA-RTX/RTXGI/blob/main/Changelog.md).
  - *Superseded:* DDGI (RTXGI 1.x) now lives at [`NVIDIAGameWorks/RTXGI-DDGI`](https://github.com/NVIDIAGameWorks/RTXGI-DDGI), last pushed 2024-02-05.
- **RTX Mega Geometry** v2.1.0 (2026-10-06) — [RTXMG](https://github.com/NVIDIA-RTX/RTXMG) (GH):
  - Builds cluster BVHs "using NVAPI for DX12, and the VK_NV_cluster_acceleration_structure extension for Vulkan".
  - Requires an "NVIDIA RTX GPU (10 GB VRAM or greater)" and DXR 1.1+. Builds are Windows-only.
  - v2.0.0 (2026-08-28) added Cluster LOD streaming.
- **OMM SDK** v1.9.2 (2026-06-23) — [OMM](https://github.com/NVIDIA-RTX/OMM) (GH):
  - Converts alpha-tested assets to OMMs, with a GPU baker (D3D12/VK) and a CPU baker. It has supported DXR 1.2 officially since 1.8.0.
  - Vulkan support is through `VK_EXT_opacity_micromap`. Ada has "2x Faster Alpha Traversal".
  - Runtime support: see section 1 (NVIDIA-only in DXR 1.2; no Mesa driver).
- **DLSS SDK** — [DLSS](https://github.com/NVIDIA/DLSS) (GH):
  - 310.9.1 (2026-09-08) added "DLSS Ray Reconstruction Transformer Mode (Preset F)". 310.6.0 (2026-04-21) added FG 5x/6x.
  - `lib/Linux_x86_64` and `lib/Linux_aarch64` contain `libnvidia-ngx-dlss.so` (SR), `-dlssd.so` (RR) and `-dlssg.so` (FG).
- **DLSS-RR guide** (August 2026): DLSS runs on "both Windows and Linux" on any "NVIDIA RTX GPU". Driver ≥ 580 is needed for DLSS 4.5+ RR — [DLSS-RR Integration Guide](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS-RR%20Integration%20Guide.pdf).
- **DLSS-FG guide**: FG needs RTX 40-series or newer; Multi-Frame Generation needs RTX 50-series — [DLSS-FG Programming Guide](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS-FG%20Programming%20Guide.pdf).
- **Streamline** 2.14.1 (2026-09-08) — [Streamline](https://github.com/NVIDIA-RTX/Streamline) (GH):
  - Adds `VK_NV_low_latency2` support and V-Sync/limiters for Dynamic MFG.
  - Plugins in the tree: `sl.common`, `sl.deepdvc`, `sl.directsr`, `sl.dlss`, `sl.dlss_d`, `sl.imgui`, `sl.nis`, `sl.pcl`, `sl.reflex`, `sl.template`. DLSS-G ships prebuilt only.
  - The build is Windows-only and needs a GPU with "DirectX 11 and Vulkan 1.2".
- **Falcor 9.0** (2026-09-21) added "ReSTIR PT Enhanced and Area ReSTIR" to its PathTracer, plus NRD-compatible guide outputs and SM 6.8/6.9; Slang 2025.13.2 — [Falcor 9.0](https://github.com/NVIDIAGameWorks/Falcor/releases/tag/9.0).
- **`nvpro-samples/vk_gltf_renderer`** is a Vulkan RT glTF path tracer with DLSS and OptiX denoising (pushed 2026-10-06) — [GH](https://github.com/nvpro-samples/vk_gltf_renderer).

### Inferences
- **Cross-vendor PT stack for YAE (Vulkan, Windows and Linux):** RTXDI (ReSTIR DI/GI, and PT later) for sampling, SHARC as the radiance cache, NRD for denoising, plus DLSS SR/RR as an NVIDIA-only add-on. All of these are HLSL or compute and port to SPIR-V through DXC.
- **Not for YAE's goals:** NRC (CUDA, Tensor Cores, Windows-only) and RTX Mega Geometry (NV extensions, and pointless for low-poly levels).
- **OMM** only speeds up alpha-tested geometry on NVIDIA RTX 40+. The any-hit fallback must stay as the cross-vendor path.
- **RTXPT** is a reference to read (and to borrow its NEE-AT and layered NRD setup from), not a library to depend on for Linux or AMD.

### Gaps
- No published NRD, RTXDI or SHARC timings for RTX 3060 Ti-class, AMD or Intel GPUs.
- I did not verify NVIDIA Linux driver support for `VK_EXT_opacity_micromap` and SER.

## 4. AMD FSR SDK 2.x / FSR 4 / FSR "Redstone"; Brixelizer GI and Hybrid Reflections

### Takeaway
As of FSR SDK 2.3.0 (2026-06-24), every ML component ships only as signed D3D12 DLLs for Windows:
- FSR 4.1 upscaling
- ML frame generation 4.0
- Ray Regeneration 1.2
- Radiance Caching (preview)

FSR 4 upscaling now officially covers RX 7000 (an INT8 model, from July 2026) as well as RX 9000; RX 6000 is planned for early 2027. FG4 and Ray Regeneration need RX 9000 and Windows 11. For Vulkan or Linux, AMD's option is still the open-source FSR 3.1 in SDK 1.1.4, which has a Vulkan backend and works on any vendor. The cheaper GI options, Brixelizer GI and Hybrid Reflections, are frozen in SDK 1.1.4.

### Cited Findings
- **Release history** — [FidelityFX-SDK releases](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/releases):
  - v2.0.0 (2025-08-20): public FSR 4.0.2.
  - v2.1.0 (2025-12-10): "Redstone" — FSR Frame Generation 4.0.0 (ML), Ray Regeneration 1.0.0 and Radiance Caching (Preview), plus FSR Upscaling 4.0.3 and FG 3.1.6.
  - v2.1.1 (2026-02-23): the SDK is renamed "AMD FSR SDK".
  - v2.2.0 (2026-03-23): FSR Upscaling 4.1.0 and Ray Regeneration 1.1.0, with breaking API changes.
  - v2.3.0 (2026-06-24): Ray Regeneration 1.2.0 (optional AO and specular-occlusion denoising, checkerboard input; more breaking changes) and FSR Upscaling 4.1.1.
- **D3D12 only:**
  - `Kits/FidelityFX/signedbin` contains only `amd_fidelityfx_{loader,upscaler,framegeneration,denoiser,radiancecache}_dx12.dll`.
  - The API doc says "Backend-specific functionality (currently only for DirectX 12)". The samples' only listed ecosystem is DirectX 12.
  - Sources: [tree](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/tree/main/Kits/FidelityFX/signedbin), [ffx-api.md](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/Kits/FidelityFX/docs/getting-started/ffx-api.md), [getting-started](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/Kits/FidelityFX/docs/getting-started/index.md) (GH)
- **FSR 4 upscaler**
  - Limitation: "FSR4 requires an AMD 7000 series discrete GPU or AMD 9000 series GPU or later" — [super-resolution-ml.md](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/Kits/FidelityFX/docs/techniques/super-resolution-ml.md).
  - Performance mode, RCAS off:

    | GPU | Target resolution | Cost |
    | --- | --- | --- |
    | RX 9070 XT | 1080p | 0.352 ms |
    | RX 9070 XT | 4K | 1.316 ms |
    | RX 7600 | 1080p | 1.998 ms |
    | RX 7800 XT | 1440p | 2.050 ms |
    | RX 7900 XTX | 4K | 3.070 ms |

  - FSR4 "no longer requires" reactive or transparency masks.
  - *Superseded:* in 2025 FSR 4 was RDNA4-only. Official FSR 4.1 for RX 7000 shipped in Adrenalin 26.6.2 with an INT8 model, because RDNA3 has no FP8; it is "available natively in over 300 games". RDNA3 APUs come next and RX 6000 is planned for early 2027 — [Tom's Hardware](https://www.tomshardware.com/pc-components/gpu-drivers/amd-brings-official-fsr-4-1-support-to-rx-7000-series-gpus-int8-model-now-available-in-300-games-rdna-3-apus-also-getting-fsr-4-1-soon) (snippet), [Hardware Busters, 2026-07-07](https://hwbusters.com/news/amd-brings-fsr-4-1-to-the-radeon-rx-7000-series-rdna-3-finally-gets-the-good-upscaler/).
- **Ray Regeneration** (ML denoiser, decoupled from upscaling) — [denoising.md](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/Kits/FidelityFX/docs/techniques/denoising.md):
  - Requirements: "an AMD Radeon RX 9000 Series GPU or later", "DirectX 12 + Shader Model 6.6" and "Windows 11".
  - Timings on an RX 9070 XT at 960×540 / 1080p / 1440p:

    | Signals denoised | 960×540 | 1080p | 1440p |
    | --- | --- | --- | --- |
    | Four (direct and indirect, diffuse and specular) | 1.10 ms | 4.26 ms | 8.10 ms |
    | Indirect diffuse and indirect specular | 0.87 ms | 3.37 ms | 6.52 ms |
    | Indirect specular only | 0.71 ms | 2.63 ms | 5.34 ms |

- **FSR Frame Generation 4 (ML)**: "requires Windows 11, DirectX 12 Agility SDK 1.4.9 and an AMD 9000 series GPU or later". It costs 2.2 ms at 4K on an RX 9070 XT and 2.1 ms at 1440p on an RX 9060 XT — [frame-interpolation-ml.md](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/Kits/FidelityFX/docs/techniques/frame-interpolation-ml.md).
- **Radiance Cache (Preview 0.9.0, 2025-12-10)**: an online-trained network ("continuously learns from the samples emitted by the path tracer") written in HLSL CS_6_6, with inference and training dispatches and a default learning rate of 0.002 — [radiance-cache.md](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/Kits/FidelityFX/docs/techniques/radiance-cache.md).
  - Press at launch called it RDNA4-exclusive and not in games until 2026 — [HowToGeek](https://www.howtogeek.com/amd-fsr-redstone-looks-promising-but-you-probably-cant-use-it/), [TechSpot](https://www.techspot.com/article/3072-amd-fsr-redstone/).
  - Adoption in December 2025: only Call of Duty: Black Ops 7 used Ray Regeneration, and only in limited form (snippet, likely out of date by now).
- **Vulkan workarounds**: AMD has no native Vulkan path. OptiScaler 0.9.0-pre10 brings FSR 4 to Vulkan games through a DX12 bridge. igor'sLAB reports no AMD statement or timeline for official Vulkan support (2026-02-25) — [igor'sLAB](https://www.igorslab.de/en/optiscaler-activates-fsr-4-under-vulcan-before-amd-itself-delivers/).
  - Bevy Solari's author notes the FSR ML denoiser is unavailable on Vulkan (2025-12-27) — [jms55](https://jms55.github.io/posts/2025-12-27-solari-bevy-0-18).
- **SDK 1.1.4 (2025-05-08)**, the last open-source multi-API SDK — [v1.1.4](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/releases/tag/v1.1.4), [vk backend](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/tree/v1.1.4/sdk/src/backends/vk):
  - FSR 3.1.4 upscaler and FG, including "General fixes to Vulkan Frame Interpolation Swapchain", and Brixelizer GI 1.0.1. Prerequisites include Vulkan SDK 1.3.250.
  - Its Vulkan backend has shader sets for FSR3Upscaler, Frameinterpolation, Brixelizer, BrixelizerGI, Denoiser, Classifier, SSSR and others.
  - SDK 2.2.0 notes: "All SDK version 1 effects are now deprecated to that version of the SDK" — [v2.2.0](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/releases/tag/v2.2.0).
- **Brixelizer GI** needs only HLSL `CS_6_6`: it is compute and SDF-based and does not need RT hardware. It has an internal resolution with upscaling to display size — [brixelizer-gi.md](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/v1.1.4/docs/techniques/brixelizer-gi.md).
  - A Godot proposal to adopt it in the Vulkan renderer was closed on 2024-07-11 — [godot-proposals #10176](https://github.com/godotengine/godot-proposals/issues/10176).
- **Hybrid Reflections** sample (SDK 1.1.4): Classifier tile lists, an SPD depth hierarchy, the FidelityFX Denoiser and RT reflection rays above a roughness threshold — [hybrid-reflections.md](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/v1.1.4/docs/samples/hybrid-reflections.md).
- **AMD Capsaicin** v1.3 (2025-11-20, MIT) implements GI-1.2 (diffuse plus specular indirect, built on the GI-1.0 two-level radiance cache) and includes a reference path tracer. It requires "Direct3D12 Ultimate capable hardware" on Windows — [Capsaicin](https://github.com/GPUOpen-LibrariesAndSDKs/Capsaicin) (GH).

### Inferences
- **What AMD users get in a Vulkan or Linux YAE (October 2026):**
  - Path tracing on RDNA2 and newer.
  - FSR 3.1 (or XeSS-SR on Windows) for upscaling.
  - NRD or an in-house SVGF for denoising.
  - No ML denoiser and no FSR 4.
- RDNA4 owners get Redstone only if YAE grows a D3D12 backend on Windows.
- **Brixelizer GI (Vulkan, compute-only) is the most practical AMD-sourced fallback for GI without RT hardware.** It is frozen code, so treat it as a vendored snapshot. YAE's targets (RTX 20+, RDNA2+, Arc) all have RT hardware, so it matters mainly for iGPUs, older GPUs, or as a cheap "medium" GI preset.

### Gaps
- I found no AMD statement on Vulkan or Linux support for FSR 4/Redstone.
- The current FSR 3.1 documentation gives no per-GPU timings.
- The Radiance Cache document gives no hardware requirement.
- The exact driver date for FSR 4.1 on RDNA3 is "Adrenalin 26.6.2 / July 2026", from press reports only.

## 5. Intel XeSS 2/3 (SR, FG, Low Latency) and Intel denoisers or path tracing samples

### Takeaway
XeSS-SR is the only Intel component with a Vulkan path. It ships as a Windows DLL and runs on other vendors' GPUs through SM 6.4/DP4a (D3D12) or specific Vulkan features. XeSS-FG/MFG and XeLL are DX12-only on Windows:
- Cross-vendor FG is limited to one generated frame.
- 3x/4x MFG is Arc-only (XeSS 3.0, 2026-03-09).

There are no Linux binaries. Intel has no real-time path tracing denoiser SDK. Open Image Denoise is a cross-vendor GPU denoiser for offline or interactive use, which suits lightmap baking.

### Cited Findings
- **XeSS releases** — [intel/xess releases](https://github.com/intel/xess/releases):
  - 3.0.0 (2026-03-09): "3x and 4x Multi-Frame Generation for Intel Arc GPUs", "Improved frame generation models… on all supported GPUs", and external memory heaps.
  - 3.0.1 (2026-04-17): FG stability.
  - 3.0.2 (2026-07-24): XeLL 1.3.2.10, fixing a memory leak on non-Intel GPUs and unwrapping Streamline proxies.
  - 2.1.1 (2025-11-13): fixed "rare crashes on Vulkan" in XeSS-SR and an AMD validation error.
- **XeSS-FG requirements**: "DirectX 12", with either an Intel Arc GPU (Alchemist or Battlemage, driver ≥ 32.0.101.7029) "or any non-Intel GPU supporting Shader Model 6.4". "On non-Intel GPUs the maximum number of generated frames is one." Pacing is done by the Intel driver on Intel GPUs and by the library elsewhere — [FG guide](https://github.com/intel/xess/blob/main/doc/xess_fg_developer_guide_english.md).
- **XeSS-SR requirements** — [SR guide](https://github.com/intel/xess/blob/main/doc/xess_sr_developer_guide_english.md):
  - Windows 10/11.
  - DX12: Iris Xe or newer, or another vendor's GPU with "SM 6.4 and with hardware acceleration for DP4a".
  - DX11: Arc only.
  - Vulkan 1.1: Iris Xe or newer, or another vendor's GPU with `shaderStorageImageWriteWithoutFormat` and `mutableDescriptorType`.
  - Uses a cross-vendor HLSL implementation; `libxess.dll` serves both D3D12 and Vulkan.
- The repo's `bin/` holds only `libxess.dll`, `libxess_dx11.dll`, `libxess_fg.dll` and `libxell.dll`. There is no `.so` — [intel/xess](https://github.com/intel/xess/tree/main/bin) (GH).
- *History:* XeSS 2.1 (2025) opened FG plus XeLL to non-Intel GPUs with SM 6.4 (GTX 10+ and RX 5000+). Standalone XeLL stays Intel-only — [Tom's Hardware](https://www.tomshardware.com/pc-components/gpus/xess-sdk-2-1-release-opens-up-intels-framegen-tech-to-compatible-amd-and-nvidia-gpus-xe-low-latency-also-goes-cross-platform-if-framegen-is-enabled), [Phoronix](https://www.phoronix.com/news/Intel-XeSS-2.1-Released).
  - Tom's Hardware notes Intel still had not delivered its promised open-sourcing of XeSS at the 3.0 launch — [Tom's Hardware](https://www.tomshardware.com/pc-components/gpu-drivers/intel-shares-xess-3-0-sdk-for-game-devs-with-3x-and-4x-mfg-modes-but-it-still-hasnt-followed-through-on-its-open-source-promise).
- **Open Image Denoise** v2.5.1 (2026-08-18, Apache-2.0) — [OIDN](https://github.com/RenderKit/oidn) (GH):
  - GPU support covers Intel Xe/Xe2/Xe3, NVIDIA Turing through Blackwell, AMD RDNA2 through RDNA4, and Apple silicon.
  - The README positions it for offline rendering and, depending on hardware, "interactive or even real-time ray tracing".

### Inferences
- **Arc users on a Vulkan YAE:**
  - Windows: XeSS-SR, or FSR 3.1.
  - Linux: only FSR 3.1 or an in-house TAAU. XeSS has no Linux binaries.
  - Battlemage supports and actually performs SER under DXR 1.2, but its Vulkan SER status is unverified.
- **OIDN** is a strong cross-vendor choice for denoising lightmap bakes. That is relevant to upgrading YAE's lightmapped content, even though it is not part of a real-time path tracing loop.

### Gaps
- I found no Intel real-time path tracing sample or denoiser SDK for games. I did not survey the GameTechDev org in depth.
- I found no XeSS-SR timings on Vulkan or on non-Intel GPUs.

## 6. Cross-vendor abstraction for upscalers, denoisers and frame generation, and what works on Linux Vulkan

### Takeaway
No vendor-neutral runtime abstraction covers Vulkan on Linux:
- **Streamline** is Windows-only and ships NVIDIA plugins plus a DirectSR plugin.
- **AMD's FSR API** is D3D12-only in SDK 2.x.
- **DirectSR** is D3D12-only.
- **OptiScaler** is a GPL-3.0 injection tool for already-shipped games.

What works under native Vulkan on Linux in October 2026:
- **NVIDIA DLSS:** SR, RR and FG through NGX `.so`s on the proprietary driver; NVK support is experimental.
- **FSR 3.1:** open source, any vendor.
- **NRD.**

Not available on Linux: FSR 4 and Redstone, XeSS, and any ML denoiser for AMD or Intel.

### Cited Findings
- **Streamline** has a Windows build, NVIDIA plugins (`sl.dlss`, `sl.dlss_d`, prebuilt DLSS-G, `sl.reflex`, `sl.pcl`, `sl.nis`, `sl.deepdvc`) and an `sl.directsr` plugin. There is no FSR or XeSS plugin in the tree — [Streamline](https://github.com/NVIDIA-RTX/Streamline) (GH).
  - XeSS 3.0.2 added "Better Streamline compatibility": XeLL unwraps Streamline proxies. This is about Streamline-wrapped D3D12 devices, not a Streamline plugin — [intel/xess releases](https://github.com/intel/xess/releases).
- **DLSS on Linux:**
  - The NGX SDK documents Linux builds ("glibc 2.11 or newer"; link `libsdk_nvngx.a`, `libstdc++.so` and `libdl.so`; release library `libnvidia-ngx-dlssg.so.<ver>`).
  - **Conflict:** the same DLSS-FG guide's "System Requirements" list only "Windows 10 20H1… or higher" — [DLSS-FG guide](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS-FG%20Programming%20Guide.pdf).
  - The DLSS-RR guide covers Windows and Linux explicitly — [DLSS-RR guide](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS-RR%20Integration%20Guide.pdf).
  - DLSS for Vulkan games under Proton has existed since 2021 — [vulkan.org](https://vulkan.org/news/auto-20094-ac2c75bc2e199e1a427d1877e6da50df), [NVIDIA blog](https://developer.nvidia.com/blog/nvidia-dlss-sdk-now-available-for-all-developers-with-linux-support-unreal-engine-5-plugin-and-new-customizable-options).
- **NVK and DLSS:** experimental DLSS support on NVK through `VK_NVX_binary_import` was merged into Mesa 26.2-devel (June 2026) and is enabled with `NVK_EXPERIMENTAL=dlss` — [GamingOnLinux](https://www.gamingonlinux.com/2026/06/the-open-source-nvidia-vulkan-driver-nvk-now-has-experimental-dlss-support/), [Phoronix](https://www.phoronix.com/news/Mesa-NVK-Vulkan-Does-DLSS).
  - NVK still exposes no Vulkan ray tracing extensions — [Mesa features.txt](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/docs/features.txt).
- **FSR 4 on Vulkan or Linux** is available only through community bridges (OptiScaler's DX12 interop) or in D3D12 games — [igor'sLAB](https://www.igorslab.de/en/optiscaler-activates-fsr-4-under-vulcan-before-amd-itself-delivers/).
- **XeSS** ships Windows DLLs only; XeSS-FG is DX12-only — [intel/xess](https://github.com/intel/xess), [FG guide](https://github.com/intel/xess/blob/main/doc/xess_fg_developer_guide_english.md).
- **OptiScaler** v0.9.4 (2026-07-18, GPL-3.0) "bridges upscaling/frame gen across GPUs. Supports DLSS2+/XeSS/FSR2+ inputs, replaces native upscalers, enables FSR-FG/XeFG on non-FG titles" — [OptiScaler](https://github.com/optiscaler/OptiScaler) (GH).
- **Inputs differ between upscalers:**
  - FSR 3.1 wants reactive and transparency masks and `frameTimeDelta` in ms — [FSR 3.1 doc](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/v1.1.4/docs/techniques/super-resolution-upscaler.md).
  - FSR 4 "no longer requires" the masks — [FSR 4 doc](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/Kits/FidelityFX/docs/techniques/super-resolution-ml.md).
  - DLSS-RR relies on guide buffers. Capcom used them heavily to fix SSS, glass, raindrop and projected-texture artifacts — [wccftech](https://wccftech.com/re-engine-path-tracing-ser-restir-gi-dlss-rr/).
- **Frame generation pacing:** with direct NGX integration the engine presents and paces the generated frames itself — [DLSS-FG guide](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS-FG%20Programming%20Guide.pdf). Mesa exposes `VK_EXT_present_timing` on anv, nvk and radv — [Mesa features.txt](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/docs/features.txt).

### Inferences
- **Build an engine-side "temporal reconstruction" interface** with a superset of inputs:
  - colour, depth, jitter, exposure, frame time
  - motion vectors, including specular motion vectors
  - normals, roughness, diffuse and specular albedo, hit distance
  - reactive and transparency masks
- **Backends for that interface:**
  - DLSS SR/RR/FG through direct NGX, not Streamline, which keeps Linux.
  - FSR 3.1 vendored from SDK 1.1.4 source.
  - XeSS-SR on Windows.
  - NRD for vendor-neutral denoising.
  - A D3D12 path for FSR 4/Redstone or XeSS-FG later, if wanted.
- **On Linux, frame generation for everyone** can only come from DLSS-FG (RTX 40+), FSR 3.1 FG (open source, with its Vulkan frame-interpolation swapchain), or an in-house solution. All of them need Vulkan to own presentation.

### Gaps
- I could not verify DirectSR's adoption or status in 2026.
- I found no shipped native-Linux game using DLSS-FG through NGX, so practical driver support for FG on Linux is unconfirmed beyond the presence of the `.so`.

## 7. Real-world cost by GPU generation and realistic budgets; hybrid versus full path tracing; DDGI fallback

### Takeaway
- **AAA path tracing does not fit the mid-range target.** It is out of reach for 8 GB RTX 3060 Ti-class cards because of both VRAM and throughput. RDNA4 trails comparable NVIDIA cards badly: below 30 fps where the RTX 5070 makes 36 in Doom's path tracing. Arc B580 lands near the RTX 4060.
- **Small scenes are a different regime.** Measured component costs:
  - DLSS-RR alone: 3.5–5.9 ms at 1080p output on RTX 3070/3060.
  - DLSS-SR: 0.4–1.5 ms on the same cards.
  - NRD ReBLUR: about 2.6 ms on an RTX 4080 at native 1440p.
  - Bevy Solari's ReSTIR DI/GI plus world cache: about 1.2–2 ms on an RTX 3080 at 900p internal for small scenes, excluding the DLSS-RR pass.
- **Verdict for a 3060 Ti:** a ReSTIR-based pipeline is plausible at 1080p60 and marginal at 1440p60.
- **Hybrid versus full PT:** hybrid RT GI scales across vendors far better than full path tracing.

### Cited Findings
**Game benchmarks**
- Intel Arc B580, Cyberpunk 2077 path tracing at 1080p:

  | Setting | fps |
  | --- | --- |
  | Native | 10 |
  | XeSS Quality | 26 (1% low 15) |
  | XeSS Performance | 38 |
  | XeSS Performance + frame generation | 60 |
  | RT Ultra (not path tracing), native | 38 |

  The card was described as "roughly comparable with GeForce RTX 4060" in RT — DSOGaming via [iChip, 2024-12-26](https://ichip.ru/novosti/ekspert-protestiroval-videokartu-intel-arc-b580-v-cyberpunk-2077-v-rezhimah-rt-ultra-i-path-tracing-897922).
- Doom: The Dark Ages with path tracing (update 2025-06-18) at 1080p — [PCGamesN, 2025-06-28](https://www.pcgamesn.com/doom-the-dark-ages/nvidia-amd-path-tracing-benchmarks):

  | GPU | Native | DLSS/FSR Quality |
  | --- | --- | --- |
  | RTX 5080 | 55 fps | 90 fps (1% low 74) |
  | RTX 4080 | 44 fps | — |
  | RTX 5070 | 36 fps | about 60 fps |
  | RX 9070 / 9070 XT | below 30 fps | "significantly lower" |

  With frame generation, the AMD 1% lows stayed under 50 fps.
- Doom without path tracing, 1080p Ultra Nightmare (always-on RT GI): RX 9070 XT 128.5 fps against RTX 5070 97.7 fps (TechPowerUp data via [Notebookcheck](https://www.notebookcheck.net/Doom-The-Dark-Ages-benchmark-shows-RX-9070-XT-matches-RTX-5080-as-AMD-takes-lead.1015027.0.html)).
- VRAM for Doom path tracing:
  - PCGH, 2026-07-07: "8 GiByte of VRAM just won't cut it here — we recommend 16 GiByte". PCGH tested 33 GPUs with and without path tracing — [PCGH](https://www.pcgameshardware.de/Doom-The-Dark-Ages-Spiel-74718/Specials/Best-CPU-and-GPU-for-the-Revelations-DLC-1547462/2/).
  - The RTX 3060 Ti is "short by three or four GBs" with path tracing at 1080p — [PC Gamer](https://www.pcgamer.com/hardware/graphics-cards/doom-the-dark-ages-gets-path-tracing-for-even-better-graphics-but-unless-youve-got-an-rtx-50-graphics-card-its-not-worth-using/) (snippet).
- PCGH (2025-06-04): path tracing on mid-range GPUs is at most a 1080p topic. It recommends the RTX 5060 Ti 16 GB as the entry card for playable path tracing. Indiana Jones gates path tracing by VRAM — [PCGH](https://www.pcgameshardware.de/Radeon-RX-9060-XT-16GB-Grafikkarte-281275/Tests/Release-Benchmark-Preis-Specs-1473547/5/).
- Capcom RE Engine (PRAGMATA scene, 73 analytic lights, 32 emissive samples) at 4K on an RTX 5090 — [wccftech, 2026-04-15](https://wccftech.com/re-engine-path-tracing-ser-restir-gi-dlss-rr/), [Capcom slides](https://www.docswell.com/s/CAPCOM_RandD/5DM2NL-gdc2026-implementing-real-time-path-tracing-in-re-engine):
  - Frame time went from 21 ms, to about 16.9 ms with SER plus bindless, to 13.3 ms after driver optimisations.
  - The team says path tracing is "effectively limited to NVIDIA GeForce RTX hardware" because it depends on DLSS-RR.
  - It runs on DX12 with DXR 1.2 and took about 1.5 years to build.

**Measured component costs (vendor documentation)**
- DLSS SR, Performance mode — [DLSS Programming Guide 310.6.0, 2026-03-31](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS_Programming_Guide_Release.pdf):

  | GPU | E/F (CNN) | J/K | L | M |
  | --- | --- | --- | --- | --- |
  | RTX 3060 @1080p | 0.60 ms | 1.45 ms | 3.96 ms | 2.81 ms |
  | RTX 3060 @1440p | 0.98 ms | 2.39 ms | 6.53 ms | 5.05 ms |
  | RTX 3070 @1080p | 0.43 ms | 0.93 ms | 2.43 ms | 1.74 ms |
  | RTX 3070 @1440p | 0.68 ms | 1.53 ms | 4.01 ms | 3.03 ms |
  | RTX 5070 @1080p | 0.27 ms | 0.64 ms | 1.17 ms | 0.75 ms |
  | RTX 5090 @1080p | 0.15 ms | 0.36 ms | 0.56 ms | 0.35 ms |

  - Presets L and M (added in 310.5.0, 2025-11-20) are "peak performant on RTX 40 series GPUs and above". Presets E and F are marked deprecated.
  - DLSS memory at 1080p is about 59–119 MB depending on preset.
- DLSS-RR, Performance mode, presets Default/F — [DLSS-RR guide, 2026-08](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS-RR%20Integration%20Guide.pdf):

  | GPU | 1080p | 1440p | 4K |
  | --- | --- | --- | --- |
  | RTX 2080 Ti | 4.39 ms | 7.20 ms | 16.37 ms |
  | RTX 3060 | 5.83 ms | 10.27 ms | 22.92 ms |
  | RTX 3070 | 3.52 ms | 6.21 ms | 13.63 ms |
  | RTX 4070 | 1.33 ms | 2.28 ms | 4.96 ms |
  | RTX 5070 | 1.59 ms | 2.72 ms | 5.84 ms |
  | RTX 5090 | 0.72 ms | 1.06 ms | 2.12 ms |

  RR memory at 1080p is about 154–163 MB.
- DLSS-FG — [DLSS-FG guide](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS-FG%20Programming%20Guide.pdf):

  | GPU | Mode | 1080p | 1440p | 4K |
  | --- | --- | --- | --- | --- |
  | RTX 4090 | 2x | 1.35 ms | 1.78 ms | 2.77 ms |
  | RTX 5080 | 2x | 1.45 ms | 2.04 ms | 2.84 ms |
  | RTX 5080 | 4x | 2.43 ms | 3.61 ms | 5.25 ms |
  | RTX 5090 | 2x | 1.07 ms | 1.46 ms | 1.72 ms |

- NRD on an RTX 4080 at native 1440p — [NRD](https://github.com/NVIDIA-RTX/NRD):
  - ReBLUR diffuse+specular: 2.55 ms
  - ReLAX diffuse+specular: 3.25 ms
  - SIGMA shadow: 0.40 ms
- AMD components (section 4): FSR 4 costs 0.35 ms (9070 XT) to 2.0 ms (RX 7600) at 1080p. Ray Regeneration costs 4.26 ms at 1080p on a 9070 XT — [FSR docs](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/Kits/FidelityFX/docs/techniques/denoising.md).
- Bevy Solari 0.18 on an RTX 3080, 1600×900 internal upscaled to 3200×1800 with DLSS-RR — [jms55, 2025-12-27](https://jms55.github.io/posts/2025-12-27-solari-bevy-0-18):

  | Scene | Total | Notes |
  | --- | --- | --- |
  | Cornell Box | 7.27 ms | DLSS-RR 6.07 ms |
  | PICA PICA | 7.96 ms | DLSS-RR 6.10 ms |
  | Dragons | 8.58 ms | DLSS-RR 6.08 ms |
  | Bistro | 14.06 ms | heaviest pass ReSTIR GI, 2.28 ms |

  - Pipeline: ReSTIR DI for the first bounce, ReSTIR GI for the second, then a world cache.
  - Limitations: NVIDIA-only in practice because of the denoiser; no alpha masks; no skinned meshes.
- Radiance cache costs:
  - SHARC traces about 4% of paths for its update pass and uses 160 MiB at 2²² entries — [SharcGuide](https://github.com/NVIDIA-RTX/RTXGI/blob/main/Docs/SharcGuide.md).
  - DDGI (RTXGI 1.x) is legacy, last pushed 2024-02-05 — [RTXGI-DDGI](https://github.com/NVIDIAGameWorks/RTXGI-DDGI).
  - Engines that still ship DDGI or Surfel GI: Wicked Engine — [features.txt](https://github.com/turanszkij/WickedEngine/blob/master/features.txt). The Forge 1.63 added "Advanced RTX GI middleware" — [The-Forge](https://github.com/ConfettiFX/The-Forge).

### Inferences
- **3060 Ti-class budget at 1080p60 (16.7 ms)**, my estimate:
  - G-buffer raster plus post: about 2–3 ms for YAE-scale content.
  - ReSTIR DI plus one-bounce ReSTIR GI plus a SHARC/world cache at 540–720p internal: about 2–4 ms. I scaled Bevy's RTX 3080 figures by roughly 1.5×, because the 3060 Ti has about 38 RT cores against the 3080's 68.
  - Then either DLSS-RR at about 4–5 ms (interpolating between the 3060 and 3070) or NRD at about 3–4 ms plus DLSS-SR at 0.5–1.2 ms.
  - Total: about 9–12 ms, which leaves headroom.
  - At 1440p, DLSS-RR alone costs about 7–8 ms on this class. Prefer NRD plus SR or FSR there, or cap 1440p at 30–40 fps.
- **Hybrid versus full PT for YAE:**
  - Keep raster primary visibility plus legacy lightmaps or RT direct lighting.
  - Add ReSTIR DI for many-light direct lighting and RT GI with a cache.
  - Make "full PT" (multi-bounce, specular chains) a high preset for RTX 40/50 and RDNA4.
- **AMD RDNA2/3 and Arc A-series:** lower internal resolution, one bounce, and SHARC/world cache termination.
- **VRAM** is not the blocker for YAE's small levels that it is for AAA path tracing. BLAS/TLAS plus PBR textures for low-poly levels should stay well under 8 GB, but upgraded 4K PBR textures could change that, so budget them.
- **Fallbacks for weak GPUs:**
  - Lightmaps (existing) plus RT shadows and AO.
  - Brixelizer GI or DDGI-style probes as a mid tier. DDGI's NVIDIA SDK is legacy, but the technique is simple to own.

### Gaps
- I found no extractable path tracing fps for RTX 3060 Ti, RTX 4060 or RX 7800 XT in Cyberpunk, Alan Wake 2 or Indiana Jones (PCGH and TechPowerUp publish charts as images).
- I found no fps-by-GPU data for small-scene path tracers (Quake II RTX, Half-Life RT, Portal RTX), although PCGH tests them.
- FSR 3.1 and XeSS-SR timings, and NRD timings on mid-range or AMD GPUs, are not published in current documentation.
- An unattributed search snippet said an RTX 4090 drops from 115 to 58 fps at 1080p in Doom when path tracing is on. I could not tie it to a source, so it is excluded.

## 8. Reference open-source engines, samples and production talks

### Takeaway
- **Most useful live references for a Vulkan, cross-vendor, small-scene path tracer:**
  - Bevy Solari (ReSTIR DI/GI plus world cache on wgpu/Vulkan; detailed blog posts).
  - RTXDI 3.x (ReSTIR DI/GI/PT).
  - NRD.
  - nvpro's Vulkan path tracer samples.
  - Wicked Engine (C++, Vulkan on Linux: path tracer, RT effects, DDGI and Surfel GI).
- **References to read, not to adopt:** Falcor 9.0 and RTXPT 1.8.
- **Archived:** Quake II RTX and kajiya.
- **No production path tracer yet:** Godot (only experimental RT plumbing) and O3DE (RT infrastructure for GI only).
- **Production talks** converge on ReSTIR plus a radiance cache plus SER, OMM and DLSS-RR, and studios report 0.5 to 1.5 years of integration work.

### Cited Findings
- **NVIDIA and research references:**
  - Falcor 9.0 (2026-09-21): ReSTIR PT Enhanced, Area ReSTIR — [Falcor](https://github.com/NVIDIAGameWorks/Falcor/releases/tag/9.0)
  - RTXPT 1.8.1, Windows-only — [RTXPT](https://github.com/NVIDIA-RTX/RTXPT)
  - Donut (MIT, pushed 2026-10-05) — [Donut](https://github.com/NVIDIA-RTX/Donut)
  - RTXDI 3.1.0 — [RTXDI](https://github.com/NVIDIA-RTX/RTXDI)
  - nvpro `vk_raytracing_tutorial_KHR` (pushed 2026-09-20) and `vk_gltf_renderer` (pushed 2026-10-06) — [tutorial](https://github.com/nvpro-samples/vk_raytracing_tutorial_KHR), [renderer](https://github.com/nvpro-samples/vk_gltf_renderer) (GH)
- **Archived projects:**
  - Quake II RTX's "final official release" is v1.8.1 (2025-12-11). The repo is archived — [Q2RTX](https://github.com/NVIDIA/Q2RTX/releases/tag/v1.8.1).
  - kajiya (Embark, Apache-2.0) is archived; last push 2025-07-07 — [kajiya](https://github.com/EmbarkStudios/kajiya) (GH).
- **Bevy Solari:**
  - Introduced in 0.17 (September 2025) with ReSTIR DI, ReSTIR GI, a world-space irradiance cache, and DLSS-RR for denoising — [Bevy 0.17](https://bevy.org/news/bevy-0-17/).
  - 0.18 (December 2025) added specular and glossy handling — [jms55](https://jms55.github.io/posts/2025-12-27-solari-bevy-0-18).
  - 0.19 brought improvements for mirrors and non-metals, performance and temporal stability — [Bevy 0.19](https://bevy.org/news/bevy-0-19/).
  - 0.20.0-rc.2 was released on 2026-09-28 (GH). Apache-2.0.
- **Wicked Engine** v0.72.120 (2026-10-02, MIT):
  - Features: "Ray tracing, path tracing (on GPU)", "Lightmap baking (with GPU path tracing)", "Real time ray tracing: ambient occlusion, shadows, reflections (DXR and Vulkan raytracing)", "Surfel GI", "DDGI", SSGI.
  - Default renderer is Vulkan on Linux and DX12 on Windows.
  - Sources: [features.txt](https://github.com/turanszkij/WickedEngine/blob/master/features.txt), [README](https://github.com/turanszkij/WickedEngine) (GH)
- **Godot:** experimental Vulkan RT plumbing in 4.7 (merged 2026-01-27); an SDFGI-to-HDDAGI upgrade PR is open — [PR #99119](https://github.com/godotengine/godot/pull/99119), [PR #119869](https://github.com/godotengine/godot/pull/119869).
- **O3DE** 2605.0 (2026-05-27): Atom contains a `RayTracingFeatureProcessor` — [O3DE source](https://github.com/o3de/o3de/blob/development/Gems/Atom/Feature/Common/Code/Source/RayTracing/RayTracingFeatureProcessor.h) (GH).
- **Diligent** RT and path tracing tutorials — [DiligentSamples](https://github.com/DiligentGraphics/DiligentSamples).
- **AMD Capsaicin** (GI-1.2, D3D12) — [Capsaicin](https://github.com/GPUOpen-LibrariesAndSDKs/Capsaicin).
- **GDC 2024**, "Making Connections: Real-Time Path-Traced Light Transport in Game Engines" (Evan Hart and Adam Marrs, NVIDIA): ReSTIR-derived path traced lighting in UE5 — [GDC Vault](https://gdcvault.com/play/1034648/Advanced-Graphics-Summit-Making-Connections).
- **GDC 2024**, "Alan Wake 2: A Deep Dive into Path Tracing Technology" (Kiya Kandar of Remedy and Juha Sjöholm of NVIDIA). It covered acceleration-structure management with lots of dynamic content, material data, light sampling, OMM, SER, DLSS RR and FG — [GDC schedule](https://schedule.gdconf.com/session/alan-wake-2-a-deep-dive-into-path-tracing-technology-presented-by-nvidia/903204), [NVIDIA On-Demand](https://www.nvidia.cn/on-demand/session/gdc24-gdc1003).
- **Doom: The Dark Ages**: NVIDIA's developer blog (2025-09-30) covers OMM, SER and DLSS 4 SR plus RR, and says path tracing "took about six months to implement and ship". It gives no bounce counts and no vendor details — [NVIDIA blog](https://developer.nvidia.com/blog/how-id-software-used-neural-rendering-and-path-tracing-in-doom-the-dark-ages).
- **Indiana Jones**: MachineGames' REAC 2025 deck refers path tracing details to a separate NVIDIA GDC talk — [REAC 2025 Indy](https://www.enginearchitecture.org/downloads/REAC_2025_Indy.pdf).
- **GDC 2026, Capcom and NVIDIA**, "Implementing Real-Time Path Tracing in RE ENGINE" (Resident Evil Requiem, PRAGMATA). Contents:
  - Streaming RIS with a 3D light grid for direct light.
  - ReSTIR GI to stabilise DLSS-RR.
  - SER, where bindless resources were needed to avoid instruction-cache stalls.
  - Sources: [Capcom slides](https://www.docswell.com/s/CAPCOM_RandD/5DM2NL-gdc2026-implementing-real-time-path-tracing-in-re-engine), [wccftech](https://wccftech.com/re-engine-path-tracing-ser-restir-gi-dlss-rr/)
- **NVIDIA at GDC 2026** announced ReSTIR PT in RTX Kit and DLSS 4.5 Dynamic MFG. Its path traced titles include RE Requiem, Pragmata, 007 First Light, Control Resonant, Directive 8020 and Tides of Annihilation — [GeForce news](https://www.nvidia.com/en-us/geforce/news/gdc-2026-nvidia-geforce-rtx-announcements/), [NVIDIA dev blog](https://developer.nvidia.com/blog/nvidia-rtx-innovations-are-powering-the-next-era-of-game-development/).
- **Research:** "ReSTIR PT Enhanced" (Lin, Kettunen and Wyman, NVIDIA; PACMCGIT 2026) is 2–3× faster than ReSTIR PT. It uses reciprocal neighbour selection, footprint-based reconnection and duplication maps, and puts direct and indirect lighting in the same reservoirs — [NVIDIA Research](https://research.nvidia.com/labs/rtr/publication/lin2026restirptenhanced/).
- **Black Myth: Wukong** (UE5) launched with "Full Ray Tracing" and DLSS 3.5 on 2024-08-20 — [NVIDIA GDC 2024 news](https://www.nvidia.com/en-eu/geforce/news/gdc-2024-dlss-rtx-full-ray-tracing-game-announcements/).

### Inferences
- **Suggested study order for yae-engine:**
  1. The nvpro Vulkan RT tutorial: Vulkan KHR ray tracing mechanics, and the GL↔Vulkan interop sample for the bridge.
  2. The Bevy Solari posts: a close match to YAE's scale and to Vulkan without DLSS-RR on AMD/Intel.
  3. The RTXDI and NRD integration guides: production ReSTIR and the vendor-neutral denoiser.
  4. Falcor and RTXPT, for reference-quality path tracing and validation.
- **Every production talk relies on DLSS-RR.** That is why shipped AAA path tracing is NVIDIA-first. A cross-vendor YAE has to own its denoising quality (NRD or SVGF tuning) instead of outsourcing it.

### Gaps
- I did not find 2025–2026 talks on path tracing in Cyberpunk 2077 or Black Myth: Wukong, or the content of a SIGGRAPH 2025 id Tech 8 talk.
- I did not locate the NVIDIA GDC talk on Indiana Jones path tracing (referenced by REAC 2025) or its slides.
- I found no 2025–2026 open-source engine besides Falcor and RTXDI's samples that ships ReSTIR PT. Bevy Solari uses ReSTIR DI/GI plus a cache, not ReSTIR PT.
