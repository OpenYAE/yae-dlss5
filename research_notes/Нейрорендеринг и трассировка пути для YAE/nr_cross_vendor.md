# DLSS 5 Neural Rendering outside NVIDIA's runtime: ports, reimplementations and vendor-neutral GPU ML paths (status 2026-10-07)

**Tags.** These mark how much weight each statement can carry.
- **[V]** I verified it by reading the repository's code, docs or release metadata, or the GitHub, Hugging Face or Mesa sources, on 2026-10-06/07.
- **[M]** A measurement that the project itself published. I read it but did not reproduce it.
- **[C]** A claim: a user report, a press statement, or a developer statement with no data behind it.
- **[D]** My own arithmetic from the cited numbers.

**Conventions.**
- Dates are commit, release or publication dates.
- "dB" means PSNR against NVIDIA's own `nvngx_dlssnr.dll` 310.8.0 output, unless the line says otherwise. For scale, the unprocessed input frame scores 26–29 dB against NVIDIA's output.
- Licences are given as plain facts. Licence conflicts are out of scope.
- The NVIDIA-official side (the DLSS 5 product, Streamline, RenoDX and the injection tools) is covered elsewhere. It appears here only where a port depends on it.

---

## 1. Which ports and reimplementations exist, and how they compare: GPUs, API, precision, performance, fidelity, openness, activity, integration and Linux

### Takeaway

On 2026-10-07 the network runs in real time outside NVIDIA's runtime on three GPU families.

- **AMD RDNA4** is the best covered.
  - mochizuki0323/DLSSNR-AMD (MIT, Vulkan FP8) takes 5.6 ms at 1080p on an RX 9070 XT under Linux and 7.2 ms under Windows, and scores 45.6–49.1 dB.
  - lmxxf (MIT, HIP) takes about 9.8 ms and scores 47.55 dB.
  - danielblnc (closed, HIP) is the most widely used.
- **AMD RDNA3:** mauri870/DLSSNR-RDNA3 (MIT, Vulkan FP16 with E4M3 emulation, Linux only) takes 15 ms at 1080p on an RX 7900 XTX and scores 45.5 dB. danielblnc's closed runtime takes about 27–35 ms on Windows.
- **NVIDIA Ada:** maanHimself/OpenDLSS-NR (MIT, Vulkan plus PTX, FP8) takes 7.8 ms at 1080p on an RTX 4070 SUPER. It is the only port that is bit-exact at speed, because it uses the same tensor-core instruction as NVIDIA.

Everything else works but is slow:

| GPU line | Port | Time |
|---|---|---|
| Intel Xe2 | Vulkan cooperative matrix FP16 | B580: about 40–53 ms at 720p |
| Intel Alchemist | SYCL | A770: 54 ms at 1280×704 |
| AMD RDNA2 | danielblnc 0.6.0 and an open INT8/FP16 OptiScaler fork | Playable only with a reduced model resolution and frame generation |
| RTX 20/30/40 | Patched "approx-fp16" official DLL | No published timings |
| RTX 20/30/40 | Open references (WebGPU, SM75 CUDA) | 0.4–1 s per frame at 720p |

Bit-exactness and speed exclude each other on non-NVIDIA hardware:
- Every real-time AMD or Intel port uses the hardware's FP32 accumulation and lands at 45–49 dB against NVIDIA.
- Exact emulation of NVIDIA's FP8 accumulation exists only as slow reference code: the WebGPU port, lmxxf's SM 6.10 chain at 186 ms, and an SM75 CUDA port at about 1 s.

### Cited Findings

#### 1a. Facts about the network that every port depends on

