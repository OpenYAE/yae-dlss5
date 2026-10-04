Third-party components
======================

This package bundles the third-party components listed below. Each keeps its
own license. The full license texts are in this folder and, for the 64-bit
host components, in payload\host64\Licenses (installed into the game folder
as host64\Licenses).

Not included and not distributed: the game and its executable, the NVIDIA NGX
runtime (nvngx_dlss.dll, nvngx_dlssnr.dll) and LumeniteFX. The installer
downloads them from their original sources at installation time.


OptiScaler with DLSS Neural Rendering ("OptiScaler_DLSSNR") by dag
-----------------------------------------------------------------
Files:    payload\host64\winmm.dll
          payload\host64\nvngx.dll_dlssnr.dll
          payload\host64\OptiScaler.ini
License:  GNU General Public License v3.0 (OptiScaler-LICENSE.txt)
Source:   https://github.com/Dagherbou/OptiScaler_DLSSNR
          Release v0.2.0-dlssnr, tag v0.2.0-dlssnr,
          commit 973761621353b99bee3dc7d4bb27b117fef2644f
Upstream: https://github.com/optiscaler/OptiScaler (GPL-3.0)

All OptiScaler binaries in this package (winmm.dll, nvngx.dll_dlssnr.dll and
everything in payload\host64\OptiScaler) are byte-identical to the files in
OptiScaler-DLSSNR-v0.2.0.zip from that release. OptiScaler.dll is renamed to
winmm.dll so that the host loads it; its contents are not changed.
OptiScaler.ini is the release's configuration file adapted for this package.
The complete corresponding source code is available at the tag above.

OptiScaler uses FreeType, licensed under the FreeType License (FTL):
    Portions of this software are copyright (c) The FreeType Project
    (https://freetype.org). All rights reserved.
License:  FreeType-LICENSE.txt

The DLSS Neural Rendering colour composition is derived from RenoDX by
clshortfuse (https://github.com/clshortfuse/renodx), MIT License.
Attribution:  payload\host64\Licenses\RenoDX_ATTRIBUTION.txt


Components shipped with OptiScaler (payload\host64\OptiScaler\)
---------------------------------------------------------------
Intel XeSS SDK 2.0, XeSS Frame Generation SDK and XeLL SDK
    libxess.dll, libxess_dx11.dll, libxess_fg.dll, libxell.dll
    Copyright (C) 2025 Intel Corporation
    License: Intel Simplified Software License (XeSS_LICENSE.txt)

AMD FidelityFX SDK
    amd_fidelityfx_*.dll
    License: FidelityFX_v2_LICENSE.md

Microsoft DirectX 12 Agility SDK
    D3D12_OptiScaler\D3D12Core.dll
    License: DirectX_LICENSE.txt


ReShade by crosire (Patrick Mours)
----------------------------------
Files:    payload\opengl32.dll (x86), payload\host64\dxgi.dll (x64)
License:  BSD 3-Clause (ReShade-LICENSE.txt)
Source:   https://github.com/crosire/reshade

Shader headers in payload\reshade-shaders\Shaders:
    ReShade.fxh, ReShadeUI.fxh  - crosire/reshade-shaders, CC0-1.0
    DrawText.fxh                - by kingreic1992, distributed with
                                  crosire/reshade-shaders


DLSS5-Feeder by Jean-Laurent Rouzies
------------------------------------
Files:    payload\dlss5-feed.addon32, payload\host64\dlss5-feed-host64.exe,
          payload\reshade-shaders\Shaders\DLSS5_Feed.fx,
          payload\Verify-DLSS5Feeder.ps1
License:  MIT (DLSS5-Feeder-LICENSE.txt)
Includes portions derived from dlss5-dx11-bridge by NIGos (MIT).


LumeniteFX by umar-afzaal (downloaded at install time, not bundled)
-------------------------------------------------------------------
License:  LumeniteFX-LICENSE.md, LumeniteFX-NOTICE.txt
Source:   https://github.com/umar-afzaal/LumeniteFX


NVIDIA DLSS / DLSS Neural Rendering (downloaded at install time, not bundled)
----------------------------------------------------------------------------
nvngx_dlss.dll:   https://github.com/NVIDIA/DLSS
nvngx_dlssnr.dll: see VERSIONS.txt for the pinned source and checksums.
These files remain subject to NVIDIA's license terms.
