# Native neural shading and a native generative "neural remaster" pass for yae-engine (state as of 2026-10-07)

Researched on 2026-10-07 for a C++20 / SDL3 / OpenGL 4.5 engine (Linux and Windows; mid-range target RTX 3060 Ti; developed on an RTX 5090) that already plans an OpenDLSS-NR branch through a GL↔Vulkan bridge. "Verified" means read in the primary source (repository file, registry XML, vendor page) on 2026-10-07. "Claim" means vendor marketing or a secondary report. Every date is the source's own date.

## 1. Neural shading APIs and their real driver support (D3D12 SM 6.9/6.10, Vulkan cooperative vector/matrix, Slang)

### Takeaway
On 2026-10-07 no cross-vendor *per-thread* ("cooperative vector") neural shading API can be shipped. D3D12 deprecated the SM 6.9 Cooperative Vector when SM 6.9 went retail (2026-02-26). It was folded into the SM 6.10 `linalg::Matrix` API, which is still a preview (experimental mode, preview drivers, "do not ship"). Vulkan has only the NVIDIA vendor extension `VK_NV_cooperative_vector`. The only ratified, multi-vendor matrix-unit primitive a Linux and Windows engine can use today is `VK_KHR_cooperative_matrix`. It runs in compute shaders on NVIDIA Turing+, AMD RDNA3/4 and Intel Xe2, with driver caveats. FP8 is not a baseline: only NVIDIA Ada+ and AMD RDNA4 support it. Slang is the practical authoring layer (autodiff, CoopVec, SlangPy), but its CoopVec is hardware-accelerated only on the SPIR-V(NV) and HLSL(LinAlg) targets.