- [V] **Structure.**
  - A 71-block U-net of shifted-window (Swin, 8×8) transformer blocks with a global ViT at the bottom, over six pooling levels.
  - FP8 E4M3 activations with FP16 accumulation; 141 MiB of weights.
  - Input and output are the same resolution; it is "not an upscaler".
  - Inputs: an LDR proxy of the frame, three lanes of Gaussian noise, the reprojected previous output, and five conditioning scalars.
  - Output: four f32 channels per pixel, an RGB residual plus a temporal-blend logit.
  - Source: OpenDLSS-NR README, last commit 2026-09-21 — [OpenDLSS-NR](https://github.com/maanHimself/OpenDLSS-NR)
- [M] **Arithmetic per frame.**

  | Resolution | Padded field | GFLOP |
  |---|---|---|
  | 512×512 | 576×512 | 139 |
  | 768×768 | — | 297 |
  | 1920×1080 | 1920×1152 | 1021 |
  | 2560×1440 | 2560×1472 | 1730 |
  | 3840×2160 | 3840×2176 | 3907 |

  Each pyramid level carries 11–18% of the FLOPs. On an RTX 4070 SUPER the network becomes compute-bound from 1080p upward, at about 131–137 TFLOP/s, which is "roughly half the part's dense FP8 tensor rate". — [execution.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/execution.md)
- [V] **Weight format.**
  - The weights are the PE resource `WEIGHTS_HT` in `nvngx_dlssnr.dll` 310.8.0.0 (SHA-256 `e16bcf15…`): 153 records.
  - The matrices are E4M3 in the tiled layouts the DLL's kernels read. Per-channel gains, scales and attention-bias tables are FP16.
  - The 310.8.0.0 version and the `e16bcf15…` hash are the ones every port requires.
  - mochizuki's extractor checks 599 entries totalling 140.9 MiB and refuses any other DLL version.
  - Sources: [DLSSNR-SYCL-Bridge](https://github.com/MakeDecisionWorth/DLSSNR-SYCL-Bridge); [DLSSNR-AMD](https://github.com/mochizuki0323/DLSSNR-AMD)
  - An early analysis (2026-09-05) called the weights a "Mixed FP8 core / FP16 conv shell, ~146.1M parameters". The "FP16 shell" part conflicts with the later readings above; treat it as probably superseded. — [windystrife/dlssnr-re](https://github.com/windystrife/dlssnr-re)
- [V] **Why bit-exactness is hard.**
  - Every FP8 GEMM is a chain of 16×16×32 multiplies, E4M3 × E4M3 → f16, using `mma.sync.aligned.m16n8k32.row.col.f16.e4m3.e4m3.f16`.
  - Each k32 step is two groups of 16 products. They are summed in fixed point with 13 fractional bits, truncated relative to the largest exponent, and then rounded to f16.
  - The K order is part of the result.
  - Values are published f32 → f16 → E4M3 with round-to-nearest-even and saturation at 448. NaN publishes as +0, and the sign of zero is kept.
  - Source: [numerics.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/numerics.md)
- [V] **The noise lanes are vendor-specific.** NVIDIA builds the three noise lanes with hardware approximate `log2`/`cos`/`sin`, which are "not the same functions from one vendor to the next". So bit-exactness on other vendors is not guaranteed even at the input. — [WebGPU port README](https://github.com/maanHimself/OpenDLSS-NR/blob/main/ports/browser-webgpu/README.md)
- [C] NVIDIA describes the model as "a one-step pixel-space diffusion model". — [NVIDIA DLSS 5 report page, 2026-09-01](https://research.nvidia.com/labs/adlr/DLSS5/)
- [C] **The official DLL may be Blackwell-only.** An OpenDLSS-NR issue commenter (2026-10-06) reports:
  - The signed 310.8.0 DLL embeds 15 cubins, all `sm_120`, with no PTX.
  - It carries the string `DLSSNR: Unsupported GPU architecture 0x%x, minimum required 0x%x`.
  - On an RTX 4080 Laptop, the official path silently returned its input.
  - Source: [OpenDLSS-NR #3](https://github.com/maanHimself/OpenDLSS-NR/issues/3)

#### 1b. AMD RDNA4 (RX 9070 / 9060)

**mochizuki0323/DLSSNR-AMD.** MIT. 83★. Latest GitHub release v0.0.3 (2026-10-01).
- [V] **Implementation.**
  - Vulkan compute in GLSL. FP8 matrix multiplication goes through `VK_KHR_cooperative_matrix` + `VK_EXT_shader_float8`, which "compile to the RDNA4 WMMA instructions".
  - Precision follows NVIDIA operation by operation: FP8 where NVIDIA uses FP8, FP16/FP32 elsewhere.
  - Sources: [ARCHITECTURE.md](https://github.com/mochizuki0323/DLSSNR-AMD/blob/main/docs/ARCHITECTURE.md); [releases](https://github.com/mochizuki0323/DLSSNR-AMD/releases)
- [V] **Platforms.**
  - Linux is the main version: Mesa ≥ 26.2 and GE-Proton 11-7.
  - Windows is an "experimental preview": AMD Software ≥ 25.10, with "Game crashes, driver resets" possible.
  - RX 9000 only; tested on an RX 9070 XT. RX 7000 "lack[s] the FP8 matrix instructions".
  - The AMD Windows driver exposes the same two extensions, so both platforms share the same shaders.
  - Sources: [README](https://github.com/mochizuki0323/DLSSNR-AMD); [ARCHITECTURE.md](https://github.com/mochizuki0323/DLSSNR-AMD/blob/main/docs/ARCHITECTURE.md)
- [V] **Integration routes.**
  - `optiscaler` uses OptiScaler-NR as host, 64-bit only. The other routes are `reshade`, `vulkan` (ReShade as a Vulkan layer under DXVK) and `dx9`.
  - OpenGL is not supported.
  - 32-bit games work on Linux through an i686 package.
  - Source: [README](https://github.com/mochizuki0323/DLSSNR-AMD)
- [M] **Network-only time on an RX 9070 XT (v0.0.3).**

  | Platform | 1080p | 1440p | 4K |
  |---|---|---|---|
  | Linux | 5.60 ms | 9.70 ms | 21.89 ms |
  | Windows | 7.21 ms | 12.59 ms | 27.32 ms |

  Source: [README](https://github.com/mochizuki0323/DLSSNR-AMD)
- [M] **In game (Linux, 4K output, FSR4 Performance).**

  | Game | No NR | NR before upscaler | NR after upscaler |
  |---|---|---|---|
  | 007 First Light | 126 fps | 68 fps | 30 fps |
  | KCD2 | 85 fps | 54 fps | 27 fps |
  | Dying Light: The Beast | 97 fps | 56 fps | 27 fps |

  Source: [README](https://github.com/mochizuki0323/DLSSNR-AMD)
- [M] **Fidelity against NVIDIA's DLL on an RTX 5090 through NGX.**

  | | 1080p | 1440p | 4K |
  |---|---|---|---|
  | Single frames, PSNR | 45.56 dB | 47.99 dB | 49.06 dB |
  | Motion sequences, PSNR | 46.3–47.0 dB | 50.1–50.9 dB | 51.1–51.6 dB |

  SSIM is 0.996–0.997 on single frames. NVIDIA's output is byte-identical from run to run. — [NGX-VERIFICATION](https://github.com/mochizuki0323/DLSSNR-AMD/blob/main/docs/ngx-verification/NGX-VERIFICATION.md)
- [M] **Windows differs from Linux.** On a 1080p frame the two outputs are 48.6 dB apart, because the Windows driver's shader compiler rounds differently. The first build takes about a minute on Windows against 10–20 s on Linux. — [README](https://github.com/mochizuki0323/DLSSNR-AMD)
- **The same runtime packaged elsewhere.**
  - [M] The OptiScaler AMD fork ships it as `MochizukiNrRuntime.dll`: "about 8.5 ms per frame at 1080p" on an RX 9070 XT. — [neural-amd-opti](https://github.com/MatheusFerreiraS/neural-amd-opti)
  - [M] zmodelerlover measured 6.8, 11.7 and 17.3 ms for one, two and three passes on a 960×540 frame. Against danielblnc's runtime it shows a colour cast of red −0.029 and blue +0.039. — [README](https://github.com/zmodelerlover/dlss5-neural-amd)
  - [V] "mochizuki 0.4.10-amd-nr … builds again on AMD driver 32.0.32015" (2026-10-04), so a driver update had broken the build. — [CHANGELOG](https://github.com/zmodelerlover/dlss5-neural-amd/blob/master/CHANGELOG.md)

**lmxxf/dlss5-on-amd-9070xt-porting.** MIT. 138★. No GitHub releases; downloads are on Quark, Gofile and Google Drive. Current release 0.41 (2026-10-05); last push 2026-10-06.
- [V] **Implementation.**
  - 38 HIP modules per architecture: gfx1201 (tested) and gfx1200 (included but untested).
  - Runs on the HIP 7 runtime that ships in the AMD driver: "No HIP SDK, no Agility SDK, no preview DXC".
  - Windows only.
  - Packages: OptiScaler, Magpie, and OptiScaler-REFramework (for RE9).
  - Source: [README](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)
- [M] **Offline whole-network time (RX 9070 XT).**

  | Tier | 1 pass | 2 passes | 3 passes |
  |---|---|---|---|
  | 900 (1600×960) | ≈7.0 ms | 13.7 ms | 20.4 ms |
  | 1080 (1152 rows, NVIDIA's geometry) | ≈9.8 ms | 19.5 ms | 29.0 ms |

  - VRAM is about 1.2 GB at 900p.
  - Stellar Blade at 2K runs 57 / 37 / 27 fps with 1 / 2 / 3 passes (0.40, 2026-10-03).
  - Source: [README](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)
- [M] **Fidelity (1080p single frame, Style 0).**
  - Default (all 71 blocks with `FAST_NUMERIC=1`): 47.55 dB.
  - Bit-exact numerics: 47.43 dB.
  - Optional block skip: 44.26 dB.
  - 1088-row geometry (the one danielblnc and mochizuki use): 45.8 dB.
  - Fast numerics against the project's own exact chain: 51.8–55.5 dB.
  - Source: [README](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)
- [V/M] **History.** Versions 0.01–0.15 (2026-09-08 to 09-14) ran the network as **D3D12 Shader Model 6.10 wave-matrix shaders**. Those 53 files are kept in `shaders/dx12-network/` as "the bit-exact reference chain".
  - The stack needed:
    - preview DXC 1.10.2605.24
    - Agility SDK 1.721.3-preview
    - AMD release-candidate "Agility SDK" driver 26.10.07.02 (32.0.31007.2048)
    - Windows Developer Mode
  - v0.01: "bit-for-bit equal to the original network for 15 frames", with a 186 ms bench.
  - v0.02: switched to "FP32 hardware accumulation" and took 112 ms.
  - 0.20 (2026-09-17): moved to HIP, "bit-identical with the DX12 chain", about 8% faster.
  - Source: [README](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)

**danielblnc/DLSS-NR-on-AMD.** Closed binary. 2,367★, 180 open issues, 26 releases since 2026-09-03; latest v0.6.0 (2026-10-03).
- [V] **Licence.** "All rights reserved". Personal non-commercial use only; no redistribution and no reverse engineering. — [LICENSE](https://github.com/danielblnc/DLSS-NR-on-AMD/blob/master/LICENSE)
- [V] **Implementation.**
  - A `version.dll` proxy that hooks FSR in DX12 games and runs HIP kernels. Windows 11; Adrenalin ≥ 26.1.1.
  - "No NVIDIA code is included or translated at runtime"; it is "a ground-up, full reimplementation".
  - Source: [README](https://github.com/danielblnc/DLSS-NR-on-AMD)
- [V] **Inside the binary.** A clang offload bundle with nine AMDGPU code objects, including gfx1201, gfx1200 and gfx11-generic. It has 34 named kernels (`k_swin_var32/64/128/256`, `k_qkv_attn`, …). Analysed 2026-09-22. — [zmodelerlover spike-rocm](https://github.com/zmodelerlover/dlss5-neural-amd/blob/master/docs/spike-rocm/README.md)
- [V] **RDNA2.** Supported since v0.6.0 (2026-10-03). RDNA2 needs the "AMD HIP 7.2 runtime", because RX 6000 drivers ship HIP 6.4 only. — [v0.6.0](https://github.com/danielblnc/DLSS-NR-on-AMD/releases/tag/v0.6.0); [zmodelerlover README](https://github.com/zmodelerlover/dlss5-neural-amd)
- [M/C] **Release-note history.**

  | Version, date | What the notes say |
  |---|---|
  | v0.2.0 | 1080p "From 10 to 23 fps" |
  | v0.2.7 | Cyberpunk "playable at 30 fps at 1080p on a 9070 XT" |
  | v0.3.0, 09-12 | Adds pre-upscale mode. Cyberpunk 1080p Ultra: native 30, FSR Quality 57, Balanced 67, Performance 71 fps; with path tracing 19 / 37 / 43 / 50 |
  | v0.4.2, 09-27 | Adds **Fast** (cheaper arithmetic) and **Reference** ("NVIDIA's exact arithmetic") modes; "RX 7000 always runs Reference" |
  | v0.4.3, 09-28 | "75 FPS in Cyberpunk @ 1080p, 9070 XT Fast mode" |
  | v0.5.0, 09-29 | RX 7000 "Up to 207%" |
  | v0.5.1 | RDNA4 +8% (Fast) and +6% (Reference) |

  Source: [releases](https://github.com/danielblnc/DLSS-NR-on-AMD/releases)
- [C] **Out-of-date README.** The README (pushed 2026-10-01) still says "roughly 33 FPS at 1080p on an RX 9070 XT", "Older GPUs are not currently supported" and "Vulkan is planned". The 75 FPS release note and v0.6.0's RDNA2 support **supersede** this. It also claims "very similar" quality but publishes no metric. — [README](https://github.com/danielblnc/DLSS-NR-on-AMD)
- [C/M] **Other measurements.**
  - Fast mode is "about 13 to 15% faster on RX 9000".
  - The RDNA3 builds keep a half-precision copy of the weights, about 280 MB more VRAM per pass.
  - Source: [zmodelerlover README](https://github.com/zmodelerlover/dlss5-neural-amd)
  - TheAutomatic's measurement (historical, version not stated): the danielblnc backend network takes "~12–13 ms @ 720p". Multi-slot scheduling raised a 4K FSR Ultra Performance test from 33.5 to 44.5 fps. — [README.en](https://github.com/TheAutomatic/dlss-5-amd-project/blob/main/README.en.md)

**guentra/dlss5-amd-hip-linux.** MIT; the vkd3d-proton changes are LGPL. Last release v0.2.6.1 (2026-09-22); inactive since.
- [V] **Implementation.**
  - Native Linux HIP/rocWMMA for gfx1200 and gfx1201, with a ReShade add-on, a Wine bridge and a modified vkd3d-proton.
  - It needs ROCm/HIP 7.
  - The network runs at a fixed 1920×1080 internally.
  - History is reset every frame, so it is "not temporally complete".
  - It uses CPU readback and upload.
  - Source: [README](https://github.com/guentra/dlss5-amd-hip-linux)
- [M] **Performance.** About 25 ms offline at 1080p (down from 210–216 ms in 0.1.0-poc). SILENT HILL f runs at about 25–28 fps. It is "bit-exact" only relative to its own reference network. — [README](https://github.com/guentra/dlss5-amd-hip-linux)

**xXJSONDeruloXx: dlssnr-proton and dlssnr-native.** GPL-3.0, 2026-09-05. Both take a model file named `nvngx_dlssnr.approx-fp16-sm_75-sm_86-sm_89-sm_120.dll`.
- [M] **dlssnr-proton:** RDNA4 on SteamOS 3.8. Asynchronous CPU staging; neural updates take 55–65 ms and "visibly lag moving gameplay". — [dlssnr-proton](https://github.com/xXJSONDeruloXx/dlssnr-proton)
- [V] **dlssnr-native:** a preview of a native Vulkan backend with a PTX compiler frontend. It passes 512/512 FP16/FP8 layout checks on an RX 9070 XT, but "104 kernels still stop at unsupported memory-barrier operations". — [dlssnr-native](https://github.com/xXJSONDeruloXx/dlssnr-native)

#### 1c. AMD RDNA3 and RDNA3.5

**mauri870/DLSSNR-RDNA3** (branch `rdna3` of a fork of mochizuki's project). MIT. Releases 0.0.3 to 0.0.3.2 (2026-10-02 to 10-04).
- [V] **Implementation.**
  - Vulkan GLSL. Linux and Proton only; `windows/` is not ported.
  - Tested only on an RX 7900 XTX with Mesa 26.2.3 RADV.
  - The E4M3 values are held as FP16, which is exact. Matrix work uses the FP16 WMMA with FP32 accumulation.
  - The E4M3 rounding (round-to-nearest-even plus saturation at 448) is emulated in ALU code by adding and subtracting a "magic constant".
  - It keeps an FP16 twin of the activations and the weights.
  - Source: [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
- [M] **Network time on the RX 7900 XTX.**

  | | 720p | 1080p | 1440p | 4K |
  |---|---|---|---|---|
  | Current | 8.5 ms | 15 ms | 26 ms | 56 ms |
  | First working version | — | 30 ms | 54 ms | 116 ms |

  - That is about 2.6× the RDNA4 cost.
  - VRAM at 4K is 5.3 GB, twice what the RDNA4 build uses.
  - Source: [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
- [M] **Fidelity.** 45.47 dB at 1080p, 47.71 dB at 1440p and 49.02 dB at 4K, against 45.56 / 47.99 / 49.06 dB for the RDNA4 build. Motion sequences were not run. — [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
- [M] **4K at reduced model resolution.**

  | Model scale | Time | PSNR against NVIDIA's full-resolution output |
  |---|---|---|
  | 75% | 34 ms | 39.39 dB |
  | 50% | 16 ms | 35.29 dB |
  | 37.5% | 11 ms | 33.83 dB |
  | 25% | 8 ms | 32.66 dB |

  Source: [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
- [M] **Limits.**
  - The network is about 3.5 TFLOP at 4K, against a 123 TFLOPS matrix peak; the floor is about 28 ms, or 38 ms at 75% efficiency.
  - On RDNA3, matrix and vector instructions do not overlap.
  - Register spills were the main cost.
  - Source: [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)

**danielblnc's runtime on RDNA3.**
- [C] v0.3.1 took about 72 ms per job on an RX 7900 XTX, "~2.5x slower than RDNA4" (2026-09-17). — [#182](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/182)
- [M] Later, through A-ENTROPY's Magpie fork (2026-10-02): 27–35 ms per frame at 1080p on the 7900 XTX, with the frame rate capping near 33 fps. — [magpie-dlss5-amd](https://github.com/A-ENTROPY/magpie-dlss5-amd)

**A-ENTROPY/magpie-dlss5-amd.** GPL-3.0 fork of Magpie. Release v0.6.8.5-amd-rdna3 (2026-10-02).
- [V] It captures a window and serves the DLSSNR effect with danielblnc's runtime through a D3D12 + HIP backend.
- [V] Known limits: the effect drops out under load, it crashes when DLSSNR and XeFG 4x are on together, and only RDNA3 has been tested.
- Source: [README](https://github.com/A-ENTROPY/magpie-dlss5-amd)

**RDNA3.5.**
- [C] Radeon 890M (gfx1150, v0.2.16): the log shows "network job 1 done in 93 ms" at 1080p. — [#186](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/186)
- [C] Radeon 8060S: "Not working" (2026-09-27). — [#207](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/207)

**PyTorch reference on RDNA3.**
- [M] mauri870/dlssnr-pytorch with Triton kernels on ROCm, RX 7900 XTX: 0.19 / 0.33 / 0.77 s at 1080p / 1440p / 4K. — [dlssnr-pytorch](https://github.com/mauri870/dlssnr-pytorch)

#### 1d. AMD RDNA2 (no WMMA)

- **danielblnc v0.6.0** (2026-10-03).
  - [C] RX 6600: "I am getting 5fps" (2026-10-06). — [#235](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/235)
  - [C] RX 6800 XT: "HIP device enumeration failed" (2026-10-05). — [#233](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/233)
  - [C] RX 6900 XT: Cyberpunk at about 35 fps with frame generation, "technically… 17-18 fps" without (2026-09-29). — [#149 comment](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/149)
- **shakhbazian/OptiScaler-RDNA2NR.** GPL-3.0. Releases r1 to r3 (2026-10-01 to 10-04).
  - [V] A HIP backend for gfx1030 only, not gfx1031/1032.
  - [V] "selected matrix operations in INT8 and the remaining paths in FP16".
  - [V] It uses the **HIP 6** runtime from the RX 6000 driver.
  - [V] DX12 is supported, and DX11 through OptiScaler's bridge. There is no Vulkan path.
  - [V] The converted model is about 278 MiB.
  - [C] A user test on an RX 6900 XT reached "approximately 45 FPS at 1440p with XeFG", with FSR3 Performance and the model at 75% before upscaling.
  - Source: [OptiScaler-RDNA2NR](https://github.com/shakhbazian/OptiScaler-RDNA2NR)
- **philippraschke75-spec/gfx1030-dlss-nr-translation-lab.** No licence.
  - [M] danielblnc's gfx1100 kernels were translated to gfx1030 by disassembly.
  - [M] On an RX 6900 XT a full captured Cyberpunk frame renders "correctly end to end" (2026-09-25), with structural correlation 0.925.
  - [M] "a full frame currently takes several hundred ms of GPU time".
  - Source: [translation-lab](https://github.com/philippraschke75-spec/gfx1030-dlss-nr-translation-lab)
- **Sakushey/gfx1030-dlss-nr-research.** Apache-2.0. A research method (emulator, ISA oracle, HIP interop). "No GTA frame was captured". — [repo](https://github.com/Sakushey/gfx1030-dlss-nr-research)
- **TripleZer000/gfx1032-dlss-nr-research** (RX 6600, 2026-09-21). It loads in GTA V; correctness is unvalidated. — [repo](https://github.com/TripleZer000/gfx1032-dlss-nr-research)

#### 1e. Intel Arc

**Uzbekunknown/dlss-nr-on-intel.** Apache-2.0. 56★. No releases; last push 2026-10-05.
- [V] **Implementation.**
  - An independent reimplementation on Vulkan `VK_KHR_cooperative_matrix`: FP16 × FP16 → FP32, with M=8, N=16, K=16.
  - **Xe2 only.** "Arc A-series (Alchemist) does not qualify: its matrix units report 8x8x16".
  - Injection is a Vulkan layer at `vkQueuePresentKHR` plus a daemon.
  - Linux Mesa ANV is the main platform. On Windows, Intel's driver produces "the same [output] … bit for bit".
  - It is written by AI: "Claude Opus 5 and 5.5".
  - Source: [README](https://github.com/Uzbekunknown/dlss-nr-on-intel)
- [M] **Arc 140V (Lunar Lake), live round trip (2026-09-27).**

  | Swapchain | Render scale | Time |
  |---|---|---|
  | 640×360 | 0.5 | 27 ms |
  | 1024×768 | 0.55 | 56 ms |
  | 1920×1080 | 0.55 | 112 ms |

  - 1080p at full scale runs at about 3 fps.
  - Tekken 7 runs at "30 fps at 800x450".
  - Memory: 0.7 GiB at 720p and 1.3 GiB at 1080p.
  - Source: [README](https://github.com/Uzbekunknown/dlss-nr-on-intel)
- [M] **Arc B580 on Windows, 1280×720.**
  - Host feature build: 12–14 ms.
  - Graph: **50–53 ms**.
  - Compose: 3.2 ms.
  - The staged GEMM runs at 5.5–15 TFLOP/s. The 140V runs at 3.5–3.8 TFLOP/s against an FP16 peak of about 32 TFLOP/s.
  - Source: [PERF-WINDOWS.md](https://github.com/Uzbekunknown/dlss-nr-on-intel/blob/master/docs/PERF-WINDOWS.md)
- [M] **Fidelity.** Compared with OpenDLSS-NR, "what is left between the two is rounding, not structure". No PSNR against NVIDIA is published. — [README](https://github.com/Uzbekunknown/dlss-nr-on-intel)

**gggz114514-oss/dlss5nr-b580-intelarc.** No licence. v0.1.0-pre (2026-09-09); README updated 2026-10-03.
- [M] Torch XPU / Triton-XPU backend on an Arc B580 at 720p:
  - Offline: about 45–46 ms; the GPU body takes 39–40 ms.
  - Cyberpunk with frame generation off: users accepted a base frame time of 55–60 ms. It has not reached 720p at 30 fps.
- [M] The exact backend is byte-identical only for the frozen RTX 4060 reference inputs. The fast version drops the FP8 activation-rounding emulation. The INT8 experiments were not adopted.
- Source: [repo](https://github.com/gggz114514-oss/dlss5nr-b580-intelarc)

**MakeDecisionWorth/DLSSNR-SYCL-Bridge.** MIT. v0.1.1 (2026-09-30).
- [V] **Implementation.**
  - The original network in SYCL, built with oneAPI DPC++ 2026.1, running on Intel GPUs through OpenCL devices.
  - **Tested on Alchemist A770 and A750**, driver 32.0.101.9033, on Windows.
  - It serves frames asynchronously as OpenNR's "teacher model". It is "not for playing".
- [M] **Performance.**
  - 1280×704: A770 54 ms (while also driving the display), A750 57 ms.
  - 1728×704: 72 ms and 74 ms.
  - One A750 delivers 12 new pictures/s; an A750 plus an A770 deliver 23/s.
- Source: [README](https://github.com/MakeDecisionWorth/DLSSNR-SYCL-Bridge)

#### 1f. NVIDIA RTX 20/30/40 outside the official runtime

- [C] **Modified builds (Guru3D, 2026-08-31).**
  - ShortFuse made modified DLSS-NR builds for RTX 20/30/40.
  - The early FP8 experiments on Ampere showed "severe performance reductions"; later builds use FP16.
  - Game results were mixed: Red Dead Redemption worked, RDR2 failed, and Hogwarts Legacy got stuck in standby.
  - GTA V "ran for approximately ten seconds before the test system lost its display signal".
  - No performance data.
  - Source: [Guru3D](https://www.guru3d.com/story/leaked-dlss-5-runs-on-rtx-20-and-rtx-30-gpus/)
- [V] **The patched build in circulation.** It is named `nvngx_dlssnr.approx-fp16-sm_75-sm_86-sm_89-sm_120.dll` (SHA-256 `dcc0dc24…`). — [dlssnr-native](https://github.com/xXJSONDeruloXx/dlssnr-native)
  - zmodelerlover recorded NGX parameters with "the pre-RTX-50 patched build" on an RTX 3050 Laptop (2026-09-21). No timing was given. — [nvidia-parity.md](https://github.com/zmodelerlover/dlss5-neural-amd/blob/master/docs/nvidia-parity.md)
- **dev-camo/dlssnr-patcher.** GPL-2.0. Last push 2026-09-03.
  - [V] Requires CUDA Toolkit 13.3. It works only when the fatbin has "Exactly one" PTX image.
  - [V] It rewrites the E4M3 `cvt` instructions into exact integer code.
  - [V] It replaces `mma.sync…m16n8k32…e4m3` with FP16 `m16n8k16` MMAs, or `m16n8k8` on Turing.
  - [V] It lowers bulk copies and mbarriers; Turing gets synchronous loads.
  - [V] It patches the architecture requirement and strips the signature.
  - No performance data.
  - Sources: [README](https://github.com/dev-camo/dlssnr-patcher); [dlssnr_patcher.py](https://github.com/dev-camo/dlssnr-patcher/blob/main/dlssnr_patcher.py)
  - **Conflict:** this design needs PTX in the DLL, but the OpenDLSS-NR #3 commenter says the signed 310.8.0 build has none (see 1a).
- **OpenDLSS-NR** (MIT; 824★; no releases; last commit 2026-09-21).
  - [M] RTX 4070 SUPER: 2.83 ms at 768², **7.77 ms at 1080p**, 12.6 ms at 1440p and 29.3 ms at 4K, with 241 dispatches.
  - [V] Windows only. It requires Ada or newer, plus `VK_KHR_cooperative_matrix`, `VK_NV_cooperative_matrix2`, `VK_EXT_shader_float8` **and** `VK_NV_cuda_kernel_launch`; the PTX route is the one that runs.
  - [M] It claims bit-exactness at all 75 block boundaries at 512². Fixtures from 644×768 up to 4K match on the composed output.
  - Source: [README](https://github.com/maanHimself/OpenDLSS-NR)
  - [C] Open issue: on an RTX 4080 Laptop, the head of the fused route is red-biased while the reference route is fine (2026-10-04 to 10-06). — [#3](https://github.com/maanHimself/OpenDLSS-NR/issues/3)
- **apiplant/opendlss-rs.** No licence file; v0.1.2 (2026-10-02).
  - [M] Runs the upstream PTX through the CUDA driver API on Linux. RTX 4090, end to end: 5.8 ms at 1080p and 21 ms at 4K.
  - [M] Its wgpu route takes 315 ms at 2048×1152.
  - Source: [opendlss-rs](https://github.com/apiplant/opendlss-rs)
- [M] **OpenDLSS-NR draft PR #6** (2026-10-06): an SM75 CUDA compatibility backend for Linux, tested on an RTX 2060.
  - Weights in FP16, with the E4M3 publication and the F13/F24 reductions done in software.
  - It matches the browser arithmetic exactly.
  - About 1019.9 ms per call at 720p, including upload and readback, "without a real-time performance claim".
  - Source: [PR #6](https://github.com/maanHimself/OpenDLSS-NR/issues/6)
- [M] **WebGPU on an RTX 3060 Ti** (Chrome, D3D12): the reference WGSL takes 123.4 ms at 512² and 412.2 ms at 1280×720; the TSL port takes 201.2 and 658.6 ms. — [three-dlss-nr](https://github.com/bhouston/three-dlss-nr)

#### 1g. Platform-neutral references: WebGPU, CUDA-to-WGSL, PyTorch, ONNX, MLX, CPU

- **OpenDLSS-NR browser port.**
  - [M] Bit-exact on 75 boundaries plus the head, on an RTX 4070 SUPER.
  - [M] 72–73 ms at 512², against 2.7 ms for Vulkan on the same card. It uses 451 dispatches and needs `shader-f16` plus 32 KB of workgroup storage.
  - [M] In the demo, a 1904×929 frame costs about 465 ms.
  - Source: [WebGPU README](https://github.com/maanHimself/OpenDLSS-NR/blob/main/ports/browser-webgpu/README.md)
- **bhouston/three-dlss-nr.** The README says MIT; GitHub reports NOASSERTION. 2026-10-05.
  - [V] Three.js TSL compute with no CPU readback. It does not need `shader-f16`. It is bit-exact against the reference WebGPU port.
  - [M] Activations take 545 MiB at 512² and 1905 MiB at 720p.
  - Source: [three-dlss-nr](https://github.com/bhouston/three-dlss-nr)
- **SamG-Coder/OpenDLSS-NR-WebCuda.** MIT; parked 2026-09-22.
  - [M] CUDA kernels compiled to WGSL, emulating Ada's F13/F24 accumulation.
  - [M] RTX 5080 in Edge: 720p went from 195 to 158 ms, 1080p from 417 to 334 ms.
  - Source: [WebCuda](https://github.com/SamG-Coder/OpenDLSS-NR-WebCuda)
- **mauri870/dlssnr-pytorch.** MIT, 2026-10-02.
  - [M] 45.70 / 48.26 / 49.10 dB at 1080p / 1440p / 4K.
  - [M] CPU with 16 threads: 21 / 40 / 90 s. ROCm Triton on a 7900 XTX: 0.19 / 0.33 / 0.77 s.
  - [V] The CUDA build "has not been tried on an NVIDIA card".
  - [V] It includes INT8-simulation and ablation scripts.
  - Source: [dlssnr-pytorch](https://github.com/mauri870/dlssnr-pytorch)
- **iamwavecut/MLX-DLSS.** Apache-2.0; last push 2026-09-10.
  - [V] Runs on Apple MLX/Metal, PyTorch and Core ML.
  - [M] Error against NVIDIA: 0.004–0.005 MAE (Core ML: 0.008–0.014).
  - [M] An M2 Max processes 18.4–20.1 input frames/s at 512×384 (temporal video).
  - Source: [MLX-DLSS](https://github.com/iamwavecut/MLX-DLSS)
- **taowen/dlss5-onnx** (Hugging Face, 2026-09-09).
  - [V] **The only ONNX export found.** Static 256×256 input. The ONNX files embed the weights.
  - [V] Three variants:
    - a reference model with FP64 reductions and emulated FP8
    - an AMD FP16 variant, 301 MB
    - an INT8-ViT variant, 234 MB
  - [M] ONNX Runtime with MIGraphX on a Radeon 890M (ROCm 6.4.2): **161.5 ms (FP16) and 176.5 ms (INT8)** per 256² image.
  - [V] "CUDA and DirectML performance has not been measured".
  - Source: [dlss5-onnx](https://huggingface.co/taowen/dlss5-onnx)
- **Other references.**
  - [V] inarikami (Hugging Face, 2026-09-22): PyTorch numerical and differentiable references, plus PTX tools. — [repo](https://huggingface.co/inarikami/dlss5-nr-reverse-engineering)
  - [V] Loong0x00/ExactNR71 (2026-09-17): a NumPy reconstruction, labelled "AI-assisted, untrusted research artifact". — [repo](https://github.com/Loong0x00/dlssnr-exact71-transparent)
  - [V] OpenDLSS-NR's CPU reference covers block 0 only. — [numerics.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/numerics.md)
- **Unverified claims.**
  - [C] romangalaxys10-spec/OpenDLSS-NR-MetalFX (MIT) claims Metal/MetalFX, D3D12 + DirectML and Vulkan backends. It is a single squashed commit (2026-09-27) with no published measurements. — [repo](https://github.com/romangalaxys10-spec/OpenDLSS-NR-MetalFX)
  - [C] andrewmd5/bgfx-dlss5-nr, an effect for Borderless Gaming, claims support "on more than just the latest NVIDIA GPUs". It has no licence and no technical detail. — [repo](https://github.com/andrewmd5/bgfx-dlss5-nr)

#### 1h. Hosts that run these runtimes (ReShade, OptiScaler, Magpie, Vulkan layers) and Linux shims

- **zmodelerlover/dlss5-neural-amd.** MIT ReShade add-on, v0.7.10 (2026-10-04). Its installer, AMD-NR-ReShade-Installer, is at v0.7.12 (2026-10-06).
  - [V] It drives danielblnc 0.4.1 to 0.6.0 (checked by hash) and mochizuki's runtime. Since installer v0.7.11, mochizuki is the default on RDNA4.
  - [V] GPU support: "RDNA2, RDNA3 or RDNA4 with the HIP 7 runtime". It "Does nothing on NVIDIA or Intel".
  - [V] Direct3D 11 works best and D3D12 works. D3D10, Vulkan and OpenGL are experimental. 32-bit D3D8/9/10/11 and OpenGL go through an x86 bridge.
  - [V] v0.7.8 (2026-10-02) added 32-bit OpenGL: "Colour only".
  - [V] Where a game has no motion vectors, it measures motion with FidelityFX optical flow.
  - Sources: [README](https://github.com/zmodelerlover/dlss5-neural-amd); [CHANGELOG](https://github.com/zmodelerlover/dlss5-neural-amd/blob/master/CHANGELOG.md); [installer releases](https://github.com/zmodelerlover/AMD-NR-ReShade-Installer/releases)
- **MatheusFerreiraS/neural-amd-opti.** GPL-3.0 OptiScaler fork, v0.4.11-amd-nr (2026-10-06).
  - [V] Offers danielblnc, lmxxf or mochizuki as the NR runtime, plus the FidelityFX denoiser as ray reconstruction. The mochizuki runtime runs on its own Vulkan device next to the game's D3D12 device.
  - Source: [repo](https://github.com/MatheusFerreiraS/neural-amd-opti)
- **TheAutomatic/dlss-5-amd-project.** "OptScaler(NR)" 1.10.3.1 (2026-10-06), forked from Matheus's work. GitHub detects no licence.
  - [V] Three backends, plus experimental SR → NR ordering.
  - Source: [README.en](https://github.com/TheAutomatic/dlss-5-amd-project/blob/main/README.en.md)
- **Other OptiScaler-related repos.**
  - [V] wilsjo2/OptiScaler-DLSSNR-PreSR-Multipass (GPL-3.0, v0.8.91, 2026-09-23) is the host for mochizuki's optiscaler route and for shakhbazian's fork. — [repo](https://github.com/wilsjo2/OptiScaler-DLSSNR-PreSR-Multipass)
  - [V] a756598009-cmyk/DLSS5-6x-AMD-OptiScaler (v10.4, 2026-10-06) is Chinese-community packaging that follows TheAutomatic's releases. — [repo](https://github.com/a756598009-cmyk/DLSS5-6x-AMD-OptiScaler)
  - [V] GoldenNights/AMD-NR-bridge (v0.4.0) lets danielblnc's runtime coexist with OptiScaler. — [repo](https://github.com/GoldenNights/AMD-NR-bridge)
- **Linux shims for danielblnc's Windows runtime.**
  - [V] Tagertswe (MIT): a Wine unixlib HIP shim, a patch adding `external_memory_fd` to vkd3d-proton, and a fix to `winevulkan`. Tested only with Cyberpunk on an RX 9070 XT (2026-09-18). — [repo](https://github.com/Tagertswe/dlssnr-on-amd-linux)
  - [V] bulacha3: v0.5.0 (2026-09-29). — [repo](https://github.com/bulacha3/DLSS-NR-on-AMD-Linux)
- **Multi-GPU.**
  - [V] maohgad-web/Neural-coprocessor (MIT ReShade add-on) runs NVIDIA's DLSS-NR on a second card while the first renders the game. — [repo](https://github.com/maohgad-web/Neural-coprocessor)
  - [M] The SYCL bridge alternates frames across several Arc cards (see 1e).

#### 1i. Summary table

Dates are latest release or push.

| Port | Licence | GPUs | API | Matrix precision | Network time (best published) | Fidelity vs NVIDIA | Latest | Host | Linux |
|---|---|---|---|---|---|---|---|---|---|
| OpenDLSS-NR | MIT | NVIDIA Ada+ | Vulkan + PTX (`VK_NV_cuda_kernel_launch`) | FP8 E4M3, f16 accumulation | 7.77 ms at 1080p (RTX 4070 S) | bit-exact (claimed, 75 boundaries) | commit 09-21 | standalone tool/library + Filament demo | no (Windows); opendlss-rs runs its PTX on Linux |
| mochizuki DLSSNR-AMD | MIT | RDNA4 | Vulkan cooperative matrix + float8 | FP8, FP32 accumulation | 5.60 ms (Linux) / 7.21 ms (Windows) at 1080p (RX 9070 XT) | 45.56 / 47.99 / 49.06 dB | v0.0.3, 10-01 | OptiScaler, ReShade, Vulkan layer | **yes (main)** |
| mauri870 DLSSNR-RDNA3 | MIT | RDNA3 | Vulkan cooperative matrix | FP16 with E4M3 emulation, FP32 accumulation | 15 ms at 1080p (RX 7900 XTX) | 45.47 / 47.71 / 49.02 dB | 0.0.3.2, 10-04 | as mochizuki | **yes (only)** |
| lmxxf | MIT | RDNA4 (gfx1201; gfx1200 untested) | HIP (earlier: D3D12 SM 6.10) | FP8 | ≈9.8 ms at 1080p, 1152 rows | 47.55 dB | 0.41, 10-05 | OptiScaler, Magpie, ReShade add-on | no |
| danielblnc | closed | RDNA4, RDNA3, RDNA2 (HIP SDK 7.2) | HIP + D3D12 interop | FP8 on RDNA4; FP16 copy on RDNA3 | ~75 fps Cyberpunk 1080p Fast (claim); 27–35 ms on 7900 XTX | no metric ("very similar") | v0.6.0, 10-03 | version.dll proxy + FSR hook | via community shims |
| guentra | MIT (+LGPL) | gfx1200/1201 | HIP/rocWMMA | FP8 | ~25 ms at 1080p | own-reference only | 09-22 (stale) | ReShade + Wine bridge | **yes** |
| shakhbazian RDNA2NR | GPL-3.0 | RDNA2 gfx1030 | HIP 6 | INT8/FP16 mix | not published (~45 fps at 1440p with frame gen and 75% model, user) | not published | 10-04 | OptiScaler fork | no |
| Uzbekunknown Intel | Apache-2.0 | Intel Xe2 (LNL, BMG) | Vulkan cooperative matrix | FP16, FP32 accumulation | B580: 50–53 ms at 720p | "rounding" vs OpenDLSS | push 10-05 | Vulkan layer + daemon | **yes (main)** |
| gggz114514 B580 | none | Arc B580 | Torch XPU / Triton | fast mode drops FP8 emulation | 39–46 ms at 720p | exact only on frozen inputs | 10-03 | own game bridge | ? |
| SYCL bridge | MIT | Arc A770/A750 (Alchemist) | SYCL/OpenCL | not documented (weights exported as f32) | 54–57 ms at 1280×704 | not published | v0.1.1, 09-30 | OpenNR teacher, async | no |
| dlssnr-patcher / "approx-fp16" DLL | GPL-2.0 / NVIDIA binary | RTX 20/30/40 | CUDA (NGX) | FP16 MMA instead of FP8 | none published | not bit-exact (by construction) | 09-03 | any NGX host | no |
| WebGPU ports (OpenDLSS-NR, three-dlss-nr) | MIT | any WebGPU GPU | WGSL / TSL | exact emulation, no FP8 | 72 ms at 512² (4070 S); 412 ms at 720p (3060 Ti) | bit-exact | 09-21 / 10-05 | browser, three.js | browser |
| dlssnr-pytorch | MIT | ROCm / CUDA / CPU | PyTorch + Triton | FP16, FP32 accumulation, E4M3 rounding | 0.19 s at 1080p (7900 XTX) | 45.70 / 48.26 / 49.10 dB | 10-02 | Python library | yes |
| taowen dlss5-onnx | (HF repo) | ONNX Runtime EPs | ONNX | FP16 / INT8-ViT | 161.5 ms at 256² (890M) | "added grain" | 09-09 | Python / ORT | yes (tested) |
| MLX-DLSS | Apache-2.0 | Apple silicon, PyTorch | MLX/Metal, Core ML | — | 512×384 at ~19 fps (M2 Max) | 0.004–0.005 MAE | 09-10 | app / CLI | PyTorch path |

Sources: the rows repeat facts cited in 1b–1g.

#### 1j. Repositories to treat as untrusted

- [V] **AMDNR/AMD-NR-DLSS5.** Created 2026-10-06, with a keyword-stuffed README and a 72.7 MB zip. It looks like a repack. — [repo](https://github.com/AMDNR/AMD-NR-DLSS5)
- [V] **Fastbrasecret8/DLSS5-Manager.** Created 2026-06-15, before the DLL leaked. Its releases are tagged "010101" and "111111", and it ships a 146 MB zip. — [repo](https://github.com/Fastbrasecret8/DLSS5-Manager)
- Neither binary was analysed; both are listed only so they can be excluded.

### Inferences

- **The best open-source code for cross-vendor work is mochizuki plus mauri870.** Together they form one MIT Vulkan code base with an FP8 RDNA4 path and an FP16 RDNA3 path, both validated against NVIDIA at about 45–49 dB. Two more pieces complement it:
  - Uzbekunknown's Intel FP16 kernels (Apache-2.0) are tuned for the Xe2 8×16×16 shape.
  - OpenDLSS-NR's documented numerics (MIT) give the exact specification.
- **OpenDLSS-NR's GLSL route will probably not run on non-NVIDIA GPUs as written.** Its FP8 GEMMs are specified as 16×16×32 E4M3 → **f16-accumulate** cooperative matrices, and it lists `VK_NV_cooperative_matrix2`. RADV's FP8 configurations accumulate to FP32 at 16×16×16, and ANV has no FP8 at all (§3). No report of OpenDLSS-NR running on AMD or Intel was found.
- **The "bit-exact" claims mean different things.**
  - OpenDLSS-NR's claim refers to NVIDIA's own captures.
  - lmxxf's and guentra's refer to their own reference chain: lmxxf's "bit-exact numerics" configuration still scores 47.43 dB against NVIDIA.
  - danielblnc's "Reference = NVIDIA's exact arithmetic" is unverifiable, since the runtime is closed.
- **Speed ranking at 1080p, network only, best published:**
  1. RTX 4090 CUDA, 5.8 ms (end to end)
  2. RX 9070 XT Vulkan on Linux, 5.6 ms
  3. RX 9070 XT Vulkan on Windows, 7.2 ms
  4. RTX 4070 SUPER, 7.8 ms
  5. RX 9070 XT HIP, about 9.8 ms
  6. RX 7900 XTX Vulkan on Linux, 15 ms
  7. RX 7900 XTX with danielblnc on Windows, about 27–35 ms
  8. Intel B580, about 100 ms or more by extrapolation [D]: the 720p graph takes 50 ms, and 1080p has about 2.2× the work.
  9. RDNA2, hundreds of ms.
- **What makes it playable on the slower lines is lower resolution, not faster kernels.** Pre-upscale mode (NR at render resolution, then FSR) and a reduced "model resolution" are the levers, at a measurable cost in fidelity: at 4K, 50% model scale gives 35.3 dB instead of 49.0 dB.

### Gaps

- **danielblnc's runtime:** no per-ms network times on Windows for current versions on RDNA4, RDNA3 or RDNA2, and no published PSNR. It is closed, so it cannot be checked.
- **RTX 20/30/40 with the patched DLL:** no measured fps or ms anywhere, and no image-quality comparison. The source DLL is also unclear (PTX versus cubin-only; see the conflict in 1f).
- **gaps on specific ports:**
  - the SYCL bridge's arithmetic precision
  - Intel B580 numbers under Linux
  - any port for Intel Xe3 (Panther Lake)
  - mochizuki's RX 9060 results (the README says tested only on the 9070 XT)
  - OpenDLSS-NR on RTX 50 (claimed Ada or newer, but no Blackwell timings)
  - whether mauri870's RDNA3 branch will be merged into mochizuki upstream

---

## 2. What each GPU line's hardware provides for this network, and what falling back from FP8 costs

### Takeaway

**FP8 matrix hardware reachable from a portable API** exists only on:
- NVIDIA Ada and Blackwell, through the proprietary driver
- AMD RDNA4, through both RADV and AMD's Windows driver (proven in production by mochizuki)

**Intel XMX (Alchemist, Xe2, Xe3) has no FP8 in Mesa ANV.** Intel, RDNA3, RTX 20 and RTX 30 must run FP16 (or BF16/INT8) matrices. RDNA2 has no matrix unit at all.

**Falling back from FP8 to FP16:**
- It is lossless for the weights, because every E4M3 value is exactly representable in FP16.
- It doubles VRAM and bandwidth: the RDNA3 build uses 5.3 GB at 4K against about 2.6 GB on RDNA4.
- It costs about 2.6× in time on RDNA3 against RDNA4.
- To stay near 45–49 dB, the E4M3 rounding of activations must still be emulated. Skipping it drops fidelity to 38.5 dB.

**INT8 is not a free win.**
- The RDNA3 INT8 rate equals its FP16 rate.
- Simulated INT8 loses 1–2.6 dB.
- Activations span up to 180,000× of dynamic range, so per-tensor INT8 breaks the high-resolution levels.

**Measured numbers for the specific cards asked about:**
- RX 7900 XTX: 15 ms at 1080p.
- Arc A770: 54 ms at 1280×704.
- Arc B580: 40–53 ms at 720p.
- RX 6800 (and 6600, 6900 XT): only user reports, hundreds of ms or about 5 fps.
- **RTX 3060, RTX 3080 and RTX 2080: no measurements exist.**

### Cited Findings

#### 2a. Matrix data types each GPU line exposes

- **NVIDIA tensor cores.**
  - [V] Turing: FP16 and INT8 (no BF16/TF32). Ampere adds BF16 and TF32. Ada adds FP8. Blackwell adds FP4 and FP6. — [Ampere GA102 whitepaper](https://images.nvidia.com/aem-dam/en-zz/Solutions/geforce/ampere/pdf/NVIDIA-ampere-GA102-GPU-Architecture-Whitepaper-V1.pdf); [RTX Blackwell whitepaper](https://images.nvidia.com/aem-dam/Solutions/geforce/blackwell/nvidia-rtx-blackwell-gpu-architecture.pdf) (accessed 2026-10-07, via subagent)
  - [V] The patcher has to replace the FP8 `mma` for sm_75/86/89 targets. — [dlssnr_patcher.py](https://github.com/dev-camo/dlssnr-patcher/blob/main/dlssnr_patcher.py)
- **NVIDIA in Mesa (NVK).**
  - [V] Cooperative matrix on Turing and newer, except TU11x (the GTX 16 series).
  - [V] FP16 shapes 16×16×16, 16×8×16 and 16×8×8, plus INT8. No BF16 and no FP8.
  - Source: [nvk_physical_device.c](https://gitlab.freedesktop.org/mesa/mesa/-/raw/main/src/nouveau/vulkan/nvk_physical_device.c) (main, accessed 2026-10-07)
- **NVIDIA proprietary driver.**
  - [C] `VK_EXT_shader_float8` arrived in beta 573.38. A community issue lists Linux 595.91.07 and 610.57.04 as having it and 580.178 as lacking it. — [Softpedia](https://drivers.softpedia.com/get/GRAPHICS-BOARD/NVIDIA/NVIDIA-GeForce-Graphics-Vulkan-1-4-Driver-573-38-Beta-64-bit.shtml); [infinitum #22](https://github.com/silvanshade-org/infinitum/issues/22)
  - [V] OpenDLSS-NR runs FP8 cooperative matrix on Ada through it. — [README](https://github.com/maanHimself/OpenDLSS-NR)
- **AMD under RADV.**
  - [V] Cooperative matrix is enabled only for gfx_level ≥ GFX11 when compiling with ACO, so **there is no RDNA2 path and no emulation**.
  - [V] All shapes are 16×16×16 at subgroup scope:
    - FP8 E4M3/E5M2 accumulating to FP32, only on GFX11_7 and newer (RDNA4 is GFX12)
    - INT8 accumulating to INT32
    - FP16 accumulating to FP16 or FP32
    - BF16, on by default only on GFX12; on GFX11 it is experimental ("precision issues")
  - Source: [radv_physical_device.c](https://gitlab.freedesktop.org/mesa/mesa/-/raw/main/src/amd/vulkan/radv_physical_device.c) (main, accessed 2026-10-07)
- **AMD on Windows.**
  - [V] The driver exposes `VK_KHR_cooperative_matrix` and `VK_EXT_shader_float8` on RDNA4 (AMD Software ≥ 25.10). — [mochizuki ARCHITECTURE.md](https://github.com/mochizuki0323/DLSSNR-AMD/blob/main/docs/ARCHITECTURE.md)
  - [V] HIP exposes the RDNA4 and RDNA3 WMMA (lmxxf, danielblnc). The RX 6000 driver ships HIP 6.4 only. — [zmodelerlover README](https://github.com/zmodelerlover/dlss5-neural-amd)
- **AMD RDNA3, measured.**
  - [M] An RX 7900 XTX reaches 131–135 TFLOPS for 16×16×16 FP16 cooperative-matrix multiplies and 132–140 TOPS in INT8. "INT8 matrix instructions instead of FP16: on RDNA3 they are not faster". — [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
- **AMD RDNA2.**
  - [C] It has packed-dot instructions (`v_dot2c_f32_f16`, `v_dot4c_i32_i8` on gfx1030), but which Navi 2x chips have them was not checked. — [LLVM bug 54691](https://lists.llvm.org/pipermail/llvm-bugs/2022-April/098954.html) (via subagent)
- **Intel under ANV.**
  - [V] Cooperative matrix exists only on parts with XMX (`has_systolic`): DG2/Alchemist, ATS-M, ARL-H, Xe2 (Lunar Lake, Battlemage) and Xe3 (Panther Lake, WCL, NVL-U). It does **not** exist on Meteor Lake or ARL-U.
  - [V] Shapes: M=8; N=8 on Xe-HPG and 16 on Xe2+; K=16 for FP16/BF16 and 32 for INT8.
  - [V] **No FP8 anywhere.**
  - Sources: [anv_physical_device.c](https://gitlab.freedesktop.org/mesa/mesa/-/raw/main/src/intel/vulkan/anv_physical_device.c); [intel_device_info.c](https://gitlab.freedesktop.org/mesa/mesa/-/raw/main/src/intel/dev/intel_device_info.c) (main, accessed 2026-10-07)
- **Intel Lunar Lake probe** (2026-09-07, Mesa ANV).
  - [V] Six configurations: FP16 and BF16 at 8×16×16 with FP16/FP32 or BF16/FP32 accumulators, and INT8 at 8×16×32.
  - [V] `cooperativeMatrixRobustBufferAccess` is false.
  - [V] TF32, INT4 and INT2 exist in the hardware (through OpenCL) but are not exposed through Vulkan.
  - Source: [hw-coopmat.md](https://github.com/Uzbekunknown/dlss-nr-on-intel/blob/master/notes/hw-coopmat.md)
- **Intel Xe3.**
  - [C] It is described as 120 TOPS against 67 for Lunar Lake. The "native FP8" wording in the source is ambiguous and may refer to the NPU. — [igor'sLAB](https://www.igorslab.de/en/panther-lake-and-the-integration-of-ki-graphics-and-image-processing-an-overview-of-intels-new-architectural-strategy/) (via subagent)

#### 2b. Peak dense matrix rates

**NVIDIA** [V]. Units: TFLOPS, or TOPS for INT8. "/" separates the FP16-accumulate and FP32-accumulate rates.

| Card | FP16 | FP8 | INT8 |
|---|---|---|---|
| RTX 2080 | 84.8 / 42.4 | — | 169.6 |
| RTX 3080 | 119 / 59.5 | — | 238 |
| RTX 4070 | 116.6 / 58.3 | 233.2 / 116.6 | — |
| RTX 4090 | 330.3 / 165.2 | 660.6 / 330.3 | — |
| RTX 5090 | 419 / 209.5 | 838 / 419 | — |

- On GeForce cards, FP32 accumulation runs at half the rate of FP16 accumulation.
- [D] RTX 3060: about 50.9 / 25.5 for FP16. RTX 4070 SUPER: about 283.9 for FP8 with FP16 accumulation.
- Sources: [GA102 whitepaper](https://images.nvidia.com/aem-dam/en-zz/Solutions/geforce/ampere/pdf/NVIDIA-ampere-GA102-GPU-Architecture-Whitepaper-V1.pdf); [RTX Blackwell whitepaper](https://images.nvidia.com/aem-dam/Solutions/geforce/blackwell/nvidia-rtx-blackwell-gpu-architecture.pdf)

**AMD**
- [C] RX 7900 XTX: 122.8 TFLOPS FP16 (third-party listing). mauri870 uses "123 TFLOPS" and measured 131–135. — [itcreations listing](https://www.itcreations.com/amd-gpu/amd-radeon-rx-7900-xtx-gpu); [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
- [C] RX 9070 XT: 389 TFLOPS FP8, 389 TOPS INT8 (pre-launch figures). — [TweakTown](https://www.tweaktown.com/news/103539/rumored-final-specs-of-rx-9070-xt-and-gpus-revealed-including-flagship-hitting-48-7-tflops/index.html)
- [D] RX 6800: about 32.3 TFLOPS of packed FP16 vector rate, with no WMMA (subagent's derivation).

**Intel**
- [C] Arc B580: 233 INT8 TOPS, so about 117 FP16. — [Intel ARK](https://www.intel.com/content/www/us/en/products/sku/241598/intel-arc-b580-graphics/specifications.html) (search snippet via subagent)
- [C] Arc A770: about 157 FP16 and 315 INT8 (third-party).
- [M] Arc 140V: an FP16 peak of about 32 TFLOP/s. — [PERF-WINDOWS.md](https://github.com/Uzbekunknown/dlss-nr-on-intel/blob/master/docs/PERF-WINDOWS.md)

#### 2c. Measured network times on the cards asked about

- **RTX 3060, RTX 3080, RTX 2080: no DLSS-NR timing exists in any source found.**
  - [M] Nearest data point: an RTX 3060 Ti in WebGPU takes 412 ms at 1280×720. — [three-dlss-nr](https://github.com/bhouston/three-dlss-nr)
  - [M] Nearest data point: an RTX 2060 with the SM75 CUDA compat backend takes about 1020 ms at 720p. — [OpenDLSS-NR #6](https://github.com/maanHimself/OpenDLSS-NR/issues/6)
- **RX 6800, 6800 XT, 6600, 6900 XT.**
  - [C] The RX 6800 and 6800 XT fail to initialise under danielblnc 0.6.0. — [#233](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/233); [#149](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/149)
  - [C] RX 6600: about 5 fps. — [#235](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/235)
  - [M] RX 6900 XT: "several hundred ms" per frame with the translated kernels. — [translation-lab](https://github.com/philippraschke75-spec/gfx1030-dlss-nr-translation-lab)
- **RX 7900 XTX.**
  - [M] 15 ms at 1080p and 56 ms at 4K (mauri870, Linux Vulkan). — [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
  - [M] 27–35 ms at 1080p (danielblnc through Magpie, Windows). — [magpie-dlss5-amd](https://github.com/A-ENTROPY/magpie-dlss5-amd)
  - [C] **Superseded:** about 72 ms in v0.3.1. — [#182](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/182)
- **RX 7800 XT** (v0.3.0, 2026-09-15).
  - [C] 1440p native: 220–230 ms per job. FSR Performance: 40–48 ms. — [#173](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/173)
- **Arc A770 and A750.**
  - [M] 54 and 57 ms at 1280×704 (SYCL). — [SYCL bridge](https://github.com/MakeDecisionWorth/DLSSNR-SYCL-Bridge)
- **Arc B580.**
  - [M] A 50–53 ms graph at 1280×720 (Vulkan cooperative matrix, Windows). — [PERF-WINDOWS.md](https://github.com/Uzbekunknown/dlss-nr-on-intel/blob/master/docs/PERF-WINDOWS.md)
  - [M] A 39–40 ms GPU body offline and a 55–60 ms base frame time in game (Triton-XPU). — [gggz114514](https://github.com/gggz114514-oss/dlss5nr-b580-intelarc)

#### 2d. Measured cost of FP8 → FP16 and FP8 → INT8

- [V] Every E4M3 value is exactly an FP16 value, so the RDNA3 build multiplies the same products on FP16 matrix units. — [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
- **The FP16 path on RDNA3.**
  - [M] It takes about 2.6× the RDNA4 time and 2× the VRAM (5.3 GB at 4K).
  - [M] An FP16 fragment needs eight VGPRs, twice an FP8 fragment, so the RDNA4 tile shapes spilled.
  - Source: [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
  - [C] danielblnc's RDNA3 builds need about 280 MB more VRAM per pass for an FP16 weight copy. — [zmodelerlover README](https://github.com/zmodelerlover/dlss5-neural-amd)
- **Turning off the E4M3 rounding emulation.**
  - [M] Keeping values in FP16 everywhere makes a 4K frame 9% faster (59.3 → 53.9 ms) but drops it from **49.0 to 38.5 dB**.
  - [M] Skipping the rounding in only five kernels costs 0.64 dB (49.02 → 48.38) and saves 1.7 ms.
  - Source: [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
- **INT8.**
  - [M] On RDNA3 it is no faster. A simulated INT8 network "loses 1 to 2.6 dB against NVIDIA". — [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
  - [M] On Intel, INT8 weights hold up: head correlation 0.9922 per output channel and 0.9931 per tensor.
  - [M] INT8 activations do not. They carry "up to 180 000x" of dynamic range; per-tensor INT8 rounds 21.5% of non-zero values to zero at level l1 (31.95% relative error). At the l5 bottleneck it is fine (0.4% and 1.59%). The XMX INT8 configuration has twice the K depth of FP16.
  - Sources: [phase23-integer-weights.md](https://github.com/Uzbekunknown/dlss-nr-on-intel/blob/master/notes/phase23-integer-weights.md); [improve-int8-bottleneck.md](https://github.com/Uzbekunknown/dlss-nr-on-intel/blob/master/notes/improve-int8-bottleneck.md)
  - [M] taowen's INT8-ViT ONNX is 22% smaller but **slower** on the 890M (176.5 against 161.5 ms). — [dlss5-onnx](https://huggingface.co/taowen/dlss5-onnx)
  - [V] The RDNA2 fork mixes INT8 and FP16 but publishes no quality figure. — [OptiScaler-RDNA2NR](https://github.com/shakhbazian/OptiScaler-RDNA2NR)
- **NVIDIA rates.**
  - [V] On Ada and Blackwell GeForce, FP16 MMA with FP16 accumulation runs at **half** the rate of FP8 with FP16 accumulation, the mode the network uses. — whitepapers above
  - [C] Guru3D reports that FP8 *emulation* on Ampere was "severe[ly]" slow and that the FP16 builds are "more practical". — [Guru3D](https://www.guru3d.com/story/leaked-dlss-5-runs-on-rtx-20-and-rtx-30-gpus/)
- **Other speed levers, with measured fidelity cost** (lmxxf, RDNA4).
  - [M] Skipping blocks 42, 43 and 46 costs 3.3 dB for a 0.2–0.32 ms gain.
  - [M] 1088-row geometry costs 1.6 dB and saves 0.45 ms (5.6% less work).
  - [M] Fast numerics barely change fidelity against NVIDIA: 47.43 → 47.55 dB.
  - [M] Adaptive ViT reuse is 5–11% faster; its quality in motion is unmeasured.
  - Source: [README](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)

### Inferences

- **[D] Achieved throughput.** Using about 1.02 TFLOP per frame at 1080p (0.96 at 1088 rows) and 3.5–3.9 TFLOP at 4K:

  | Port and card | Achieved | Share of matrix peak |
  |---|---|---|
  | OpenDLSS-NR, RTX 4070 SUPER | 131 TFLOP/s | ~46% of FP8 |
  | mochizuki, RX 9070 XT, Linux | ~172 TFLOP/s | ~44% of the claimed 389 |
  | mochizuki, RX 9070 XT, Windows | ~134 TFLOP/s | — |
  | mauri870, RX 7900 XTX | ~62–64 TFLOP/s | ~51% of 123 |
  | Uzbekunknown, Arc B580 (720p field ≈0.48 TFLOP) | ~9 TFLOP/s | ~8% of ~117 FP16 |
  | SYCL, Arc A770 | ~8 TFLOP/s | ~5% |
  | three-dlss-nr, RTX 3060 Ti WebGPU | ~1.2 TFLOP/s | — |

  So **the Intel paths are the furthest from their hardware limits.** Uzbekunknown's notes put the limit in the register file, not in arithmetic.
- **[D] What a well-tuned FP16 cooperative-matrix Vulkan port could reach** on the lines that have no port. This assumes about 50% of the FP16-accumulate peak, as the RDNA3 port reaches; it is a projection, not a measurement.

  | Card | Projected 1080p network time |
  |---|---|
  | RTX 3060 | ~40 ms |
  | RTX 3080 | ~17 ms |
  | RTX 2080 | ~24 ms, likely worse: Turing has only m16n8k8 and no cp.async |
  | Arc B580 | ~17 ms, if Intel kernels reached RDNA3-class efficiency (they are at ~8% today) |
  | RX 6800 | ~80–100 ms with packed FP16 dot products and no matrix unit; about 20–25 ms at 50% model scale |
- **Precision choice on NVIDIA.** FP16 accumulation is both the fast mode on GeForce and closer to NVIDIA's own f16 accumulation. On AMD and Intel, Vulkan cooperative matrix FP8 or FP16 accumulates in FP32 (RADV lists FP16 accumulators for FP16 inputs only). That FP32 accumulation is one reason those ports sit at 45–49 dB rather than bit-exact.
- **INT8 is a niche option.** It suits weights, and activations only at the ViT bottleneck. It is a speed lever only where INT8 throughput is greater than FP16: NVIDIA, Intel XMX (twice the K depth) and RDNA2 dot4. It is not a lever on RDNA3, where the rates are equal.

### Gaps

- No measured DLSS-NR timings on RTX 2080, 3060 or 3080 (patched DLL or otherwise), on an RX 6800, or on any Xe3 part.
- Official AMD and Intel matrix-rate pages were not confirmed; the RDNA4 and Arc figures above are third-party or pre-launch.
- Whether AMD's Windows Vulkan driver exposes FP8 cooperative matrix on anything other than RDNA4. Its shape and accumulator list was not dumped; gpuinfo per-device reports would settle this.
- No published fidelity numbers for FP16-only ports on NVIDIA Turing or Ampere.

---

## 3. Vendor-neutral GPU ML execution paths: driver support in October 2026, and which route covers the most GPUs at acceptable speed

### Takeaway

**Vulkan compute is the only vendor-neutral route that works for end users today.** It means `VK_KHR_cooperative_matrix`: FP16 as the baseline, with FP8 through `VK_EXT_shader_float8` where available.
- **Coverage.**
  - NVIDIA RTX 20 and newer: proprietary driver and NVK.
  - AMD RDNA3 and newer: RADV and AMD Windows.
  - Intel XMX parts: Alchemist with 8×8 shapes; Xe2 and Xe3 with 8×16.
  - FP8 only on Ada, Blackwell and RDNA4.
  - RDNA2, GTX 16 and Meteor Lake need a non-matrix FP16 fallback.
- **Evidence.** AMD's two fastest ports (mochizuki and mauri870) and the Intel port are all Vulkan cooperative-matrix code, running on RADV, AMD Windows and ANV/Intel Windows.

**D3D12 is not shippable.**
- D3D12 SM 6.10 LinAlg (wave-level matrices with FP8 types) is the right design. lmxxf ran a bit-exact implementation of the whole network on it.
- But it is still **preview-only**: preview Agility SDK, AMD developer-preview driver, Developer Mode. NVIDIA access is through developer relations only, and Intel's driver is "future".
- SM 6.9 cooperative vectors were **deprecated** before retail.

**ONNX Runtime, Windows ML and DirectML are fragmented and not real-time.**
- DirectML is in maintenance mode.
- The Windows ML providers exclude Turing (TensorRT-RTX needs RTX 30 or newer) and RDNA2 (MIGraphX needs RDNA3 or newer).
- The only ONNX export takes 161 ms at 256² on an 890M.

**WebGPU is bit-exact but 25–50× slower.** It has no FP8 and no standard matrix operations; subgroup-matrix is Chromium-experimental.

**HIP (AMD only) and SYCL (Intel only) are good single-vendor fallbacks.** SYCL is the only route that reaches Alchemist at a usable rate.

### Cited Findings

#### 3a. Vulkan

- [V] **`VK_KHR_cooperative_matrix` coverage.**
  - gpuinfo coverage: Windows 43.92%, Linux 41.34%. — [gpuinfo](https://vulkan.gpuinfo.org/displayextensiondetail.php?extension=VK_KHR_cooperative_matrix) (accessed 2026-10-07)
  - Mesa: "DONE (anv, lvp, nvk/Turing+, panvk/v11+, radv/gfx11+, vn)". — [features.txt](https://gitlab.freedesktop.org/mesa/mesa/-/raw/main/docs/features.txt) (main, 2026-10-06)
- [V] **AMDVLK was discontinued on 2025-09-15**, so RADV is AMD's Linux Vulkan driver. — [Phoronix](https://www.phoronix.com/news/AMDVLK-Discontinued)
- [V] **`VK_NV_cooperative_matrix2`.**
  - An NVIDIA extension, not ratified. gpuinfo coverage: Windows 22.14%, Linux 21.48%.
  - RADV implements it only behind the driconf option `radv_cooperative_matrix2_nv`.
  - ANV advertises the name but supports only per-element operations; its flexible-dimension list is empty.
  - NVK does not expose it.
  - Sources: [registry](https://registry.khronos.org/vulkan/specs/latest/man/html/VK_NV_cooperative_matrix2.html); [gpuinfo](https://vulkan.gpuinfo.org/displayextensiondetail.php?extension=VK_NV_cooperative_matrix2); [radv source](https://gitlab.freedesktop.org/mesa/mesa/-/raw/main/src/amd/vulkan/radv_physical_device.c); [anv source](https://gitlab.freedesktop.org/mesa/mesa/-/raw/main/src/intel/vulkan/anv_physical_device.c)
  - The Intel probe (2026-09-07) confirms: "advertised but empty … count = 0". — [hw-coopmat.md](https://github.com/Uzbekunknown/dlss-nr-on-intel/blob/master/notes/hw-coopmat.md)
- [V] **Cross-vendor successor: `VK_EXT_cooperative_matrix_maintenance1`.**
  - Released in Vulkan 1.4.359 (2026-08-07), with contributors from NVIDIA, Qualcomm, Intel and Arm.
  - It adds conversions, reductions and per-element operations.
  - Mesa: "DONE (lvp, radv/gfx11+)".
  - Sources: [Phoronix](https://www.phoronix.com/news/Vulkan-1.4.359); [features.txt](https://gitlab.freedesktop.org/mesa/mesa/-/raw/main/docs/features.txt)
  - [C] No evidence was found that it covers workgroup-scope matrices or flexible dimensions.
- [V] **`VK_EXT_shader_float8`.**
  - gpuinfo coverage: Windows 10.53%, Linux 7.85%.
  - RADV has had it since Mesa 25.2: "DONE (radv/gfx12+, vn)". ANV does not have it.
  - Sources: [gpuinfo](https://vulkan.gpuinfo.org/displayextensiondetail.php?extension=VK_EXT_shader_float8); [Phoronix](https://www.phoronix.com/news/RADV-VK_EXT_shader_float8) (2025-06-23)
  - [V] AMD's Windows driver has it on RDNA4. — [mochizuki ARCHITECTURE.md](https://github.com/mochizuki0323/DLSSNR-AMD/blob/main/docs/ARCHITECTURE.md)
- [V] **`VK_KHR_shader_bfloat16`.** Mesa: ANV gfx12.5+ (DG2 and newer) and RADV gfx12+. On RDNA3 it is experimental only. — [features.txt](https://gitlab.freedesktop.org/mesa/mesa/-/raw/main/docs/features.txt)
- [V] **Other ML extensions.** There is no KHR cooperative-vector extension and no KHR/EXT tensor extension. The ones that exist:
  - `VK_NV_cooperative_vector` (NVIDIA)
  - `VK_NV_cooperative_matrix_decode_vector` (1.4.352, May 2026)
  - `VK_ARM_tensors` and `VK_ARM_data_graph` (both Arm, not ratified)
  - Sources: [Phoronix 1.4.352](https://phoronix.com/news/Vulkan-1.4.352-Released); [VK_ARM_tensors](https://docs.vulkan.org/refpages/latest/refpages/source/VK_ARM_tensors.html)
- **Evidence from the ports.**
  - [M] mochizuki runs FP8 cooperative matrix on RADV and on AMD's Windows driver. Windows is slower (7.21 against 5.60 ms), compiles slower (about a minute against 10–20 s) and rounds differently (48.6 dB apart). — [README](https://github.com/mochizuki0323/DLSSNR-AMD)
  - [V] A driver update broke the build once; it built again on driver 32.0.32015. — [CHANGELOG](https://github.com/zmodelerlover/dlss5-neural-amd/blob/master/CHANGELOG.md)
  - [M] The Intel kernels produce bit-identical results on Mesa ANV and on Intel's Windows driver. — [README](https://github.com/Uzbekunknown/dlss-nr-on-intel)

#### 3b. Direct3D 12

- [V] **SM 6.9 went retail** with Agility SDK 1.619 (2026-02-26), on AMD Adrenalin 26.2.1, NVIDIA 595+ and Intel Arc. "Cooperative Vector has been deprecated in favor of a future design unifying matrix-matrix and vector-matrix operations, coming in Shader Model 6.10". — [DirectX blog](https://devblogs.microsoft.com/directx/shader-model-6-9-retail-and-more/)
- [V] **SM 6.10 LinAlg is in preview.**
  - Agility SDK 1.720-preview (2026-04-27): thread scope (matrix-vector), wave scope (matrix-matrix) and threadgroup scope. The examples use `F8_E4M3FN` and `F8_E5M2` types.
  - 1.721-preview (2026-05-28).
  - Vendor access: AMD RX 9000 through developer-preview drivers 25.30.41.02 and 26.10.07.02; NVIDIA through developer relations only; Intel Xe2+ "in a future driver".
  - Sources: [SM 6.10 preview](https://devblogs.microsoft.com/directx/shader-model-6-10-agilitysdk-720-preview/); [LinAlg preview](https://devblogs.microsoft.com/directx/d3d12-linalg-preview/); [1.721 preview](https://devblogs.microsoft.com/directx/announcing-agilitysdk-721-preview-and-more-shader-model-6-10-features/)
- [V] **Still preview in September 2026.** An ONNX Runtime PR (2026-09-17) still needs 1.721.3-preview plus AMD's 26.10.07.02 preview driver. — [ORT #32667](https://github.com/microsoft/onnxruntime/pull/32667)
- [V/M] **lmxxf's port is the only DLSS-NR implementation on this API.**
  - It needs Developer Mode, because the add-on calls `D3D12EnableExperimentalFeatures`.
  - The exact chain took 186 ms; the first fast chain took 112 ms.
  - It was abandoned for HIP in 0.20 because HIP was about 8% faster and needed no preview components.
  - Source: [README](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)

#### 3c. DirectML, Windows ML and ONNX Runtime

- [V] **DirectML** "is in maintenance mode … no new functionality". — [microsoft/DirectML](https://github.com/microsoft/DirectML)
- [V] **Windows ML execution providers** (page dated 2026-09-22).
  - In-box: CPU and "DirectML (legacy)".
  - Downloadable:
    - AMD MIGraphX: RDNA3 and newer, driver ≥ 25.10.13.09
    - NVIDIA NvTensorRtRtx: "GeForce RTX 30XX and above"
    - Intel OpenVINO
    - WebGPU: experimental
  - Source: [MS Learn](https://learn.microsoft.com/en-us/windows/ai/new-windows-ml/supported-execution-providers)
- [V] **ONNX Runtime.**
  - The ROCm EP was removed from 1.23 on; MIGraphX replaces it. — [ORT docs](https://onnxruntime.ai/docs/execution-providers/ROCm-ExecutionProvider.html)
  - The WebGPU EP has subgroup-matrix FP16 kernels, tested on an RX 9070 XT through the SM 6.10 preview stack. — [ORT #32667](https://github.com/microsoft/onnxruntime/pull/32667)
- [M] **The only DLSS-NR ONNX evidence:** taowen's static 256² model on MIGraphX takes 161.5 ms on an 890M; first compilation takes "minutes". — [dlss5-onnx](https://huggingface.co/taowen/dlss5-onnx)

#### 3d. WebGPU

- [V] **Subgroup matrix** is Dawn-only and experimental (`chromium-experimental-subgroup-matrix`). `shader-f16` and subgroups have shipped. There is no FP8. — [ORT #32667](https://github.com/microsoft/onnxruntime/pull/32667); [blink-dev](https://groups.google.com/a/chromium.org/g/blink-dev/c/xteMk_tObgI) (via subagent)
- [M] **Cost of exact emulation on WebGPU.** Each 16-product group needs about "six operations where the hardware does one". Without inter-block fusion and chaining, 512² takes 72 ms against 2.7 ms in Vulkan on the same card. — [WebGPU README](https://github.com/maanHimself/OpenDLSS-NR/blob/main/ports/browser-webgpu/README.md)

#### 3e. Driver maturity, judged from llama.cpp's Vulkan backend

- [V] **AMD.** INT8 cooperative-matrix kernels for RDNA3/4 were merged on 2026-09-24 and work on both RADV and AMD Windows. gpt-oss-20B prompt processing on an R9700 went from 3936 to 5631 t/s. — [llama.cpp #27952](https://github.com/ggml-org/llama.cpp/pull/27952)
- [V] **Intel.**
  - Cooperative matrix on A-series was disabled because it was slower. — [discussion #13530](https://github.com/ggml-org/llama.cpp/discussions/13530)
  - Cooperative matrix causes **Windows TDRs on the Arc 140V** with drivers 101.8509 and 101.8531. — [#20554](https://github.com/ggml-org/llama.cpp/issues/20554)
  - llama.cpp's Xe2 path needs a minimum subgroup size of 16. — [#20776](https://github.com/ggml-org/llama.cpp/issues/20776)
- [V] **NVIDIA.** NV coopmat2 Q8_0 prompt processing became 16–19% slower on an RTX 5060 Ti. — [#30000](https://github.com/ggml-org/llama.cpp/issues/30000)
- [C] NVK's cooperative matrix improved from about 70% to about 92% of the proprietary driver's speed. — [Phoronix](https://www.phoronix.com/news/NVK-Cooperative-Matrix-Perf)

#### 3f. Single-vendor compute routes

- **HIP.**
  - [V] The HIP 7 runtime ships inside Adrenalin for RDNA3 and RDNA4 (`amdhip64_7.dll`). RX 6000 drivers have only HIP 6.4, so RDNA2 users of danielblnc must install the HIP SDK 7.2; shakhbazian's fork runs on HIP 6. — [zmodelerlover README](https://github.com/zmodelerlover/dlss5-neural-amd); [OptiScaler-RDNA2NR](https://github.com/shakhbazian/OptiScaler-RDNA2NR)
  - [V] On Linux, HIP is not part of Mesa. It needs ROCm plus a bridge to reach it from a Proton process, and that is the reason mochizuki chose Vulkan. — [mochizuki README](https://github.com/mochizuki0323/DLSSNR-AMD)
- **SYCL.** [M] It is the only route that reaches Alchemist at a usable rate: 54 ms at 1280×704 on an A770. — [SYCL bridge](https://github.com/MakeDecisionWorth/DLSSNR-SYCL-Bridge)

### Inferences

**Best route for widest coverage today [D].** One Vulkan compute implementation with three kernel tiers, chosen at runtime from `vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR` and the `shaderFloat8CooperativeMatrix` feature:

1. **FP8 cooperative-matrix tier: RDNA4, Ada and Blackwell.**
   - On RDNA4 it should match mochizuki: about 5.6–7.2 ms at 1080p, 45.6 dB.
   - On RTX 40/50 the tier can keep NVIDIA's exact arithmetic. OpenDLSS-NR's GLSL reference route already runs E4M3 → f16 cooperative matrices through `VK_KHR_cooperative_matrix` + `VK_NV_cooperative_matrix2` + `VK_EXT_shader_float8`, without PTX, and is bit-exact; its PTX route is the faster form. — [execution.md](https://github.com/maanHimself/OpenDLSS-NR/blob/main/docs/execution.md)
   - A portable kernel that used FP32 accumulators on NVIDIA would run at half the FP8 rate on GeForce and would no longer be bit-exact.
2. **FP16 cooperative-matrix tier with E4M3 rounding emulation: RDNA3, RTX 20/30, Intel Alchemist, Xe2 and Xe3.**
   - The mauri870 design runs 15 ms at 1080p on a 7900 XTX at 45.5 dB.
   - RTX 30 and Intel need shape-specific tiling (16×8×16 and 8×16×16).
   - Projected times are in §2.
3. **Non-matrix FP16/packed-dot fallback: RDNA2, GTX 16, Meteor Lake and older iGPUs.**
   - It needs model scale ≤ 50% plus pre-upscale placement to be usable.

**Why Vulkan wins on coverage.**
- It is the only API with production drivers for all three vendors' matrix units on both Windows and Linux.
- It runs inside the game's own device under DXVK/vkd3d-proton, which mochizuki and Uzbekunknown exploit.
- MIT/Apache code already exists for tiers 1 and 2 on AMD and Intel.

**Risks.**
- Windows driver quality: AMD shader-compile time and rounding differences, a build broken by one AMD driver update, and Intel cooperative-matrix TDRs in llama.cpp.
- Vendor shape fragmentation.

**When to revisit D3D12.** SM 6.10 LinAlg should be reconsidered once it ships in a retail Agility SDK with retail NVIDIA and Intel drivers. It would then be the natural Windows-only route, with FP8 types, a threadgroup-scope GEMM and no Vulkan interop. lmxxf's HLSL chain shows it can be exact. No retail date was found.

**Not real-time routes.**
- ONNX/Windows ML: static shapes, fragmented EPs, no FP8 guarantees, 161 ms at 256².
- WebGPU: 25–50× slower than tensor-core paths.
- These remain the right choice for offline or still-image tooling and for cross-checking.

**Fidelity ceiling.** Exact NVIDIA arithmetic (F13 truncated FP8 accumulation) cannot be reproduced inside AMD or Intel matrix units, which accumulate to FP32. So the practical ceiling for hardware-speed non-NVIDIA paths is the about 45–49 dB already reached. Exact emulation costs about 6× per product, which is why the exact routes run at 0.07–1 s per frame.

### Gaps

- **Driver dumps:**
  - the proprietary NVIDIA and Intel Windows drivers' cooperative-matrix configuration lists (types, shapes, accumulators)
  - whether AMD Windows exposes FP16 accumulators for FP8
  - whether NVIDIA or Intel proprietary drivers ship `VK_EXT_cooperative_matrix_maintenance1` yet
- **D3D12:** the SM 6.10 retail date, and per-vendor LinAlg data-type tables.
- **ONNX:** whether FP8 works in the MIGraphX, TensorRT-RTX or OpenVINO EPs for this graph. No real-time ONNX DLSS-NR measurement exists. ncnn was not researched.
- **Turing/Ampere:** no measured Vulkan cooperative-matrix performance for a network of this shape.

---

## 4. Open-weight, distilled or quantized replacements, and similar academic or community models

### Takeaway

One open-weights student model exists: **OpenNR** (MakeDecisionWorth/OpenNR-ReShade, MIT, first release 2026-09-27).
- It is "small networks trained to imitate" DLSS-NR: a roughly 2.6 MB convolutional U-net with a global branch.
- It runs as D3D11/D3D12 compute, with experimental Vulkan, on any DX11-class GPU. It was tested on Arc A770 and A750.
- Its teacher is the original network, run through a SYCL bridge.
- No training code, dataset or fidelity metric is published.

The subagent's search had concluded that no student model existed; OpenNR corrects that. Apart from OpenNR:
- The Hugging Face repos named "open-dlss5-nr" are "Coming soon" placeholders whose 148 MB file looks like NVIDIA's weights repackaged.
- The quantization work is partial: an INT8 ViT ONNX variant, an INT8/FP16 mix for RDNA2, and INT8 and block-skip studies with measured dB losses.

The academic analogues (Intel's EPE, one-step image-to-image diffusion, neural supersampling) are not drop-in real-time replacements.

### Cited Findings

- **OpenNR (MakeDecisionWorth/OpenNR-ReShade).** MIT; releases v0.1.0 (2026-09-27) to v0.2.1 (2026-09-30).
  - [V] A ReShade add-on that runs "a small neural network" to "re-balance local tone, local contrast and colour". Models: "1 pass" and "2 passes".
  - [V] It runs at up to 704 lines and upsamples its correction.
  - [V] It supports D3D11 and D3D12; Vulkan is experimental. It needs "A GPU with DirectX 11 compute shaders" and was tested on Arc A770/A750.
  - [V] "Use the teacher model" shows "the large model OpenNR's own models are trained to imitate", running in the SYCL bridge.
  - Source: [README](https://github.com/MakeDecisionWorth/OpenNR-ReShade); [releases](https://github.com/MakeDecisionWorth/OpenNR-ReShade/releases)
  - [V] Shipped weights: `models/1pass` and `models/2pass`, about 2.63 MB in total for `1pass`.
  - [V] The `model.txt` layer list describes a four-level encoder–decoder: 16 → 32 → 64 → 128 channels, mid blocks at 128, skip concatenations, and a "global" branch at 64×64 (g0–g2). Output is 4 channels for 1-pass and 12 for 2-pass.
  - Source: [models](https://github.com/MakeDecisionWorth/OpenNR-ReShade/tree/main/models)
  - [V] Training code, data and quality metrics are not in the repository. — [repo tree](https://github.com/MakeDecisionWorth/OpenNR-ReShade)
- **Hugging Face "open" repos.**
  - [V] alpindale/open-dlss5-nr (2026-09-03) and sekkit/open-dlss5-nr (2026-09-05) say "Coming soon." under an `openmdw-1.1` tag. Both hold the same `dlss5nr.safetensors` of 147,943,434 bytes. — [alpindale](https://huggingface.co/alpindale/open-dlss5-nr); [sekkit](https://huggingface.co/sekkit/open-dlss5-nr) (via subagent; the alpindale file list was confirmed directly)
  - [C] The subagent's inference: given the size, the file is probably NVIDIA's weights repacked, not an open-trained model.
  - [C] The subagent's searches on 2026-10-07 for "dlss distill", "dlss5 student", "dlss5 lora", "dlss5 dataset", "neural remaster" and similar returned no repositories, and Hugging Face lists no student models.
- **Quantized or reduced variants of the original network, with measured effect.**
  - [M] taowen's ONNX INT8-ViT: 234 MB against 301 MB in FP16, and slower on the 890M (176.5 against 161.5 ms); "flat and dark regions may show added grain". — [dlss5-onnx](https://huggingface.co/taowen/dlss5-onnx)
  - [M] mauri870: simulated INT8 loses 1–2.6 dB; dropping the E4M3 rounding loses 10.5 dB; model scale 50% gives 35.29 dB. — [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md)
  - [V] mauri870/dlssnr-pytorch includes `int8.py` (W8A8 simulation), `int8_blocks.py`, `ablate.py` and `m4_gain.py`, but publishes no result tables for them. The RDNA3 README mentions experiments on "what an int8 or low-rank network would lose"; only the INT8 range is reported. — [dlssnr-pytorch](https://github.com/mauri870/dlssnr-pytorch)
  - [M] Intel notes: INT8 weights are fine (head correlation about 0.992); activations are not, except at the bottleneck. — [phase23](https://github.com/Uzbekunknown/dlss-nr-on-intel/blob/master/notes/phase23-integer-weights.md); [int8-bottleneck](https://github.com/Uzbekunknown/dlss-nr-on-intel/blob/master/notes/improve-int8-bottleneck.md)
  - [M] lmxxf: skipping ViT blocks costs 3.3 dB; multi-pass skip lists score 34–46 dB against its own three-pass output. — [README](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)
  - [V] shakhbazian (RDNA2): INT8 for selected matrix multiplications plus FP16, with no metric. — [OptiScaler-RDNA2NR](https://github.com/shakhbazian/OptiScaler-RDNA2NR)
  - [V] gggz114514 (B580): INT8 experiments were not adopted; the fast mode drops FP8 emulation. — [repo](https://github.com/gggz114514-oss/dlss5nr-b580-intelarc)
- **Signs that NVIDIA's own model was distilled.**
  - [C] inarikami's Hugging Face repo gives a weight-record identifier containing "Blend_Quantize_With_Teacher". That suggests NVIDIA itself trained with a teacher and quantization; this reading comes from the name only. — [inarikami](https://huggingface.co/inarikami/dlss5-nr-reverse-engineering) (via subagent)
- [V] **Obstacle to training on the original graph.** Five `*.prior` tensors in the 310.8.0 model contain NaN/Inf, which "makes gradient-based use of this graph fail" unless sanitised (issue closed 2026-10-04). — [OpenDLSS-NR #5](https://github.com/maanHimself/OpenDLSS-NR/issues/5)
- **Tools that could generate training pairs exist; no published datasets were found.**
  - [V] Examples: video2dlssnr (MIT) and ComfyUI DLSS 5 nodes. — [video2dlssnr](https://github.com/DaniilSokolyuk/video2dlssnr); [ComfyUI-DLSS5-Enhancer](https://github.com/Blueforcer/ComfyUI-DLSS5-Enhancer)
- **Academic and industry models of similar purpose** (via subagent; licences as GitHub reports them on 2026-10-07).
  - [V] Intel ISL "Enhancing Photorealism Enhancement" (Richter et al. 2021): no licence file. — [arXiv 2105.04619](https://arxiv.org/abs/2105.04619); [isl-org/PhotorealismEnhancement](https://github.com/isl-org/PhotorealismEnhancement)
  - [V] StreamDiffusion (Apache-2.0). — [repo](https://github.com/cumulo-autumn/StreamDiffusion)
  - [V] img2img-turbo (MIT), a one-step image-to-image model. — [repo](https://github.com/GaParmar/img2img-turbo)
  - [V] NSRD (CVPR 2024, MIT), neural supersampling. — [repo](https://github.com/Riga2/NSRD)
  - [V] RTX Remix, an asset remaster tool rather than a per-frame neural pass. — [dxvk-remix](https://github.com/NVIDIAGameWorks/dxvk-remix)
  - [C] A Hugging Face Space, "dlss-5-anything", imitates the look offline with FLUX.2-klein and the prompt "make it more realistic"; it is not real-time. — [victor/dlss-5-anything](https://huggingface.co/spaces/victor/dlss-5-anything)

### Inferences

- **OpenNR is the only truly open (MIT code plus MIT-distributed weights) cross-vendor option today.** Its convolutional network is a few MB rather than 141 MiB, and it targets tone, local contrast and colour.
  - By design it cannot reproduce DLSS-NR's generative detail: noise injection, the Swin/ViT capacity and the skin/structure controls.
  - Its fidelity against the teacher is unmeasured, and the student weights are trained on the teacher's outputs.
  - It is the realistic template for a "DLSS-5-class look on every GPU", including RDNA2, GTX 16 and Alchemist.
- **A path to a stronger open student exists, but nobody has taken it publicly.** The pieces are in place:
  - a differentiable PyTorch reference that matches NVIDIA at 45.7–49.1 dB (mauri870)
  - output-pair generators
  - the noise and temporal specification (OpenDLSS-NR)
  - What is missing is a dataset and training compute; the NaN priors must also be sanitised.
- **Quantizing the original network is a poor lever.** INT8 is no faster on RDNA3, slower on the 890M ONNX path, and breaks the high-resolution activations. Reducing model resolution, pre-upscale placement and multi-pass control are the levers that work.

### Gaps

- OpenNR's training method, data, GPU cost and any PSNR or perceptual score against DLSS-NR. Its README only says the student "imitates".
- Whether any private or Discord-only distillation efforts exist. None were found on GitHub or Hugging Face.
- Low-rank or pruning results for the original network: tools exist, results are unpublished.
- Real-time speed and size of the academic analogues; the subagent did not check them.

---

## 5. Community reports: quality and stability of the AMD ports against NVIDIA, and the Intel Arc and RTX 20/30 attempts

### Takeaway

**Quality.**
- The open AMD ports publish objective fidelity of 45–49 dB PSNR (SSIM 0.996–0.998) against NVIDIA's DLL on an RTX 5090. Frame-to-frame variation is "about as much as NVIDIA's".
- danielblnc's closed runtime publishes none. Users report early flicker (fixed), ghosting in Async mode, a weaker effect on faces in pre-upscale mode, and colour differences between runtimes.
- Some flicker reproduces on NVIDIA's own DLL too.

**Stability is the weak point on Windows.** Reports include:
- multi-second GPU stalls and driver timeouts
- full-system freezes after 20–60 minutes
- VRAM doubling
- antivirus flags on the closed binary
- "driver resets" in mochizuki's Windows preview

**Linux.** The native Vulkan ports (mochizuki, mauri870) are reported as the smoothest, while danielblnc's HIP runtime is hard to use under Proton.

**Intel Arc.** The ports work but were called a "Diashow" (slideshow) in press, about 2.4 fps at 1080p on a 140V on 2026-09-20. They later improved to 30 fps at 800×450.

**RTX 20/30.** Patched builds run but have no published performance numbers, and Guru3D saw crashes and black-outs.

**Vendors.** I found no statement from AMD or Intel and no NVIDIA takedown of any port.

### Cited Findings

#### Quality against NVIDIA

- [M] **Objective metrics from the open ports.**

  | Port | PSNR (1080p / 1440p / 4K) | Other |
  |---|---|---|
  | mochizuki | 45.56 / 47.99 / 49.06 dB | sequences up to 51.6 dB |
  | mauri870 RDNA3 | 45.47 / 47.71 / 49.02 dB | — |
  | lmxxf | 47.55 dB (1080p) | — |
  | dlssnr-pytorch | 45.70 / 48.26 / 49.10 dB | — |
  | MLX-DLSS | — | 0.004–0.005 MAE |

  Sources: [mochizuki NGX verification](https://github.com/mochizuki0323/DLSSNR-AMD/blob/main/docs/ngx-verification/NGX-VERIFICATION.md); [README-RDNA3](https://github.com/mauri870/DLSSNR-RDNA3/blob/rdna3/README-RDNA3.md); [lmxxf](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting); [dlssnr-pytorch](https://github.com/mauri870/dlssnr-pytorch); [MLX-DLSS](https://github.com/iamwavecut/MLX-DLSS)
- **danielblnc's runtime.**
  - [C] The developer: "Output quality is very similar … though there are still some effects that may not be working 100%". — [README](https://github.com/danielblnc/DLSS-NR-on-AMD)
  - [M] zmodelerlover measured a tile-extrapolation blow-up on that AMD port (max correction 4.16 against a frame mean of 0.13) and added a 0.25 "Residual Limit" as a guard.
  - [V] It also documents what differs from NVIDIA's composition. On NVIDIA, the screen shows a RenoDX/OptiScaler composition of the DLL output, not the raw output. In danielblnc's runtime the style input was pinned to 0 until v0.3.3.
  - Source: [nvidia-parity.md](https://github.com/zmodelerlover/dlss5-neural-amd/blob/master/docs/nvidia-parity.md)
- **User reports** (via the subagent, cross-checked against issue bodies where noted).
  - [C] Flicker in early builds: on a 9070 XT, "flicker and run at 13fps @ 1440P and 20fps @ 1080P" (2026-09-04). After v0.2.15: "Flickering is fixed for me" (2026-09-07). — [#30](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/30)
  - [C] Ghosting in Async mode; the developer says "async is only good for photo mode". — [#69](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/69)
  - [C] Pre-upscale mode "only changes the lighting but does not touch the faces" (2026-09-27). It "does not have the same effect as others with a Nvidia Card" (2026-10-05). — [#211](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/211)
  - [C] "shimmering on faces when moving" on a 9060 XT (2026-09-26). — [#200](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/200)
  - [C] lmxxf replayed a reported brightness flicker in Yimo/Aniimo on a real RTX 5090 with the original DLL. The original "produced almost the same response" (2026-10-03). — [lmxxf #13](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting/issues/13)
  - [M] Intel port: the effect differs by game (Tekken 7 and DoA5 gain texture; MK1 loses face detail), and "Whether any of it is better is taste, not measurement". — [README](https://github.com/Uzbekunknown/dlss-nr-on-intel)

#### Performance reports

Beyond the developers' numbers in §1 and §2.
- [C] RX 9070 XT, early builds: 4K jobs of 109–156 ms (6–9 fps) and 1080p jobs of 31–47 ms (2026-09-04). — [#3](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/3)
- [C] RX 9070, TLOU1: jobs of 62–94 ms at a 1440p render and 15–32 ms at 720p. — [#62](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/62)
- [C] RX 7900 XTX: 5–10 fps at 4K with FSR4 Ultra Performance (2026-09-04). — [#10](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/10)
- [C] RX 7900 XTX: 15 fps at 1080p Ultra Performance, 22 fps overclocked (v0.2.15). — [#117](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/117)
- [C] RX 7800 XT, Witcher 3 at 1080p: Inline mode 10 fps; Async mode 190–280 fps "obviously not playable when you start moving" (2026-09-30). — [#222](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/222)
- [C] Press: TechTimes reported Cyberpunk at 3440×1440 going from 11 to 50 fps on v0.4.0 (2026-09-28). — [TechTimes](https://www.techtimes.com/articles/328149/20260928/dlss-5-neural-rendering-hits-amd-radeon-74-performance-leap-one-build.htm)
- [C] Claims of "60+ FPS in 4K" and "121 base fps 4K Ultraperformance" depend on frame generation or Ultra Performance mode plus YouTube videos, and are unverified. — [#130](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/130); [#204](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/204)

#### Stability

- [C/M] RX 9060 XT with danielblnc: single jobs held the GPU for 3.8–4.2 s every 10–30 minutes; two close together "locked the whole PC". zmodelerlover added a stand-down watchdog in v0.7.8 and Async timing in v0.7.10. — [CHANGELOG](https://github.com/zmodelerlover/dlss5-neural-amd/blob/master/CHANGELOG.md)
- [C] Full system freeze after about 20–60 minutes on a 9070 XT at 4K, v0.6.0 (2026-10-04). — [#232](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/232)
- [C] Driver timeout in TLOU2. — [#178](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/178)
- [C] Frequent GPU wait timeouts. — [#62](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/62)
- [C] VRAM went from about 51% to 103% with the mod installed but NR off (RX 9070 XT, 3440×1440, v0.2.14). — [#106](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/106)
- [C] MSFS 2024 runs out of memory. — [#192](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/192)
- [C] Windows Defender reported "Trojan:Win32/Wacatac.H!ml" on v0.2.16. This is probably a heuristic flag, but the binary is closed. — [#133](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/133)
- [V] mochizuki's own warning for Windows: "Game crashes, driver resets and other unexpected problems can happen". — [README](https://github.com/mochizuki0323/DLSSNR-AMD)

#### Linux and Proton

- [C] danielblnc's runtime under Proton: "You cannot use hip on proton" (2026-09-08). A diagnostic PE-to-ELF HIP bridge reached dispatch, but "The image was mostly black". — [#39](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/39); [PR #141](https://github.com/danielblnc/DLSS-NR-on-AMD/pull/141)
- [C] mochizuki on a 9060 XT with Proton GE 11-7: "performance is great, quality too" (2026-09-25). — [#1](https://github.com/mochizuki0323/DLSSNR-AMD/issues/1)
- [C] A ROG Ally (RDNA3) works through mauri870's port (2026-10-03). — [#3](https://github.com/mochizuki0323/DLSSNR-AMD/issues/3)

#### Intel Arc

- [C] ComputerBase (2026-09-20) headlined "Diashow" (slideshow): 2.4 fps at 1080p, 12.5–13.5 fps at 640×360, Tekken 7 at 10.5 fps. — [ComputerBase](https://www.computerbase.de/news/grafikkarten/dlss-5-auf-intel-arc-neural-rendering-wird-zur-diashow.99479/)
- [M] **Superseded** by the developer's own later numbers: 30 fps at 800×450 on 2026-09-27. — [README](https://github.com/Uzbekunknown/dlss-nr-on-intel)
- [C] HWCooling headlined that the support was "Vibe Coded by AI". — [HWCooling](https://www.hwcooling.net/en/dlss-5-now-running-on-intel-gpus-too-ai-wrote-the-support/)
- [M] B580 at 720p: base frame time of 55–60 ms, "not yet" 30 fps. — [gggz114514](https://github.com/gggz114514-oss/dlss5nr-b580-intelarc)
- [M] A750/A770 (SYCL): "for looking and comparing, not for playing". — [SYCL bridge](https://github.com/MakeDecisionWorth/DLSSNR-SYCL-Bridge)

#### RTX 20/30

- [C] Guru3D (2026-08-31): mixed game compatibility, a display-signal loss in GTA V, and "no standardized performance or image-quality analysis". — [Guru3D](https://www.guru3d.com/story/leaked-dlss-5-runs-on-rtx-20-and-rtx-30-gpus/)
- [C] A user claim: RX 7000 behaves the "same as on rtx 30 series" because neither has an FP8 pipe (2026-09-04). — [#22 comment](https://github.com/danielblnc/DLSS-NR-on-AMD/issues/22)

#### Vendors

- [V] All the main port repositories were live and not archived on 2026-10-07 (GitHub API). — [danielblnc](https://github.com/danielblnc/DLSS-NR-on-AMD); [OpenDLSS-NR](https://github.com/maanHimself/OpenDLSS-NR)
- [C] TechTimes (2026-09-28) quotes NVIDIA's Rajal Maharaj on Sept 4: "DLSS 5 will come to RTX 40-series GPUs at a later date". Not verified at source. — [TechTimes](https://www.techtimes.com/articles/328149/20260928/dlss-5-neural-rendering-hits-amd-radeon-74-performance-leap-one-build.htm)
- I found no AMD or Intel statement.

### Inferences

- **For users, the measured gap between the open AMD ports and NVIDIA (45–49 dB) is likely invisible next to two other factors:**
  - integration choices: pre- or post-upscale placement, the proxy and tone encoding, composition, and temporal smoothing
  - the frame rate
- **Most "quality" complaints are about integration, not the network.** Reports of a "weaker effect on faces" and of ghosting trace back to pre-upscale mode or Async timing.
- **The open ports are more trustworthy than the most popular runtime.** The closed danielblnc runtime has the most users, the most stability reports and no published fidelity data. The open Vulkan ports (mochizuki, mauri870) have the best-documented fidelity, and on Linux the best reported experience.
- **Intel and RTX 20/30 have no polished port yet.** Users' experience there matches the hardware analysis in §2:
  - Intel's kernels run at a small fraction of peak.
  - RTX 20/30 depends on an unmeasured patched DLL.

### Gaps

- **Missing sources:**
  - Reddit (r/Amd, r/IntelArc, r/nvidia, r/LocalLLaMA) and Discord content: no threads were retrieved
  - Phoronix forum, Digital Foundry and Hardware Unboxed coverage: none found
  - Tom's Hardware and VideoCardz articles: unreadable
- **Missing data:**
  - per-model fps for RTX 2080, 3060, 3080 and 4060/4070 with the patched DLL
  - any Arc A770 gaming report beyond the SYCL bridge's own numbers
  - a controlled side-by-side (same scene, same settings) of danielblnc's output against NVIDIA's