### Cited Findings
#### Direct3D 12
- SM 6.9 went retail on 2026-02-26 with Agility SDK 1.619 and DXC 1.9.2602.16. The retail features are Long Vector (up to 1024 elements), SER, OMM, 16-bit float specials, and native 16-bit, wave and int64 ops (all now required). The post says: "Cooperative Vector has been deprecated in favor of a future design unifying matrix-matrix and vector-matrix operations, coming in Shader Model 6.10". Long Vector support is listed for AMD RX 9000, Intel Arc B-series and all NVIDIA RTX. — [DirectX blog, "Announcing Shader Model 6.9 Retail", 2026-02-26](https://devblogs.microsoft.com/directx/?p=12769)
- The SM 6.10 preview came out on 2026-04-27 with Agility SDK 1.720-preview and DXC 1.10.2605.2. It contains `linalg::Matrix`, Group Wave Index, Variable Group Shared Memory and new RT intrinsics. LinAlg status per vendor: "Supported on AMD Radeon RX 9000 series"; Intel "Planned for an upcoming release"; NVIDIA "Supported on all RTX hardware". — [DirectX blog, SM 6.10 preview, 2026-04-27](https://devblogs.microsoft.com/directx/shader-model-6-10-agilitysdk-720-preview/)
- LinAlg Matrix has three scopes:
  - **Thread scope**, formerly Cooperative Vectors: matrix-vector work inside graphics shaders.
  - **Wave scope**, formerly WaveMMA: matrix-matrix work.
  - **ThreadGroup scope**, which is new: "The tiling decision is shifted to the driver".

  It also adds an outer product with interlocked accumulation for training. Component types are F16, F32, F8_E4M3FN and U32. It requires "AgilitySDK 1.720.1-preview" and experimental features enabled before the device is created. Drivers: AMD "AgilitySDK Developer Preview Edition 25.30.41.02"; NVIDIA "Contact your developer relations representative for in-development driver access" (this conflicts with the SM 6.10 post's "all RTX"); WARP is supported. — [DirectX blog, D3D12 LinAlg Matrix preview, 2026-04-27](https://devblogs.microsoft.com/directx/d3d12-linalg-preview/)
- NVIDIA SDKs moved to newer previews:
  - RTXNS v1.5.0 (2026-09-17) builds against Agility SDK `1.721.3-preview` and requires "DX12: NVIDIA public R615 driver or newer" (its Vulkan path needs R570+). — [RTXNS releases](https://github.com/NVIDIA-RTX/RTXNS/releases)
  - RTXNTC v0.10.0-beta (2026-08-04) requires a pre-release driver 620.12 for SM 6.10 LinAlg, plus Windows Developer Mode. It states: "The DX12 LinAlg support is for testing purposes only. DO NOT SHIP ANY PRODUCTS USING IT". It also says "DX12 LinAlg inference is incompatible with the current version of AMD developer preview drivers (26.10.07.02)". — [RTXNTC README](https://github.com/NVIDIA-RTX/RTXNTC)
- The earlier D3D12 Cooperative Vector preview (Agility 1.717-preview) ran on Intel Arc A and B series and on the built-in Arc GPUs of Core Ultra Series 2 (2025-06-03). — [Intel, Cooperative Vectors Demo](https://www.intel.com/content/www/us/en/developer/articles/technical/cooperative-vectors-demo.html)
- AMD MiniDXNN (MIT; created 2026-03-12, last push 2026-07-10) is a header-only HLSL library for MLP inference and training on LinAlg Matrix. It requires Windows 11 Developer Mode, Agility 1.721-preview, DXC v1.10.2605.4, and "AMD Radeon RX 9000 Series GPUs or equivalent NVIDIA". — [GPUOpen MiniDXNN](https://github.com/GPUOpen-LibrariesAndSDKs/MiniDXNN)

#### Vulkan
- **Registry** (Vulkan-Docs main, last commit 2026-10-02):
  - Cooperative vector exists only as `VK_NV_cooperative_vector` (author NV, extension #492). There is no KHR or EXT cooperative-vector extension.
  - Matrix extensions: `VK_KHR_cooperative_matrix` (ratified), `VK_EXT_cooperative_matrix_maintenance1` (ratified), `VK_NV_cooperative_matrix2`, `VK_NV_cooperative_matrix_decode_vector`, `VK_ARM_cooperative_matrix_layouts`, `VK_QCOM_cooperative_matrix_conversion`.
  - Types: `VK_EXT_shader_float8` (ratified) and `VK_KHR_shader_bfloat16` (ratified).
  - ML graphs: `VK_ARM_tensors` and `VK_ARM_data_graph` (with TOSA, optical-flow and neural-accelerator-statistics add-ons), plus `VK_QCOM_data_graph_model`.

  — [Vulkan-Docs vk.xml](https://github.com/KhronosGroup/Vulkan-Docs/blob/main/xml/vk.xml)
- `VK_EXT_cooperative_matrix_maintenance1` arrived in Vulkan 1.4.359. It adds type/use conversions, reductions, per-element ops and index→coordinate conversion. — [Phoronix](https://www.phoronix.com/news/Vulkan-1.4.359)
- **Khronos ML Birds-of-a-Feather session (SIGGRAPH, July 2026).**
  - Extension timeline: VK_NV_cooperative_matrix (2019) → VK_KHR_shader_integer_dot_product (2021) → VK_KHR_cooperative_matrix (2023, "Cross-IHV ratification") → VK_NV_cooperative_vector (2024, "Tiny networks within a thread e.g. neural texture compression", labelled a vendor extension) → VK_NV_cooperative_matrix2 (2024) → VK_NV_cooperative_matrix_decode_vector (2026).
  - Standardisation: "Vulkan ML TSG is working towards EXT version of some cooperative matrix 2 features".
  - New data type in 2026: `VK_EXT_shader_ocp_microscaling_types` (FP4/FP8/MXINT8).
  - Data graphs: "Currently shipping as ARM extensions and proposed for standardisation".
  - Khronos asks whether it should start an open-source layer to bring ML extensions to all Vulkan hardware.
  - Claims Vulkan inference reaches "85% - 100+% of CUDA performance on most models on NVIDIA hardware".

  — [Khronos ML BOF slides, July 2026](https://www.khronos.org/developers/linkto/machine-learning-neural-rendering-and-the-future-of-open-graphics-slides)
- The Vulkan Roadmap 2026 profile (2026-01-23) contains no ML features. It covers VRS, shader clock, host image copy, compute derivatives, swapchain improvements and higher limits. — [Khronos blog](https://www.khronos.org/blog/vulkan-introduces-roadmap-2026-and-new-descriptor-heap-extension)
- RTXNS on Vulkan: "GPU must support the Vulkan `VK_NV_cooperative_vector` extension (minimum NVIDIA RTX 20XX)", NVIDIA R570+. — [RTXNS README](https://github.com/NVIDIA-RTX/RTXNS)
- **Mesa** (features.txt on main, last commit 2026-10-06):

  | Extension | Mesa drivers marked DONE |
  | --- | --- |
  | `VK_KHR_cooperative_matrix` | anv, lvp, nvk/Turing+, panvk/v11+, radv/gfx11+ (RDNA3+), vn |
  | `VK_EXT_cooperative_matrix_maintenance1` | lvp, radv/gfx11+ |
  | `VK_EXT_shader_float8` | radv/gfx12+ (RDNA4), vn |
  | `VK_KHR_shader_bfloat16` | anv/gfx12.5+, radv/gfx12+, vn |
  | `VK_NV_cooperative_vector`, `VK_NV_cooperative_matrix2` | not listed for any driver |

  — [Mesa docs/features.txt](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/docs/features.txt)

  Phoronix reported on 2025-06-25 that RADV in Mesa 25.2 implements only the `CooperativeMatrixConversionsNV` part of NV coopmat2, for FSR4 and vkd3d-proton. — [Phoronix](https://www.phoronix.com/news/RADV-NV-Coperative-Matrix2)
- **llama.cpp's Vulkan backend** (master, Oct 2026) gates `VK_KHR_cooperative_matrix` per vendor:
  - AMD (both the proprietary and the open driver) is limited to RDNA3/RDNA4 as a "Workaround for AMD proprietary driver reporting support on all GPUs".
  - Intel is limited to Xe2/Xe3, plus integrated Xe1 on the Windows driver, because "older hardware (ex. Arc A770) has performance regressions".

  — [ggml-vulkan.cpp](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-vulkan/ggml-vulkan.cpp)
- **OpenGL:** the GL API registry (gl.xml) contains no cooperative-matrix or cooperative-vector extension (checked 2026-10-07). — [OpenGL-Registry gl.xml](https://github.com/KhronosGroup/OpenGL-Registry/blob/main/xml/gl.xml)

#### Hardware data types
- RDNA3 WMMA supports FP16, BF16, INT8 and INT4. RDNA4 adds FP8 and structured sparsity. AMD claims 2× FP16 and 4× INT8 throughput over RDNA3. This comes from search-result summaries; the pages were not opened. — [Wikipedia, RDNA 3](https://en.wikipedia.org/wiki/RDNA_3); [GPUOpen WMMA guide for RDNA 4](https://gpuopen.com/learn/wmma-guide-amd-rdna-4-gpus-part-1/)
- OpenDLSS-NR's FP8 network (E4M3 activations, FP16 accumulation) requires "an NVIDIA Ada (or newer) GPU". — [OpenDLSS-NR README](https://github.com/maanHimself/OpenDLSS-NR)

#### Slang
- **Targets:** D3D11/D3D12 (HLSL), Vulkan (SPIR-V, GLSL), CUDA (supported); Metal (experimental), WebGPU/WGSL (experimental, "still work in-progress"), OptiX and CPU (experimental). It generates forward and backward derivatives automatically, and has shipped in the Vulkan SDK since 1.3.296.0. — [Slang README](https://github.com/shader-slang/slang)
- **How CoopVec is compiled:**
  - SPIR-V and HLSL targets keep CoopVec as hardware intrinsics (no lowering).
  - CUDA lowers it unless the target has `optix_coopvec`.
  - Every other target (WGSL, Metal, GLSL…) runs `lowerCooperativeVectors`, which turns it into ordinary code.

  — [slang-emit.cpp (master)](https://github.com/shader-slang/slang/blob/master/source/slang/slang-emit.cpp)
- **Releases:** Slang v2026.19 (2026-09-29); SlangPy v0.43.1 (2026-07-16). — [Slang releases](https://github.com/shader-slang/slang/releases); [SlangPy releases](https://github.com/shader-slang/slangpy/releases)
- **`neural.slang`** is "a new experimental standard module for implementing inline neural networks directly in shader code" (HPG 2026 Hot3D talk; post dated 2026-09-09). — [Slang SIGGRAPH 2026 roundup](https://shader-slang.org/blog/2026/09/09/siggraph-2026-roundup/)
- **SIGGRAPH 2026 course code:**
  - Cooperative-vector MLP training is "only supported on Nvidia hardware on Windows/Linux".
  - The `neural/` examples "use the Vulkan cooperative-vector path and require Windows or Linux with an NVIDIA GPU".
  - The scalar samples run on Metal; "cooperative vector is not supported on Metal".

  — [shader-slang/neural-shading-s26](https://github.com/shader-slang/neural-shading-s26)
- **RTXNS v1.4.0** (2026-07-29) added Slang autodiff for cooperative vectors:
  - `dadd`/`dzero` for CoopVec and the `HCoopVec` alias;
  - backward derivatives for shiftedExp, swish and tanh;
  - `LinearOp`/`LinearOp_Backward` with the layout and type as generic parameters.

  It also moved to the DX12 LinAlg (SM 6.10) toolchain. — [RTXNS releases](https://github.com/NVIDIA-RTX/RTXNS/releases)

### Inferences
- **D3D12 LinAlg does not help this engine.** It is Windows-only and preview-only ("do not ship").
- **The shippable accelerated route is Vulkan, in two parts:**
  - `VK_NV_cooperative_vector` for inline per-pixel MLPs on NVIDIA RTX 20+, which includes the RTX 3060 Ti.
  - `VK_KHR_cooperative_matrix` compute kernels as the only vendor-neutral tensor-unit path: NVIDIA Turing+, AMD RDNA3/RDNA4, Intel Xe2. Intel Alchemist exposes it but may be slower than plain code, per llama.cpp's gating.
- **GPUs without matrix units need a fallback.** In the target set that is AMD RDNA2 (RX 6000) and NVIDIA GTX. Both RTXNTC and Intel TSNC ship a DP4a/FMA fallback for this case. Any network we ship must either be useful at FMA/DP4a speed or be optional on these GPUs.
- **Design for FP16, not FP8.** FP8 exists only on NVIDIA Ada+ and AMD RDNA4. Ampere (RTX 3060 Ti) and RDNA3 top out at FP16/BF16/INT8, so the baseline is FP16, plus INT8 where quality allows.
- **Slang is the natural authoring layer, but it needs a runtime switch.**
  - One source can produce SPIR-V for Vulkan, HLSL for a later D3D12 backend, and CUDA for offline tools.
  - On a non-NVIDIA Vulkan device, CoopVec SPIR-V has no accelerated lowering.
  - So the engine needs a second kernel family built on KHR coopmat (or the scalar lowering), picked at runtime by capability.
- **GL exposes no matrix units**, so every accelerated path needs the GL↔Vulkan bridge already planned (Roadmap NR-3) or a future Vulkan renderer.

### Gaps
- No retail date for SM 6.10 / LinAlg was found, and Intel's LinAlg driver is only "planned".
- It could not be verified whether AMD's or Intel's proprietary Vulkan drivers expose `VK_NV_cooperative_vector`: the vulkan.gpuinfo.org coverage page did not render its table. No evidence that they do was found.
- No public KHR/EXT cooperative-vector proposal was found. Khronos only says an EXT for "some cooperative matrix 2 features" is in progress.
- The RDNA3/RDNA4 throughput figures come from search summaries of AMD material, not from opened primary pages.

## 2. NVIDIA RTX Kit neural pieces, AMD and Intel neural work: availability and cross-vendor status

### Takeaway
Of NVIDIA's neural SDKs, only Neural Texture Compression has a real cross-vendor path: decompress on load into BCn on any SM6 / Vulkan 1.3 GPU, with a DP4a fallback. RTX Neural Shaders is a sample/SDK that needs NVIDIA cooperative vectors on Vulkan. The NRC library is binary-only and NVIDIA-only (it bundles CUDA runtime DLLs), with Windows binaries only. Neural Materials and Neural Faces have no public SDK in RTX Kit 2026.1–2026.3. All of AMD's neural features (FSR Redstone ray regeneration, radiance caching, ML frame generation) are RDNA4-only, DX12-only and Windows-only; ML upscaling also covers RDNA3 since SDK 2.3. Intel has productized neural texture compression (TSNC; DX12 XMX plus an FMA fallback, delivered as Slang shaders). Intel's neural denoiser and prefiltering are research only.

### Cited Findings
#### NVIDIA RTX Kit
- RTX Kit 2026.3 (2026-09-09) contains:
  - DLSS SDK 310.9.1, which adds Ray Reconstruction Transformer Preset F;
  - NRD 4.17.3; RTX Character Rendering 1.4.0; RTXDI 3.1.0 (ReSTIR PT improvements, DLSS RR in the sample); RTX Mega Geometry 2.0;
  - RTX Neural Shading 1.4.0 and RTXNTC 0.10.0 Beta, both adding DX12 LinAlg (SM 6.10);
  - RTX Texture Filtering 1.3 (Collaborative Texture Filtering); Streamline 2.14.1.

  No Neural Materials, Neural Faces or Neural Radiance Cache SDK entry appears in the 2026.1, 2026.2 or 2026.3 notes. — [RTX-Kit releases](https://github.com/NVIDIA-RTX/RTX-Kit/releases)
- **RTX Neural Shaders (RTXNS).** It covers "how to train neural networks and use the resulting models for inference alongside conventional graphics rendering". It uses Slang with either the DirectX Preview Agility SDK or Vulkan `VK_NV_cooperative_vector`, includes SlangPy samples, and supports Windows (x64 and Arm64) and Linux. v1.5.0 is dated 2026-09-17. The GitHub licence field is "NOASSERTION", i.e. a custom licence. — [RTXNS](https://github.com/NVIDIA-RTX/RTXNS)
- **RTX Neural Texture Compression (RTXNTC) v0.10.0-beta (2026-08-04):**
  - Modes: "Inference on Load" (transcode to BCn), "Inference on Sample" and "Inference on Feedback" (sampler feedback, sparse tiles).
  - Size and quality: many PBR bundles compress to "about 5 bits/texel" at a PSNR of 40–50 dB comparable to BCn, against 64 bits/texel uncompressed.
  - Speed: cooperative vectors give "2-4x improvement in inference throughput" on Ada and Blackwell.
  - Fallback: "DP4a instructions or regular integer math" on "any platform that supports at least Direct3D 12 Shader Model 6". It was validated on GTX 1000, Radeon RX 6000 and Arc A.
  - Requirements: compression needs Turing+; inference on sample is recommended on Ada+. Vulkan CoopVec builds are "OK to use for shipping". Linux x64 is supported.

  — [RTXNTC README](https://github.com/NVIDIA-RTX/RTXNTC)
- Khronos's July 2026 summary of NTC: a 4096² texture takes 3.8 MB, against 5.3 MB for BC "high" at 1024²; PSNR is 22.0 dB versus 19.4 dB in their example. — [Khronos ML BOF slides](https://www.khronos.org/developers/linkto/machine-learning-neural-rendering-and-the-future-of-open-graphics-slides)
- **Neural Radiance Cache (NRC) library.**
  - Releases: v0.16.0.0 (2026-10-03) added Windows ARM64.
  - Contents: binary only — `NRC_D3D12.dll` and `NRC_Vulkan.dll` plus `cudart64_13.dll` and nvrtc DLLs, for Windows x64/arm64. The repository tree has no Linux binaries. — [NVIDIA-RTX/NRC](https://github.com/NVIDIA-RTX/NRC)
  - Training: the integration guide says it is "relying on Tensor Cores to train the neural network each frame".
  - Memory at 1920×1080 (training resolution 274×154, eight bounces, 1 spp): about 191.8 MB. — [RTXGI NrcGuide.md](https://github.com/NVIDIA-RTX/RTXGI/blob/main/Docs/NrcGuide.md)
- **RTX Neural Faces** is described as taking "a rasterized face and 3D pose and generates an enhanced face in real time". NVIDIA's page offers to notify developers when it becomes available; it is not in RTX Kit releases up to 2026.3. — [NVIDIA dev blog](https://developer.nvidia.com/blog/nvidia-rtx-neural-rendering-introduces-next-era-of-ai-powered-graphics-innovation); [RTX-Kit releases](https://github.com/NVIDIA-RTX/RTX-Kit/releases)
- **Neural materials** currently exist publicly as teaching code: the SIGGRAPH 2026 Slang course has a step-by-step neural material pipeline (`neural/`, NVIDIA Vulkan CoopVec only). — [neural-shading-s26](https://github.com/shader-slang/neural-shading-s26)
- **DLSS SDK v310.9.1** (2026-09-08) ships the SR (`dlss`), RR (`dlssd`) and FG (`dlssg`) libraries for Windows x64/arm64/arm64ec and for Linux x86_64/aarch64. There is no NR library in it. — [NVIDIA/DLSS](https://github.com/NVIDIA/DLSS)

#### AMD
- FSR Redstone launched with Adrenalin 25.12.1 in December 2025 (search summary). — [The FPS Review](https://www.thefpsreview.com/2025/12/10/amd-fsr-redstone-is-coming-to-town-ml-fsr-for-rdna-4/)
- **FSR SDK 2.2** (2026-03-23): FSR Upscaling 4.1 and Ray Regeneration 1.1. The ML features — Upscaling 4.1, Frame Generation 4.0, Ray Regeneration 1.1 and Radiance Caching 0.9 — are RDNA4-only. RDNA 3.5 and older get the analytical FSR 3 fallback. Only "DirectX 12" and the UE5 plugin are listed, on Windows 10/11. — [GPUOpen FSR SDK 2.2](https://gpuopen.com/learn/amd-fsr-sdk-2-2-now-available/)
- **FSR SDK 2.3** (2026-06-24): Upscaling 4.1.1 now runs on "AMD Radeon RX 9000 and 7000 Series" (RDNA3 added). Frame Generation 4.0.1 and Ray Regeneration 1.2.0 stay RX 9000-only; Ray Regeneration 1.2.0 adds AO and specular-occlusion denoising and a checkerboard mode. Radiance Caching 0.9.0 remains a tech preview. DX12 only, Windows only. — [GPUOpen FSR SDK 2.3](https://gpuopen.com/learn/amd-fsr-sdk-2-3-blog/)
- **FSR Radiance Caching** is "an online machine learning model that continuously trains on complex, multi-bounce global illumination (GI) on-device and in real-time". It is a technical preview, v0.9.0, released in December 2025 as part of FSR SDK 2.1, for "Radeon RX 9000 Series graphics cards and above", DirectX 12. — [GPUOpen FSR Radiance Caching](https://gpuopen.com/amd-fsr-radiancecaching/)
- **AMD research** (none of it shipped as an SDK):
  - **Neural Intersection Function** (HPG 2023): an MLP made only of dense matrix multiplications replaces BVH traversal for secondary rays, cutting "secondary ray casting time for direct illumination by up to 35%". — [EG digital library](https://diglib.eg.org/handle/10.2312/hpg20231135)
  - **Neural Texture Block Compression** (EGSR 2024): learns a mapping to BC-compressed textures with "up to about 70% less storage footprint" and no shader changes. — [EG digital library](https://diglib.eg.org/handle/10.2312/mam20241178)
  - **Neural supersampling and denoising for real-time path tracing** (GPUOpen, 2024-10-28, updated 2025-06-26; I3D 2025): a multi-branch multi-scale U-Net on 1 spp radiance, guided by albedo, normal, roughness, depth and specular hit distance, plus motion vectors and history. — [GPUOpen](https://gpuopen.com/learn/neural_supersampling_and_denoising_for_real-time_path_tracing/)

#### Intel
- **Texture Set Neural Compression (TSNC)**, shown at GDC 2026:
  - Variant A: ">9x" compression against 4.8x for BC, with "roughly 5%" FLIP error.
  - Variant B: ">17x" (18.05x maximum), with 6–7% error.
  - Four deployment modes: install, load, stream and sample time.
  - XMX acceleration through the D3D12 cooperative vector / linear algebra path, with an FMA fallback for GPUs without XMX and for CPUs.
  - On Panther Lake B390 at 1080p: 0.661 ns/pixel with FMA against 0.194 ns/pixel with linear algebra, a 3.4× speed-up.
  - Rebuilt on SlangPy and Slang compute shaders, with HLSL or SPIR-V output.

  — [Wccftech, 2026-04-10](https://wccftech.com/intel-texture-set-neural-compression-sdk-tsnc-18x-smaller-textures/); [IT Brief, 2026-04-06](https://itbrief.co.uk/story/intel-releases-neural-texture-compression-sdk-for-game-devs)

  Availability conflict: IT Brief says Intel "has released" TSNC as a standalone SDK, while Wccftech says an "Alpha version" is planned "later this year". No public repository link was found.
- **Neural Prefiltering for Correlation-Aware Levels of Detail** (Weier, Zirr, Kaplanyan et al., TOG 42(4), 2023): two small networks on a sparse multi-level voxel grid, 10–20 minutes of training per asset, 70–95% compression, interactive to real-time rates. Research only. — [Saarland University publication page](https://graphics.cg.uni-saarland.de/publications/weier-2023-neural-lod.html)
- **Intel's neural reconstruction for path tracing** (2025-06-18): a "spatiotemporal joint neural denoising and supersampling model" ran the Jungle Ruins scene at 1 spp, 30 FPS at 1440p on an Arc B580. No XeSS or SDK release was announced. — [Wccftech](https://wccftech.com/intel-enabling-high-fidelity-visuals-faster-performance-on-built-in-gpus-demos-ray-reconstruction-path-tracing-arc-b580/)

  A roundup states that as of August 2026 Intel had published no direct equivalent to NVIDIA Ray Reconstruction (search snippet only). — [Wccftech roundup](https://wccftech.com/roundup/nvidia-dlss-vs-amd-fsr-vs-intel-xess-everything-you-need-to-know/)
- **Open Image Denoise 2.x** runs on CPU, SYCL, CUDA, HIP and Metal devices. Version 2.3 added a "fast" quality mode for interactive previews. — [OIDN releases](https://github.com/OpenImageDenoise/oidn/releases); [Phoronix on OIDN 2.3](https://www.phoronix.com/news/Open-Image-Denoise-2.3)

### Inferences
- **NTC (NVIDIA or Intel) adds little for YAE as a feature.** The assets are 2006-era and small. Its value is as a reference: cross-vendor MLP inference shipped with CoopVec, linear-algebra and DP4a/FMA tiers.
- **No vendor neural path-tracing assist covers a Linux and Windows Vulkan engine on all three vendors.** NRC is NVIDIA-only and Windows-only; FSR Radiance Caching and Ray Regeneration are RDNA4-only, DX12-only and Windows-only; Intel has nothing shipped. A vendor-neutral NRC has to be our own code (see question 5).
- **Neural Faces and Neural Materials cannot be planned on**: neither has a public SDK.

### Gaps
- RTX Neural Faces: no release date or licence terms found.
- NRC library: licence text not read; there is no Linux build and no statement about one.
- FSR SDK: no Vulkan or Linux timeline found.
- Intel TSNC: availability and download location are unresolved because the two reports conflict.
- No measured ms costs were found for NRC, FSR Radiance Caching or Ray Regeneration on mid-range GPUs.

## 3. Native integration of a DLSS-5-class generative "neural remaster" pass: inputs, placement, temporal stability, the DLSS 5 SDK

### Takeaway
As of 2026-10-07, NVIDIA's DLSS 5 Neural Rendering SDK is not public:
- Streamline 2.14.1 and DLSS SDK 310.9.1 contain no NR plugin, header or library;
- custom-engine developers asking on NVIDIA's forums in late September and early October 2026 have no visible reply;
- the only shipping title, NBA 2K27 (2026-09-03), runs it on RTX 50 only.

The documented contract therefore comes from three places: NVIDIA's marketing and research pages (color + motion vectors, models, Structure/Tone intensity, semantic and engine masks, end-of-pipeline stage); OpenDLSS-NR's reimplementation of the 310.8.0 network and its demo pipeline; and the OptiScaler/RenoDX injection composition.

That 310.8.0 network sees no depth, normals, albedo or per-pixel masks. Its inputs are an LDR paper-white proxy, 3 lanes of noise, the reprojected previous output and five scalars. A native integration therefore gains mainly from:
- exact linear HDR and paper white;
- correct per-object and skinned motion vectors, with "history present" flags and resets;
- excluding the UI by where the pass sits;
- engine-authored masks applied in the composite;
- compositing back into HDR before the engine's own tone mapping.

### Cited Findings
#### NVIDIA DLSS 5: what is public
- **Announcement** (2026-03-16): "DLSS 5 takes a game's color and motion vectors for each frame as input". It "provides game developers with detailed controls for intensity, color grading and masking". "Integration is seamless, using the same NVIDIA Streamline framework". It "will arrive this fall". — [NVIDIA newsroom](https://nvidianews.nvidia.com/news/nvidia-dlss-5-delivers-ai-powered-breakthrough-in-visual-fidelity-for-games)
- **SIGGRAPH 2026** (2026-07-21): a "one-step pixel-space diffusion transformer distilled from substantially larger foundation models". The first demo used two RTX 5090s, one only for the AI; the launch target is a single GPU. Developers can pick between three models per scene and use Structure and Tone Intensity sliders and masks per character or object. — [PC Games Hardware](https://www.pcgameshardware.de/Deep-Learning-Super-Sampling-Software-277618/Specials/dlss-5-three-ai-models-single-gpu-control-siggraph-2026-1548907/)
- **ADLR report page** (2026-09-01), quoted directly:
  - "one-step pixel-space diffusion model";
  - conditioned on "the current rendered frame, engine motion vectors, carried temporal state, and artistic-direction values";
  - "consistency supervision from renderer-derived scene attributes" during training;
  - "trained for frame-to-frame temporal stability";
  - "causal and deterministic";
  - real time "at up to 4K";
  - "runs locally as a rendering stage within existing game pipelines on GeForce RTX 50 Series GPUs".

  The PDF report returned HTTP 403. — [NVIDIA ADLR, DLSS 5: Generative Neural Rendering](https://research.nvidia.com/labs/adlr/DLSS5/)
- **GeForce news** (2026-09-01) mentions:
  - "color and motion vectors as input" and analysis of "color, surface albedo, detailed lighting, and surface normals";
  - "Structure Intensity and Tone Intensity", "semantic AI masking that recognizes scene objects automatically", and engine-level masking of prop or asset groups (glassware, water droplets, foliage);
  - Streamline or the UE5 plugin;
  - NBA 2K27 at 370 fps at 4K on an RTX 5090.

  — [NVIDIA GeForce news](https://www.nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/)
- **Technical preview** (launch 2026-09-03):
  - It is "a generative AI stage attached to the end of the render pipeline", working "alongside Super Resolution, Multi Frame Generation and Ray Reconstruction".
  - Structure intensity covers "high-frequency detail: ambient occlusion, contact shadows, reflections and subsurface scattering"; Tone intensity covers "low-frequency detail: broader lighting and color response".
  - Semantic auto-masking comes from the model; engine-level masking comes from the engine.
  - NVIDIA claims performance improved "5X in six months" (March→August 2026).
  - RTX 50 desktop and laptop GPUs only.
  - 370 FPS displayed at 4K = Performance SR + 6× MFG, about 62 FPS rendered.
  - Caveat: "NVIDIA has not published a DLSS 5 on versus off comparison at matched settings".

  — [Back2Gaming](https://www.back2gaming.com/features/nvidia-dlss-5-technical-preview-3d-guided-neural-rendering/)
- **NVIDIA developer blog** (2026-09-22): developers can "choose from among several models, mix them across scenes, gameplay, or cutscenes, and adjust Structure Intensity and Tone Intensity", and "use semantic AI masking to apply or hold back the effect". The post has no SDK-access details. — [NVIDIA developer blog](https://developer.nvidia.com/blog/whats-new-for-game-developers-dlss-5-with-3d-guided-neural-rendering-nvidia-ace-updates-and-new-rtx-kit-capabilities/)
- **Measured** (HotHardware, 2026-09-04):
  - RTX 5070 Ti, 2560×1440 Quality, NBA 2K27: 68.9 fps average with NR against about 240 fps without.
  - The GPU sat at its 300 W limit; the RTX 5090 laptop "can't really use DLSS 5".
  - NVIDIA says Ada support will come "once RTX 50 Series performance is more fully tuned".

  — [HotHardware](https://hothardware.com/news/nvidia-dlss-5-neural-rendering-tested)
- **SDK availability** (verified 2026-10-07):
  - Streamline main / v2.14.1 (2026-09-08) has headers `sl_dlss.h`, `sl_dlss_d.h`, `sl_dlss_g.h`, `sl_deepdvc.h`, `sl_directsr.h`… and no neural-rendering header or programming guide. — [NVIDIA-RTX/Streamline](https://github.com/NVIDIA-RTX/Streamline)
  - DLSS SDK 310.9.1 has no NR library. — [NVIDIA/DLSS](https://github.com/NVIDIA/DLSS)
  - A custom-engine developer reported on 2026-09-24 that Streamline 2.14.1 lacks "the neural-rendering plugin implementation, feature-specific header, or integration guide". No NVIDIA reply is visible; similar requests followed on 2026-10-01..05. — [NVIDIA Developer Forums](https://forums.developer.nvidia.com/t/dlss-5-neural-rendering-sdk-access-for-a-custom-windows-engine/384226)
- **Unverified (page returned 403; search snippet only):** TechPowerUp's analysis of the DLL leaked from NBA 2K27's early-access build lists runtime inputs of Backbuffer/Color, Depth, MVec, UI handling, masking and a "bidirectional distortion field". — [TechPowerUp](https://www.techpowerup.com/352033/nvidia-dlss-5-dll-leaked-by-nba-2k27-early-access-build-heres-our-analysis)

#### OpenDLSS-NR (310.8.0 network; HEAD 9d08f41, 2026-09-21; MIT)
- **Input lanes** (16 per padded pixel):

  | Lanes | Contents |
  | --- | --- |
  | 0–2 | Gaussian noise ("Box-Muller from a hash of the *padded* pixel coordinate and a per-frame seed") |
  | 3 | constant 1 |
  | 4–6 | centred display proxy |
  | 7–9 | the reprojected previous **output** (a copy of 4–6 without history) |
  | 10 | style id/128 |
  | 11 | local tone |
  | 12–14 | "structure / skin / auto-mask conditioning triple" |
  | 15 | 0 |

  Padding is a mirrored copy with its own noise. — [docs/network.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/network.md)
- **Proxy:**
  - `v = scene / max(paperWhite, 0.05)`;
  - a shoulder above 0.75: `0.75 + 0.25·(1 − exp(−5.770780·(v − 0.75)))`;
  - sRGB encoding on the f16 grid;
  - "Non-finite and negative scene values are clamped to zero first".

  — [docs/frame.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/frame.md)
- **Composition:**
  - `neural = clamp(proxy + rgb/4)`;
  - `weight = clamp(sigmoid(head.a) · blendScale)`, where blendScale is a learned 0.7397;
  - `lerp` with the history only where a history exists;
  - the stored history is truncated toward zero to half precision (it feeds the next frame's input).
  - After that come the style operator (natural/cinematic presets), an intensity blend back toward the proxy, then a "tone upgrade": "matching luminance ratios and transferring hue in Oklab" to put LDR results back on the HDR scene.

  — [docs/frame.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/frame.md)
- **Temporal loop:**
  - five-tap Catmull-Rom history sampling ("A box or bilinear filter here visibly softens the result frame over frame");
  - a "history present" flag separate from motion ("Zero motion means 'the history is at this same pixel'");
  - sky motion from rotation-only reprojection;
  - disocclusion is left to the network's logit; its mean blend weight on Bistro falls "from 0.69 at rest to 0.15 during the scripted orbit";
  - blended (translucent) renderables carry only camera motion;
  - toggling NR does not flash because the history stays primed with the proxy.

  — [docs/frame.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/frame.md)
- **Per-object motion vectors** (patched Filament). The engine stores the previous world transform, bones, morph weights, instance transforms and the previous unjittered clip-from-world. Reprojection error on Bistro at 1280×720 is 0.006, against 0.030 without reprojection and 0.037 with the sign flipped. The skinned/morphed path gives 0.007 against 0.014. — [docs/frame.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/frame.md)
- **Engine embedding.** The NR work is recorded "into Filament's own command buffer, between the scene view and the present view": no extra submissions, no host synchronization. Four secondary command buffers are pre-recorded (history parity × NR on/off), and only the parameter block is updated each frame. A resize re-fits in about 50 ms. — [docs/frame.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/frame.md)
- **Requirements and performance.**
  - Needs Ada+ with `VK_KHR_cooperative_matrix`, `VK_NV_cooperative_matrix2`, `VK_EXT_shader_float8` and `VK_NV_cuda_kernel_launch`.
  - RTX 4070 SUPER (241 dispatches): 2.8 ms at 768², 7.8 ms at 1080p, 12.6 ms at 1440p, 29.3 ms at 4K.
  - The WebGPU port (no tensor cores, no FP8) takes 72 ms at 512² against 2.7 ms natively.
  - Weights are 141 MiB in FP8.

  — [OpenDLSS-NR README](https://github.com/maanHimself/OpenDLSS-NR)

#### Injection route (OptiScaler DLSS-NR "by dag" with RenoDX composition; shipped in this repository's payload, NGX `nvngx_dlssnr.dll` 310.8.0, about 165 MB)
- **Placement:** "Immediately after the game's upscaler, on the same command list, before the interface is drawn… the model never sees your HUD". With frame generation, NR runs once per rendered frame. Its inputs are the depth and motion vectors the game already gives DLSS. — [READ ME - DLSS Neural Rendering.txt](https://github.com/OpenYAE/yae-dlss5/blob/main/payload/host64/READ%20ME%20-%20DLSS%20Neural%20Rendering.txt)
- **Composition** (credited to RenoDX's DLSS 5 addon by clshortfuse). The model's answer is treated as a complete picture, not a delta:
  - `UpgradeToneMap` uses a two-branch luminance ratio: below the proxy's luminance the original is the target; above it, the difference is headroom handed back on top;
  - an OkLab hue correction keeps the model's hue and chroma direction;
  - a final blend runs between a luminance-only result and the full colour;
  - a reversible neutral-axis gamut compression works in a Hunt-Pointer-Estevez LMS basis.

  — [RenoDX_ATTRIBUTION.txt](https://github.com/OpenYAE/yae-dlss5/blob/main/payload/host64/Licenses/RenoDX_ATTRIBUTION.txt)
- **Controls** exposed by the injection, with defaults:

  | Setting | Behaviour |
  | --- | --- |
  | `TransferStrength` | 1.0 by default |
  | `ColourStrength` | 1.0 by default |
  | white point | auto-measured from the frame ("measured frame means in one game ranged from 0.065 to 185") |
  | `WhitePointScale` | the paper-white control |
  | `MaxRatio` | 2.0 by default: the most any pixel may be brightened; darkening is not capped |
  | `WorkingScale` | "Cost falls with the square of this"; above 1.0 it supersamples |

  The model's own parameters are `Preset` (baked in when the model is created), `Style`, `Intensity`, `LocalStructure`, `LocalTone`, `SkinStructure` (−1 = follow local structure) and `AutoMask` (default true). — [OptiScaler.ini, `[DlssNr]`](https://github.com/OpenYAE/yae-dlss5/blob/main/payload/host64/OptiScaler.ini)

#### yae-engine's own starting point
- The Roadmap section added 2026-09-25 records what exists: `FrameConstants::prevViewProj` is filled; `RenderScene` instances carry `prevWorld` (nothing reads it); the HDR target is RGBA16F; MRT1 holds the normal and linear depth. Still missing: a velocity attachment, the previous bone palette, a "no history" flag and a history reset on events. The whole `med1` frame at 3440×1440 costs 3.7 ms. The planned insertion point is "after the scene, before HUD/UI/console/menu/video". — [yae-engine docs/Roadmap.md](https://github.com/OpenYAE/yae-engine/blob/main/docs/Roadmap.md)

### Inferences
- **What "native" adds for the 310.8.0 network.**
  - **Exact paper white and exposure.** The engine knows the linear HDR value that maps to display white. Injection has to guess it: OptiScaler auto-measures it, and frame means span 0.065–185.
  - **Correct motion and history validity.** Per-object, skinned, instance and sky motion; separate "no history" flags; resets on load, teleport, cutscene cut and save load. The original YAE through the Feeder gets only ReShade-estimated depth and motion vectors.
  - **UI kept out by placement**, the same as in the injection route.
  - **Engine masks, applied by us.** The network has no per-pixel mask lane. Its "skin" and "structure" are scalar conditioning plus an auto-mask flag. So we would apply the engine-level masking NVIDIA advertises ourselves, as a per-pixel strength multiplier in the composite. Candidates: the first-person weapon, flares, particles, decals, water, translucent surfaces, the skydome, and in-world text.
  - **Compositing in linear HDR before our tonemapper and grading**, using the luminance-ratio + OkLab tone upgrade from OpenDLSS-NR and RenoDX. This keeps the authored darkness instead of the network's LDR tone.
- **Placement, as a design proposal:**
  1. Scene → (later TAA/upscale) → build the NR proxy from linear HDR with the engine's own paper white.
  2. NR → composite back into HDR.
  3. Tone map / colour grading.
  4. UI/HUD/console/menu/video.

  This matches DLSS 5's "end of the render pipeline" stage and OptiScaler's "after upscaler, before UI".
- **A reduced working resolution is the main cost lever.** Cost scales with the square of the scale (OptiScaler). OpenDLSS-NR's timings grow roughly linearly with pixels (7.8 → 29.3 ms for 4× the pixels). So a 0.5 working scale at 1440p should cost roughly 3–4 ms on a 4070 SUPER-class GPU, with fine synthesized structure softened. This is an estimate, not measured.
- **Async compute brings little with the bridge.** NR runs on its own VkDevice/queue, synchronized with exported semaphores. Overlapping it with GL work requires pipelining one frame ahead, which adds a frame of latency. OpenDLSS-NR's zero-extra-sync model (recording into the renderer's own command buffer) is only possible once the renderer is itself Vulkan, for example the RTGL1 branch.
- **Temporal stability means matching what the network was trained on.** Use a per-frame seed hashed from the padded coordinate (and the `--fixed-dt` frame index for gates), the 5-tap Catmull-Rom, the history flag, the network's logit × 0.7397 cap, and half truncation. Engine-side additions belong in the composite, not the input: a highlight guard (OptiScaler's MaxRatio) and a mask-driven strength. No source documents neighbourhood clamping of the NR history.
- **Approximate DLSS 5 cost** from HotHardware's 5070 Ti numbers: 1000/68.9 − 1000/240 ≈ 10 ms per rendered frame at 1440p Quality. This assumes the same SR/FG settings in both runs, which the article does not state. It is the same order as OpenDLSS-NR's 12.6 ms at 1440p on a 4070 SUPER.
- **The 310.8.0 network cannot meet the coverage goal** (RTX 3060 Ti, RDNA2/3/4, Arc). Its arithmetic is FP8 and its fast path is PTX. Without tensor cores the WebGPU port is about 27× slower at 512². The weights are 141 MiB of 1-byte FP8 values, about 148 M parameters (a calculation from the size). Even an FP16 KHR-coopmat port would likely land far beyond a mid-range frame budget at native resolution. Wider coverage needs a much smaller network of our own (question 4), or an NVIDIA-only opt-in mode.

### Gaps
- NVIDIA's official DLSS 5 programming guide or input list is not public. It is unknown whether it takes depth, an explicit UI layer, masks per pixel, or HDR input with exposure. The leaked-DLL input list is unverified.
- The ADLR PDF report (architecture size, training data, losses) returned 403.
- OpenDLSS-NR timings on the RTX 5090 are not published; this is the Roadmap's NR-0 task.
- No primary measurement isolates the cost of DLSS 5 itself; HotHardware's ratio is not settings-matched.
- RenoDX's DLSS 5 addon source was not found on RenoDX's main branch (searched 2026-10-07). The composition is known only from the attribution text and OpenDLSS-NR's description.

## 4. Training our own small game-specific network: feasibility, prior work, model sizes and costs, inference routes, toolkits

### Takeaway
Training a small, game-specific enhancement network ourselves is feasible in 2026 at the scale of published work. Comparable U-Net GANs train on a single 12 GB consumer GPU (HyPER-GAN: one RTX 4070, 20 epochs). Arm ships a fully open, retrainable real-time temporal network (NSS) with data-capture and training tools.

Generative "remaster" networks that run in real time cost tens of ms at 1080p on high-end GPUs:
- HyPER-GAN: 12.7 ms on an RTX 4090, 29.6 ms on an RTX 4070 SUPER;
- REGEN: 32 ms at 960×540 on an RTX 4090;
- DLSS-class quality comes from distilling far larger foundation models.

So for an RTX 3060 Ti budget (about 2–4 ms) the realistic target is an NSS-sized (~10 GOP) kernel-prediction/residual network, trained supervised on pixel-aligned pairs from our own renderer (raster GL vs a path-traced or high-quality reference). It should run as hand-written FP16 Vulkan compute (KHR coopmat, with a fallback) rather than through ONNX Runtime.

### Cited Findings
#### Prior work on game "photorealism / remaster" networks
- **REGEN** (arXiv 2508.17061, 2025-08-23):
  - Uses EPE (Richter et al.; G-buffer-conditioned GAN with class-specific streams and an MSeg-based discriminator) to build a pseudo-paired dataset, then trains a lightweight paired Pix2PixHD.
  - Data: CARLA2Real-UE4 (15,011 frames); targets Cityscapes (5,000 images) and KITTI (15,000 frames).
  - Inference uses the frame only.
  - RTX 4090: 31.12 FPS (32.13 ms) at 960×540 against 2.58 FPS for EPE; 25.57 FPS at 1280×720; 10.99 FPS at 1920×1080.
  - CMMD is slightly better than EPE; temporal consistency is checked with optical-flow endpoint error.

  — [REGEN, arXiv HTML v2](https://arxiv.org/html/2508.17061v2)
- **HyPER-GAN** (arXiv 2603.10604, v3 2026-06-29):
  - Architecture: a U-Net generator (three down and three up stages, 64/128/256 channels, four residual blocks) and a PatchGAN discriminator. No G-buffers.
  - Training data: 19,252 GTA-V/PFD frames paired with EPE outputs, plus matched patches from Cityscapes (5,000) and Mapillary Vistas (25,000).
  - Training: "Single NVIDIA RTX 4070 GPU with 12GB", 20 epochs, batch 1.
  - Inference at 1080p: RTX 4090 78.90 FPS (12.68 ms, 1.8 GB VRAM); RTX 4070 SUPER 33.74 FPS (29.64 ms).
  - Integrated into UE 5.4+ through the "Neural Rendering plugin" via ONNX.
  - Claims 6× REGEN's FPS.

  — [HyPER-GAN, arXiv](https://arxiv.org/html/2603.10604v3)

  Conflict on EPE speed: HyPER-GAN cites EPE at 22 FPS at 957×526, but REGEN measured EPE at 2.58 FPS at 960×540 on an RTX 4090.
- **DLSS 5** is "distilled from substantially larger foundation models" — [PC Games Hardware](https://www.pcgameshardware.de/Deep-Learning-Super-Sampling-Software-277618/Specials/dlss-5-three-ai-models-single-gpu-control-siggraph-2026-1548907/). It is trained with "consistency supervision from renderer-derived scene attributes" — [NVIDIA ADLR](https://research.nvidia.com/labs/adlr/DLSS5/).

#### Open, retrainable real-time networks (closest template)
- **Arm Neural Super Sampling (NSS)** (2025-08-12):
  - A "four-level UNet backbone" parameter-prediction network that outputs a 4×4 filter kernel, temporal accumulation/rectification coefficients and a hidden-state tensor fed back to the next frame. About 10 GOPs.
  - Inputs: color, motion vectors, depth, jitter and camera matrices, plus a luma derivative (against flicker) and disocclusion masks.
  - Training data: about 100-frame sequences of 540p 1 spp frames paired with 1080p 16 spp ground truth. Trained in PyTorch (Adam, cosine LR), with ExecuTorch quantization-aware training.
  - Budget: ≤4 ms on mobile; pre- and post-shaders take about 1.4 ms.

  — [Arm community blog](https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/how-arm-neural-super-sampling-works)
- **NSS distribution.**
  - The weights are open under Arm's AI Model Community License, which allows retraining "on datasets captured from your own content".
  - Tools: the Neural Graphics Model Gym, an Unreal data-capture plugin, and the VGF model format for the ML SDK for Vulkan.
  - An Emulation Layer implements the ML extensions where the driver lacks them.
  - v1 has high, mid and low quality modes.

  — [Hugging Face Arm/neural-super-sampling](https://huggingface.co/Arm/neural-super-sampling)
- Arm's documentation reports about 2.0 ms of inference on the Neural Accelerator plus about 1.35 ms of pre/post, about 3.35 ms in total (search summary). — [Arm NSS use case guide](https://documentation-service.arm.com/static/689c51eee7f7ce6150e89527?token=)

#### In-engine training and inference toolkits
- **RTXNS:** trains MLPs inside the renderer in Slang with autodiff on CoopVec. NVIDIA only. — [RTXNS](https://github.com/NVIDIA-RTX/RTXNS)
- **SlangPy:** Python-driven training on the same Slang kernels. — [neural-shading-s26](https://github.com/shader-slang/neural-shading-s26)
- **MiniDXNN:** DX12 LinAlg MLP inference and training (preview). — [MiniDXNN](https://github.com/GPUOpen-LibrariesAndSDKs/MiniDXNN)
- **VkNRC:** a Vulkan NRC whose "Fully-Fused MLP is implemented with VK_NV_cooperative_matrix (the KHR one is too limited)" and which claims faster backpropagation than tiny-cuda-nn. Last push 2024-09-10; no licence file. — [AdamYuan/VkNRC](https://github.com/AdamYuan/VkNRC)

  Conflict: Khronos's slides say it is "Implemented in open GLSL using VK_KHR_cooperative_matrix". — [Khronos ML BOF slides](https://www.khronos.org/developers/linkto/machine-learning-neural-rendering-and-the-future-of-open-graphics-slides)
- **Benchmarks and samples:** `jeffbolznv/vk_cooperative_vector_perf` (updated 2026-04-21) and Intel's `wenjiewang-intel/dx12-cooperative-vector-perf` (2026-01-13). — [jeffbolznv/vk_cooperative_vector_perf](https://github.com/jeffbolznv/vk_cooperative_vector_perf); [wenjiewang-intel/dx12-cooperative-vector-perf](https://github.com/wenjiewang-intel/dx12-cooperative-vector-perf)

#### Inference routes
- **Windows ML / ONNX Runtime** (doc dated 2026-09-22).
  - Execution providers: MIGraphX (AMD; "RDNA 3 or later", driver 25.10.13.09+), NvTensorRtRtx (NVIDIA; "GeForce RTX 30XX and above", driver 32.0.15.5585 + CUDA 12.5), OpenVINO (Intel), QNN, VitisAI, and WebGPU ("experimental"; "Any DirectX 12–capable GPU").
  - The downloadable EPs need Windows 11 24H2+; DirectML is in-box but labelled "(legacy)".

  — [Microsoft Learn](https://learn.microsoft.com/en-us/windows/ai/new-windows-ml/supported-execution-providers)

  Windows ML became generally available on 2025-09-23. — [Windows Developer Blog](https://blogs.windows.com/windowsdeveloper/2025/09/23/windows-ml-is-generally-available-empowering-developers-to-scale-local-ai-across-windows-devices/). NVIDIA claims TensorRT for RTX is ">50% faster" than DirectML. — [NVIDIA blog](https://developer.nvidia.com/blog/deploy-ai-models-faster-with-windows-ml-on-rtx-pcs)
- **Vulkan-native inference libraries:**
  - ncnn links statically into "one binary, any IHV device, <10MB". Its Vulkan gemm, convolution and SDPA layers use cooperative matrices (code search: 39 hits); latest release 20260526. — [Khronos ML BOF slides](https://www.khronos.org/developers/linkto/machine-learning-neural-rendering-and-the-future-of-open-graphics-slides); [Tencent/ncnn](https://github.com/Tencent/ncnn)
  - ggml (llama.cpp, stable-diffusion.cpp) is "one binary, any IHV device, <50MB" and uses KHR coopmat and NV coopmat2. — [llama.cpp PR #10597](https://github.com/ggml-org/llama.cpp/pull/10597)
  - Kompute's last release is v0.9.0 (2024-01-20); the repository was pushed 2026-08-15. — [KomputeProject/kompute](https://github.com/KomputeProject/kompute)
  - Arm's ML SDK for Vulkan (VGF) plus the emulation layer. — [Hugging Face NSS card](https://huggingface.co/Arm/neural-super-sampling)
- **WebGPU:** Chromium's `chromium-experimental-subgroup-matrix` shows about 0% support in web3dsurvey. — [web3dsurvey](https://web3dsurvey.com/webgpu/features/chromium-experimental-subgroup-matrix). OpenDLSS-NR's WebGPU port takes 72 ms at 512². — [OpenDLSS-NR README](https://github.com/maanHimself/OpenDLSS-NR)

### Inferences
- **Training data we can render ourselves.** The engine can render exactly aligned pairs with G-buffers (depth, normals, albedo, material and object IDs, motion). Possible targets: an offline path-traced reference (the RTGL1/PT branch or a baker), "hero asset / high-quality material" renders (yae-materials PBR), or even DLSS-NR 310.8.0 outputs used as a teacher on NVIDIA hardware. The last option is a licence question that is out of scope here. With pixel-aligned pairs the problem becomes supervised (L1 / perceptual + temporal warping loss), which is easier and more stable than EPE-style unpaired GAN training. REGEN and HyPER-GAN show the "pseudo-pairs → small paired model" route works.
- **Compute needed.** HyPER-GAN's precedent (one RTX 4070) suggests a single RTX 5090 can train a few-million-parameter U-Net in hours to days. Temporal training needs sequences (NSS uses ~100 frames) and per-pixel motion, which the engine has once NR-2 is done.
- **Size budget for the RTX 3060 Ti.** Published "remaster" networks cost 12–30 ms at 1080p even on Ada/Ada-refresh GPUs. A 2–4 ms budget on Ampere points to an NSS-class network (~10 GOPs at 540p-ish internal resolution, recurrent hidden state), or to running a heavier network at a reduced working scale and upsampling only the residual/detail layer. This is an estimate.
- **Inference route.** Hand-written Slang/GLSL compute on `VK_KHR_cooperative_matrix` (FP16) covers NVIDIA Turing+, AMD RDNA3/4 and Intel Xe2 on Linux and Windows. Use `VK_NV_cooperative_vector` for tiny per-pixel MLPs on NVIDIA, and an FP16/DP4a scalar fallback for RDNA2/GTX. This avoids ONNX Runtime's Windows-only EPs and the cost of sharing GL/Vulkan resources with ORT. ncnn is the most practical cross-vendor library for prototyping and accuracy checks before porting the kernels.

### Gaps
- No published measurement of a small enhancement network on an RTX 3060 Ti, RDNA2/3 or Arc was found.
- No public numbers on DLSS 5's training data or compute.
- No shipped game was found that uses a self-trained "remaster" network.
- Zero-copy interop between Windows ML EPs and a Vulkan/GL renderer is not documented in the sources read.
- The training compute of NSS itself is not stated.

## 5. ML assists for path tracing as a neural layer (NRC, neural path guiding, ML denoisers)

### Takeaway
Every shipping ML assist for path tracing is single-vendor:
- **NVIDIA:** DLSS Ray Reconstruction (public DLSS SDK with Linux and Windows libraries; Streamline on Windows) and the NRC library (binary, CUDA-backed, Windows).
- **AMD:** FSR Ray Regeneration and Radiance Caching (RDNA4, DX12, Windows).
- **Intel:** research demos only.

Neural path guiding is still research. For a Linux and Windows engine covering all three vendors, the viable neural layer is our own online-trained NRC-style MLP on `VK_KHR_cooperative_matrix` (VkNRC shows feasibility), with DLSS RR as an NVIDIA-only option on top of a non-neural denoiser baseline.

### Cited Findings
- **NRC (NVIDIA).**
  - Workflow: an "update" path-trace pass at reduced resolution writes training data, then a full-resolution "query" pass; NRC "propagates the predicted data backwards along the training path" and trains each frame on Tensor Cores; a resolve pass follows.
  - Memory: about 191.8 MB at 1080p (training resolution 274×154, eight bounces).
  - API: D3D12 and Vulkan; "NRC relies on `-fvk-use-dx-layout`".

  — [RTXGI NrcGuide.md](https://github.com/NVIDIA-RTX/RTXGI/blob/main/Docs/NrcGuide.md)

  The library ships CUDA runtime and nvrtc DLLs and Windows x64/arm64 binaries only (v0.16.0.0, 2026-10-03). — [NVIDIA-RTX/NRC](https://github.com/NVIDIA-RTX/NRC)
- **Patents (plain fact):** NVIDIA holds US patents titled "Real-time neural network radiance caching for path tracing" (US 11,610,360) and "Fully-fused neural network execution" (US 11,631,210; US 11,935,179). — [USPTO 11610360](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11610360); [USPTO 11631210](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11631210)
- **Open NRC re-implementation:** VkNRC (Vulkan; fully-fused MLP on NV cooperative matrix; last push 2024-09-10; no licence file). — [AdamYuan/VkNRC](https://github.com/AdamYuan/VkNRC). Khronos lists it as running NRC "online every frame… Converges in seconds". — [Khronos ML BOF slides](https://www.khronos.org/developers/linkto/machine-learning-neural-rendering-and-the-future-of-open-graphics-slides)
- **AMD FSR Radiance Caching 0.9.0:** a tech preview with online training on-device, RX 9000+, DX12. — [GPUOpen](https://gpuopen.com/amd-fsr-radiancecaching/)
- **DLSS Ray Reconstruction.**
  - In the public DLSS SDK 310.9.1, the `dlssd` libraries exist for Windows and for Linux x86_64/aarch64. — [NVIDIA/DLSS](https://github.com/NVIDIA/DLSS)
  - RR Transformer Preset F arrived with RTX Kit 2026.3. — [RTX-Kit releases](https://github.com/NVIDIA-RTX/RTX-Kit/releases)
  - **Required Streamline tags:** input and output color, depth (linear or hardware), motion vectors, diffuse albedo, specular albedo, normals (+roughness).
  - **Optional tags:** specular motion vectors (or specular hit distance with camera matrices), a transparency layer and its opacity, color before transparency, an SSS guide and a DoF guide.

  — [Streamline ProgrammingGuideDLSS_RR.md](https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS_RR.md)
- **FSR Ray Regeneration 1.2.0:** RX 9000 only, DX12, Windows. It adds AO and specular-occlusion denoising and a checkerboard mode. — [GPUOpen FSR SDK 2.3](https://gpuopen.com/learn/amd-fsr-sdk-2-3-blog/)
- **Intel:** a joint neural denoising + supersampling demo at 1 spp, 30 FPS at 1440p on an Arc B580 (2025-06-18), with no SDK. — [Wccftech](https://wccftech.com/intel-enabling-high-fidelity-visuals-faster-performance-on-built-in-gpus-demos-ray-reconstruction-path-tracing-arc-b580/). OIDN is cross-vendor (CPU/SYCL/CUDA/HIP/Metal) with a "fast" mode since 2.3. — [Phoronix](https://www.phoronix.com/news/Open-Image-Denoise-2.3)
- **AMD research** on neural supersampling + denoising at 1 spp (I3D 2025) has no SDK. — [GPUOpen](https://gpuopen.com/learn/neural_supersampling_and_denoising_for_real-time_path_tracing/)
- **Arm** ships "Neural Super Sampling and Denoising (NSSD)" in its Unreal plugin, built on its data-graph extensions; it is mobile-oriented. — [Khronos ML BOF slides](https://www.khronos.org/developers/linkto/machine-learning-neural-rendering-and-the-future-of-open-graphics-slides); [arm/neural-graphics-for-unreal](https://github.com/arm/neural-graphics-for-unreal)
- **Neural path guiding** remains research:
  - online neural path guiding with normalized anisotropic spherical Gaussians — [arXiv 2303.08064](https://arxiv.org/pdf/2303.08064);
  - a neural parametric mixtures GPU prototype — [neuropara/neural-mixture-guiding](https://github.com/neuropara/neural-mixture-guiding);
  - a student real-time neural path guiding project — [dom-wuest/NeuralPathGuiding](https://github.com/dom-wuest/NeuralPathGuiding).

  The real-time path-guiding work cited for 2025–2026 (ReSTIR Path Guiding, SIGGRAPH Asia 2025; Radiance Cascade Path Guiding) is described as non-neural (search summary). — [NVIDIA research publications](https://research.nvidia.com/labs/rtr/publication/)

### Inferences
- **Where the neural layer meets path tracing:**
  - an own NRC-style online MLP over KHR coopmat — cross-vendor, Linux and Windows, needs the Vulkan renderer or bridge;
  - optionally DLSS RR as an NVIDIA-only replacement denoiser (NGX on Linux, Streamline or NGX on Windows; needs albedo, specular albedo, normal/roughness, depth and motion vectors);
  - FSR Ray Regeneration and Radiance Caching are not reachable from a Vulkan/Linux engine today.
- **The G-buffer contract overlaps.** DLSS RR's required inputs (albedo, specular albedo, normals/roughness, depth, motion vectors) are a superset of what a native generative NR pass would want. Building that G-buffer once (Roadmap NR-2 plus the PT branch) serves the denoiser, the NR network, and our own training-data capture.
- **NRC's cost on RDNA3/Xe2 through KHR coopmat is unmeasured.** Training every frame is the expensive part, and VkNRC's author found KHR coopmat "too limited" for a fully-fused MLP. The `VK_EXT_cooperative_matrix_maintenance1` and the planned EXT for coopmat2 features may close that gap; this is speculative.

### Gaps
- No measured ms costs on mid-range GPUs were found for DLSS RR, FSR Ray Regeneration, NRC or VkNRC.
- Intel's plan to ship a neural denoiser (XeSS or otherwise) is unknown.
- No production-ready, cross-vendor neural path guiding implementation was found.
