# YNB — the YAE Neural Bridge protocol, version 1

> **Status: draft of 2026-10-07, approved for implementation on 2026-10-08 (P6).** Contract C3 of the program
> (`project-empty/docs/NR_PT_Program.md`): owned by this repository, consumed by **glhook** (phase D2,
> the x86 side) and **`yae-nr-host64.exe`** (phase D3, the x64 side). The draft is frozen for
> implementation at milestone M0 and **frozen as v1 at the start of D3**; until then a change is made
> here and nowhere else. Every default value marked "proposed" is a starting point for measurement in
> D2.5/D3, not a measured optimum.

YNB moves one frame of *You Are Empty* per present from the 32-bit game process, where glhook captures
it before the HUD, to a 64-bit process that runs an optional AA stage and NR through `yae-neural`, and
moves the result back — on the GPU, without the game's render thread waiting in steady state. It is a
successor of two working designs and borrows from both (§14): DLSS5-Feeder's 32-bit transport
(protocol v11, MIT) and the x86 bridge of zmodelerlover's `dlss5-neural-amd` (protocol v6, MIT).

## 1. Scope and conventions

**Parties.** The **client** is glhook, an x86 `opengl32.dll` proxy loaded by `YOU_ARE_EMPTY.exe`
(`ds2render.dll` imports `OPENGL32.dll`, so the game folder's copy decides what loads —
`yae-QindieGL/tools/remix/README.md` lines 8–9). The **host** is `yae-nr-host64.exe`, a 64-bit process
started by the client.

**What crosses.** Per frame: up to five input images and one output image (shared GPU memory, or shared
CPU memory in the fallback of §10), two fence values, one slot record in a shared control block, and one
pipe message. Per session: a handful of lifecycle messages.

**What never crosses.** The HUD layer (it stays private to the client, which composites it over the
output); GL object names (only NT handle values cross); NVIDIA's weights or any model data (they stay in
the host's folder, P4); pointers, `HANDLE`, `size_t` or `bool` fields — handle values travel as `u64`,
booleans as `u32`.

**Keywords.** MUST, MUST NOT, SHOULD, MAY as in RFC 2119.

**Encoding.** Little-endian; packed structures with fixed-width fields; every structure's size and
every field offset in this document is asserted at compile time on both sides
(`static_assert(sizeof…)`, `offsetof`), as `dlss5-neural-amd` does for its wire structures
(`core/x86bridge/bridge_ipc.h` lines 69–84).

**Image conventions** (the frame contract C2 of `yae-neural`). Every shared image is stored as its
producer wrote it, and the producer **declares the image origin** — `ORIGIN_BOTTOM_LEFT` (row 0 is the
bottom of the picture, OpenGL's convention) or `ORIGIN_TOP_LEFT` (row 0 is the top) — once per
generation in BUILD and again per frame in the slot record (§6.2, §7.2). The origin applies to every
input and to the output, which comes back in the same origin. **Neither side flips images or vectors to
convert between conventions**: the host passes the declared origin to `yae-neural`
(`yn_frame`'s origin field, `YN_ORIGIN_BOTTOM_LEFT` / `YN_ORIGIN_TOP_LEFT`) and to its AA stage; whether
a consumer reorients internally is its own business. **glhook declares `ORIGIN_BOTTOM_LEFT`**: it copies
OpenGL's framebuffer row for row and composites the output back the same way. Pixel centres are at
+0.5; sizes are in pixels of the input resolution. Motion vectors point **from the current pixel to its
position in the previous frame** (`prev = cur + mv`), in pixels, **in the image's own coordinates**
(for a bottom-left image +y points up the screen, towards higher rows), and do **not** include jitter;
jitter offsets use the same coordinates as the vectors. That is the convention of the DLSS programming
guide (NVIDIA DLSS SR Programming Guide 310.6.0, 2026-03-31, §3.6.1–3.6.2: vectors current → previous
in pixels, `MVJittered` = 0; §3.7.3: jitter in the vectors' coordinate system), generalised to either
origin.

**Matrix conventions.** 4×4, `f32`, column-major, OpenGL clip conventions (clip-space z in [−w, w],
window depth in [0, 1] under the default `glDepthRange`), exactly as glhook observes them on the GL
matrix stacks.

**Terms.**

| Term | Meaning |
|---|---|
| frame id `n` | `u64`, 1 for the first frame submitted in a session, +1 per submitted frame, never reused in a session; it is also the fence value of that frame |
| slot `s` | `n mod K`; one set of shared resources |
| `K` | slot count, 2–4 (proposed default 3 for the GPU transport, 2 for the CPU copy) |
| generation `g` | `u64`, +1 for every BUILD; resources, slot records and frames carry it |
| session | one host process serving one client process |

## 2. Processes and launch

### 2.1 Files and discovery

| Path (relative to the game folder) | What |
|---|---|
| `opengl32.dll` | glhook (x86) |
| `yae-nr.ini` | the client's settings, among them `host_path` |
| `yae-nr\yae-nr-host64.exe` | the host (x64) |
| `yae-nr\yae_neural.dll`, `yae-nr\models\*.ynw` | the runtime and the extracted models (host only; models never in git or a release — P4) |
| `yae-nr\logs\` | `glhook.log`, `host.log` |

The client MUST locate the host by `host_path` (default `yae-nr\yae-nr-host64.exe`, resolved against the
directory of glhook's own module), never through `PATH` or the game's working directory. It MUST check
that the file is a PE32+ image and SHOULD check its SHA-256 against `yae-nr\manifest.json` when the
installer wrote one (D4). The v1 chain's `host64\` folder is not reused: the two profiles must not
collide.

### 2.2 Launch (normative)

The client starts the host in the background as soon as the game's window context exists, so that the
model is loaded while the game shows its menus; the game keeps rendering in pass-through meanwhile (the
Feeder's lesson: a host started on the render thread froze every apply and resize for seconds —
`src/dlss5-feed32.cpp` lines 954–962 at tag v1.18.0-beta.2).

1. Generate a 16-byte random **session nonce** (`BCryptGenRandom`).
2. `CreateProcessW(host_path, "<host_path> --ynb 1 --client-pid <decimal pid> --nonce <32 hex digits>",
   NULL, NULL, FALSE, CREATE_SUSPENDED | CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT, NULL, <host
   directory>, …)`. Handles are not inherited.
3. **Affinity.** `GetProcessAffinityMask(GetCurrentProcess(), &process, &system)`, then
   `SetProcessAffinityMask(hostProcess, system)`. A child inherits its parent's affinity
   (learn.microsoft.com, SetProcessAffinityMask, Remarks: "Process affinity is inherited by any child
   process"), and DS2's `ds2kernel.dll` pins the game to CPU 0 with
   `SetProcessAffinityMask(GetCurrentProcess(), 1)` (`yae-QindieGL/tools/remix/README.md` lines 86–96).
   A pinned helper froze the Remix bridge at the logo; the v1 helper has the same exposure (D1.5). The
   mask may exceed the parent's: it must only be a subset of the system mask (same page).
4. `AssignProcessToJobObject(job, hostProcess)` for a job with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, so
   the host dies with the game even when the game crashes.
5. `DuplicateHandle(GetCurrentProcess(), GetCurrentProcess(), hostProcess, &value, SYNCHRONIZE |
   PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_DUP_HANDLE, FALSE, 0)`; `value` goes into HELLO. The host
   uses it to watch the client and to duplicate handles into it, so it needs no access to the game
   process's DACL (the Feeder's protocol v4 change — `src/feed_ipc.h` lines 149–154).
6. `ResumeThread`.

The host, at start, MUST: re-check its own affinity and widen it to the system mask if it is narrower
(logged); run at `NORMAL_PRIORITY_CLASS` with no busy-waiting thread (the Remix bridge server's
high-priority busy-waits are what starved the pinned game); call
`SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_APPLICATION_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32)`; create
the pipe of §2.4; and wait for the client (`launch_timeout_ms`, §8).

The client's own worker threads stay on the game's CPU mask; they MUST block on kernel objects, never
spin.

### 2.3 Adapter

The client reads the GL device's LUID and node mask with `glGetUnsignedBytevEXT(GL_DEVICE_LUID_EXT
(0x9599))` and `GL_DEVICE_NODE_MASK_EXT (0x959A)` (part of `GL_EXT_memory_object_win32`; `GL_LUID_SIZE_EXT`
= 8) and sends them in HELLO. The host MUST create every device it uses for the session (D3D12 for
allocation, the `yae-neural` Vulkan device) on the adapter with that LUID and echo the LUID in
HELLO_ACK; a mismatch is `ADAPTER_MISMATCH` and the client stays in pass-through. On AMD the GL LUID was
measured to match the DXGI adapter exactly (`dlss5-neural-amd` `docs/opengl-route.md` line 70); the
Feeder's multi-GPU failure mode is exactly a host on the other GPU ("cross-process fence import failed —
most often the host opened a different GPU than the game", issue #100). A client that cannot read the LUID
sends 0 and is offered only the CPU-copy transport (§10).

### 2.4 Channels

- **The pipe** `\\.\pipe\ynb-<client pid>-<nonce hex>`: lifecycle messages and one FRAME notification per
  submitted frame (§7). Created by the host with `FILE_FLAG_FIRST_PIPE_INSTANCE`,
  `PIPE_REJECT_REMOTE_CLIENTS`, byte mode, overlapped I/O, a DACL for the current user only, an
  out-buffer of 4 KiB and an in-buffer of `K × 40` bytes, so the client can run at most `K` frames
  ahead before a FRAME write blocks (the Feeder bounds its backlog the same way —
  `host/dlss5-feed-host64.cpp` lines 3140–3165 at v1.18.0-beta.2).
- **The control block**: an unnamed pagefile-backed section created by the host and duplicated into the
  client (HELLO_ACK), 64 KiB, laid out in §6. Per-frame data, live controls, states and statistics.
- **Events**: `ev_done` (auto-reset, host → client: `host_progress` advanced), duplicated into the
  client, so the client's pacing wait (§8) blocks instead of spinning.
- **Process handles**: each side holds the other's and treats its signalled state as "peer gone".

### 2.5 Lifetime

One host per client process. The host exits when the client's process handle is signalled, the pipe
breaks, QUIT arrives, or its job is closed. On every exit path it controls, the host MUST first wait for
its own queue (bounded by `gpu_wait_cap_ms`) and then CPU-signal `fence_out` to `UINT64_MAX`, releasing
any wait a non-conforming client might hold (the Feeder's exit rule — `host/dlss5-feed-host64.cpp` lines
3868–3878).

## 3. Handshake and versioning

```
client                                   host
  │  connect pipe                          │
  │── HELLO ──────────────────────────────►│  check nonce, pid, version; open devices on the LUID
  │◄──────────────────────────── HELLO_ACK ─│  control block, events, process handle, backend, model
  │── BUILD (g) ──────────────────────────►│  allocate K slot sets + fences (first BUILD)
  │◄──────────────────────────── BUILD_ACK ─│  handles, sizes, formats
  │  import into GL, prove a round trip    │
  │── BUILD_DONE (g, result) ─────────────►│
  │── FRAME (n, g, s) ────────────────────►│  … one per submitted frame
  │── DROP (g) ───────────────────────────►│  resize, context change, disable
  │◄───────────────────────────── DROP_ACK ─│
  │── QUIT ───────────────────────────────►│
```

- **Major version.** Both sides MUST refuse a peer whose `major` differs, with `VERSION_MISMATCH` logged
  as "install both halves from one release" — a mismatched pair must fail at the header, not desync the
  pipe (the Feeder: `src/feed_ipc.h` lines 66–67; `dlss5-neural-amd` rejects older versions explicitly,
  `docs/x86bridge.md` line 72).
- **Minor version.** Additive only. A minor version may append fields to a message body (the receiver
  accepts `body_bytes` ≥ the v1.0 size and ignores the tail) and may add message kinds, which a sender
  uses only after the peer announced that minor version in HELLO/HELLO_ACK. The control block carries its
  own version, header size and slot stride (§6); readers use the strides, never their own `sizeof`.
- **Identity.** The host refuses a HELLO whose nonce or PID differs from its command line, and a pipe
  client whose `GetNamedPipeClientProcessId` differs from that PID (`SECURITY`).
- **Build ids.** Each side logs the other's build id and version string on connect.

## 4. Shared resources

### 4.1 Allocation authority

**The host allocates every shared resource.** GL memory objects are import-only — a GL process cannot
export memory that another API opens — so the direction is forced (the Feeder: `docs/PLAN-OPENGL.md`
§1 and §5; `dlss5-neural-amd`: `docs/opengl-route.md`, "Why the route has the shape it has"). It is also
the better direction: the resources are born with exactly the flags the host's consumers need.

### 4.2 Handle types

| Type (bit) | Host allocates with | Client imports with | Host's Vulkan imports with | Status (2026-10-07) |
|---|---|---|---|---|
| `HT_D3D12_RESOURCE` (1) — **preferred** | `ID3D12Device::CreateCommittedResource` + `CreateSharedHandle`; fences `CreateFence(…, D3D12_FENCE_FLAG_SHARED)` | `GL_HANDLE_TYPE_D3D12_RESOURCE_EXT`; fences `GL_HANDLE_TYPE_D3D12_FENCE_EXT` | `VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_RESOURCE_BIT`; `VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D12_FENCE_BIT` (timeline) | NVIDIA x86 cross-process: in production in the Feeder; AMD: measured in a 64-bit process; Intel: unverified |
| `HT_D3D11_IMAGE` (2) | a D3D11 device, `D3D11_RESOURCE_MISC_SHARED_NTHANDLE`; fences `ID3D11Device5::CreateFence(…, D3D11_FENCE_FLAG_SHARED)` | `GL_HANDLE_TYPE_D3D11_IMAGE_EXT`; fences as D3D12 fences | `VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT` | AMD x86: measured by `dlss5-neural-amd` (bytes cross both ways, colour only, synchronised by `glFinish`) |
| `HT_OPAQUE_WIN32` (4) | Vulkan export, `VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT` | `GL_HANDLE_TYPE_OPAQUE_WIN32_EXT` | native | standard GL/VK interop; not measured for YAE |
| `HT_CPU_COPY` (8) | a shared section (§10) | `glReadPixels` into PBOs / `glTexSubImage2D` from PBOs | upload/readback buffers | fallback; works wherever GL 2.1 PBOs work |

The client announces in HELLO which types it can import, in its order of preference; the host picks the
first it can serve and answers with one type for the session. **The import's handle type MUST match the
allocation API exactly**: AMD's driver accepts `GL_HANDLE_TYPE_OPAQUE_WIN32_EXT` for a D3D12 resource
handle without an error, creates the storage and reports the FBO complete — and is wrong; "the import
succeeded" proves nothing about the type (`dlss5-neural-amd` `docs/opengl-route.md` lines 83–86). A
client MUST NOT retry an import with a different type "to see what works"; it reports `IMPORT_FAILED` in
BUILD_DONE and the host offers the next type in a new BUILD.

### 4.3 The slot set

Each of the `K` slots holds one set:

| Resource (bit) | DXGI format | GL internal format | Writer → reader | Content and rules |
|---|---|---|---|---|
| `RES_COLOR` (1) | `R8G8B8A8_UNORM` (28) for `COLOR_LDR_PROXY`; `R16G16B16A16_FLOAT` (10) for `COLOR_LINEAR_HDR` | `GL_RGBA8` / `GL_RGBA16F` | client → host | the frame before the HUD, in the declared origin; LDR proxy = the display-referred bytes the game wrote, never linearised, never BGRA; alpha ignored |
| `RES_DEPTH` (2) | `R32_FLOAT` (41) | `GL_R32F` | client → host | the window-space depth as written (0 = near, 1 = far or cleared); not linearised; `depth_reversed` = 0 for DS2 |
| `RES_MOTION` (4) | `R16G16_FLOAT` (34) | `GL_RG16F` | client → host | pixels at input resolution, current → previous, in the image's own coordinates (§1), without jitter; absent when the host computes motion (`MV_HOST`, §10) |
| `RES_MOTION_FLAGS` (8) | `R8_UNORM` (61) | `GL_R8` | client → host | 1 = history valid at `cur + mv`; 0 = no history (a zero vector means "history at this pixel", not "no history" — contract C2) |
| `RES_CONTROL_MASK` (16) | `R8_UNORM` (61) | `GL_R8` | client → host | 0…1, multiplies the NR effect in composition (weapon, sky, particles, faces and creatures) |
| `RES_OUTPUT` (32) | as `RES_COLOR` | as `RES_COLOR` | host → client | the result in the colour's encoding, size and origin (v1: output size = input size) |

The **HUD layer is not part of the set**: it is the client's private set of GL targets (`Phase_D2_GLHook.md`,
"Как устроено").

**Memory (calculation, not a measurement).** At 18 bytes per pixel for a full LDR set:
1920×1080 — 37.3 MB per slot, 112 MB for `K` = 3; 3440×1440 — 89.2 MB per slot, 268 MB for `K` = 3;
3840×2160 — 149 MB per slot, 448 MB for `K` = 3; allocation alignment adds to these. This is GPU memory;
whether an imported memory object also consumes the 32-bit client's virtual address space is
driver-specific and is measured in D2.5.

### 4.4 Creation (host, normative)

Every shared texture is a committed resource on a `D3D12_HEAP_TYPE_DEFAULT` heap with
`D3D12_HEAP_FLAG_SHARED`; `DIMENSION_TEXTURE2D`, 1 mip, 1 sample, `D3D12_TEXTURE_LAYOUT_UNKNOWN`;
`D3D12_RESOURCE_FLAG_ALLOW_SIMULTANEOUS_ACCESS`, plus `ALLOW_UNORDERED_ACCESS` on any resource the host
writes from compute and `ALLOW_RENDER_TARGET` on any resource it renders into; initial state `COMMON`.
The handle comes from `CreateSharedHandle(resource, NULL, GENERIC_ALL, NULL, &h)`; the size the GL import
needs is `GetResourceAllocationInfo(0, 1, &desc).SizeInBytes` — the client has no D3D12 device to ask
(the Feeder: `host/dlss5-feed-host64.cpp` lines 2959–2999). The host logs one line per resource with its
format, flags and size (the Feeder's issue #43 came down to one of four textures born without a flag,
and no log said which). The two fences are created with the first BUILD and live for the session.

### 4.5 Import (client, normative)

For each resource: `glCreateMemoryObjectsEXT`; `GL_DEDICATED_MEMORY_OBJECT_EXT = GL_TRUE` **before** the
import (a D3D12 resource handle backs exactly one resource — `dlss5-neural-amd` rule 2);
`glImportMemoryWin32HandleEXT(mem, size, <type of §4.2>, handle)`; `glTexStorageMem2DEXT` (or the DSA form
when present); the GL error queue drained after every call, and the failing stage and error recorded for
BUILD_DONE (the Feeder's `import_stage`/`import_err`, `src/feed_gl.h` lines 211–214, 473–538). For each
fence: `glGenSemaphoresEXT` + `glImportSemaphoreWin32HandleEXT(GL_HANDLE_TYPE_D3D12_FENCE_EXT)`; the value
is set with `glSemaphoreParameterui64vEXT(GL_D3D12_FENCE_VALUE_EXT)` before **every** signal and wait.
Every texture listed in a signal or a wait uses `GL_LAYOUT_GENERAL_EXT`, which pairs with
`ALLOW_SIMULTANEOUS_ACCESS` (`src/feed_gl.h` lines 563–594).

Before BUILD_DONE reports success, the client SHOULD prove the set once: write a pattern into
`RES_COLOR` of slot 0, signal, and read the host's echo back through `RES_OUTPUT` (the loopback host and
`--transport-only` do exactly that). "Imported without error" is not proof (§4.2).

### 4.6 Crossing processes

Handles created in the host are duplicated into the client with
`DuplicateHandle(GetCurrentProcess(), h, clientProcess, &value, 0, FALSE, DUPLICATE_SAME_ACCESS)`, using
the process handle the client gave in HELLO (it carries `PROCESS_DUP_HANDLE`); only if that value is 0
does the host fall back to `OpenProcess`. The `u64` value travels in BUILD_ACK and is valid only in the
client.

### 4.7 Handle and object lifetime (normative)

- **HANDLE-1 — never close an imported NT handle.** The client MUST keep every imported memory and fence
  handle open until the process exits, on every vendor. AMD's driver takes no reference of its own:
  closing the handle after the import faulted inside the driver, from a driver thread, at an
  unpredictable later moment — 3 faults in 8 runs with closing, 0 in 8 without (`dlss5-neural-amd`
  `docs/opengl-route.md` lines 74–80). The cost is bounded and logged: at most `6 × K + 2` handles per
  generation.
- **HANDLE-2 — GL objects die in their own context.** Textures, memory objects and semaphores are deleted
  only while the context that created them is current; otherwise they are forgotten and die with the
  context (the Feeder: `docs/PLAN-OPENGL.md` §4 and §8; `dlss5-neural-amd`: everything keyed on
  `wglGetCurrentContext()`).
- **HANDLE-3 — the host keeps a generation's resources until DROP_ACK** and may release them after; the
  client's open handles keep the allocations alive for as long as it still holds GL objects on them.

### 4.8 What is known per vendor (2026-10-07)

| Fact | NVIDIA | AMD | Intel |
|---|---|---|---|
| `GL_EXT_memory_object_win32` + `GL_EXT_semaphore_win32` in a legacy game's context | present on every DLSS-capable driver; NVIDIA hands GL-1.x-era games a 4.6 compatibility context (Feeder `docs/PLAN-OPENGL.md` lines 97–106, 366–371) | present on RX 9070 XT, Adrenalin 26.8.1, in 4.6 compatibility and 3.3 core contexts (`opengl-route.md` lines 61–65) | not confirmed on the Windows driver; Mesa lists the `_win32` variants only for zink and d3d12; the Feeder's verifier warns they "do not exist on an iGPU" (`payload/Verify-DLSS5Feeder.ps1` line 1522) |
| D3D12 resource → GL, **x86, cross-process** | verified: Worms Ultimate Mayhem, 32-bit GL, 3840×2160, RTX 5090, driver 616.56, 0.13 ms of game CPU per frame (`docs/PLAN-OPENGL.md` lines 3–10) | 64-bit only: all six formats import and are FBO-complete, bytes identical both ways; in a 32-bit process the measured type is `D3D11_IMAGE` (`core/x86bridge/gl32.inc` lines 1–9) | unknown |
| D3D12 fence → GL semaphore, `glWaitSemaphoreEXT` | verified (Feeder) | verified in a 64-bit process (`opengl-route.md` line 69) | unknown |
| `GL_DEVICE_LUID_EXT` matches the DXGI adapter | not checked here (in the extension) | yes (`opengl-route.md` line 70) | unknown |
| Closing an imported NT handle | allowed by the extension | faults (HANDLE-1) | unknown |

The rows marked unknown are D2.5's and the hardware lab's to fill.

### 4.9 Orientation, channel order, encoding (normative)

- **Declare, do not flip.** GL's framebuffer origin is bottom-left. The client copies the framebuffer
  into the shared images row for row (row 0 = the bottom of the screen), declares `ORIGIN_BOTTOM_LEFT`,
  writes motion vectors and jitter in the same coordinates, and composites the output back row for row.
  The host and `yae-neural` take the origin from the slot record. `dlss5-neural-amd` flips in both
  directions because its consumer expects a top-down image — "the inversions do not cancel"
  (`docs/opengl-route.md` lines 162–164, its proof at 250–253); YNB carries the origin instead, so a
  missing or extra flip cannot happen on the client side.
- **RGBA, never BGRA.** GL has no sized BGRA8 format; a blit writes semantic RGBA, so a BGRA crossing
  would put blue where the host expects red with no error anywhere — "a picture that looks plausible until
  the sky is orange" (`opengl-route.md` lines 157–161; the Feeder: `docs/PLAN-OPENGL.md` §1, "BGRA8").
- **No sRGB conversion.** `GL_FRAMEBUFFER_SRGB` and the scissor test are disabled around every copy and
  restored after (the Feeder's state guard, `src/feed_gl.h` lines 631–665).
- **Multisampled framebuffers** are resolved into the single-sample shared image by the copy blit
  itself (same rectangle, no mirroring, which is what a resolving blit requires — `opengl-route.md` lines
  202–210). DS2's video settings have no multisampling key (the `scr_*` variables in
  `yae-research/notes/console_variables.md`), but a driver override can still force it, hence the rule.

## 5. Synchronisation

### 5.1 Fences and values

Two shared fences per session: **`fence_in`** (client → host: "the inputs of frame `n` are written")
and **`fence_out`** (host → client: "the output of frame `n` is written, or frame `n` was abandoned").
The value of frame `n` on both is `n` (the Feeder's scheme: `src/feed_ipc.h` lines 19–34). Values only
grow; a new generation continues the sequence (BUILD_ACK carries the current base).

### 5.2 Rules (normative)

- **SYNC-1 — values are frame ids.** The client signals `fence_in = n` exactly once per submitted frame;
  the host signals `fence_out = n` exactly once per frame it accepted — on the GPU when it produced an
  output, on the CPU (`ID3D12Fence::Signal`) when it abandons the frame.
- **SYNC-2 — no unconfirmed GPU wait in the client.** The client MUST NOT queue `glWaitSemaphoreEXT` on
  `fence_out` for value `v` before it has observed `host_progress ≥ v` (§6) on the CPU. The wait is still
  issued — it carries the cross-API acquire of the output texture — but it can no longer hang:
  `glWaitSemaphoreEXT` has no timeout (`src/feed_gl.h` lines 584–594), and a wait nobody satisfies wedges
  the game's whole GPU queue, `Present` included, until the driver resets the GPU — which the Feeder saw
  as a system-wide freeze (`src/dlss5-feed32.cpp` lines 1036–1043; `host/dlss5-feed-host64.cpp` lines
  3868–3873).
- **SYNC-3 — no unconfirmed GPU wait in the host.** The host MUST NOT make a queue wait on `fence_in`
  value `v` before it has observed the fence's completed value `≥ v` on the CPU
  (`ID3D12Fence::SetEventOnCompletion` or `vkWaitSemaphores`, each with `in_wait_cap_ms`).
  `dlss5-neural-amd` confirms GL's signal on the CPU before ever letting its queue wait on it, because "a
  queue wait that never completes is a hung queue that nothing can release" (`opengl-route.md` lines
  180–187). The host waits on a thread of its own, so the pipe is never left unread (the reason the
  Feeder had dropped its CPU wait: its single serve thread stopped reading the pipe — issue #15).
- **SYNC-4 — every accepted frame advances.** For every FRAME it accepts, the host eventually sets the
  slot's `state` to DONE, ABANDONED or FAILED, its `done_frame_id` to `n`, and `host_progress` to `n`,
  and signals `ev_done`; `fence_out ≥ n` holds whenever `host_progress ≥ n`. The client uses an output
  only when the slot says DONE for that frame id.
- **SYNC-5 — input reuse.** The client writes slot `s` for frame `n` only when `in_consumed ≥ n − K`
  (the host has finished reading the inputs of the frame that held the slot before). Otherwise frame `n`
  is not submitted (§8).
- **SYNC-6 — output reuse.** An output of frame `m` may be read (composited) only during the presents of
  frames `m` … `m + K − 1`, and every `fence_in` signal lists, besides the slot's inputs, every output
  texture read since the previous signal. Because the host writes slot `m mod K`'s output next for frame
  `m + K`, and only after observing `fence_in ≥ m + K` (SYNC-3), every read of output `m` has completed
  by then (GL executes in order).
- **SYNC-7 — flush after signal.** Every `glSignalSemaphoreEXT` is followed by `glFlush`; without it the
  signal can sit in the client's command buffer while the host waits (`src/feed_gl.h` lines 579–581).

### 5.3 One frame, pipelined (the default)

```
client, frame n (s = n mod K)                       host
──────────────────────────────────────────────      ─────────────────────────────────────────────
capture point (before the first HUD draw):
  in_consumed ≥ n − K ?  else: not submitted (§8)
  copy colour/depth into slot s (row for row),
  write motion, flags, mask
  glSignalSemaphoreEXT(fence_in = n, inputs of s +
      outputs read since the last signal); glFlush
  write slot record (seqlock), in_submitted = n
  FRAME(n, g, s) ─────────────────────────────────►  validate (g, s, n = last + 1)
HUD draws → the private HUD layer                    CPU-wait fence_in ≥ n      (SYNC-3)
…                                                    read slot record (seqlock)
SwapBuffers:                                         AA stage → yae-neural → output of s;
  m = n − 1                                          the queue signals fence_out = n
  host_progress ≥ m ? else pacing wait on ev_done    completion thread: CPU-wait fence_out ≥ n
  slot(m).state == DONE and done_frame_id == m ?        → state DONE, done_frame_id = n,
    glWaitSemaphoreEXT(fence_out = m, output of m)        in_consumed = n, host_progress = n,
    composite output m + HUD layer                        timings; SetEvent(ev_done)
  else composite pass-through (§8)
  real SwapBuffers
```

The result shown is one frame old. That is what lifted the ~35 fps ceiling of the Feeder's same-frame
contract on 32-bit games (issue #15; the Feeder's README, `async_home`), and `dlss5-neural-amd` measured
**+16 % to +41 %** with pipelining across three games, without smearing, because the whole image is
replaced and stays self-consistent (`docs/x86bridge.md` line 95). The client composites the HUD layer of
frame `m` over the output of `m` by default (a consistent, one-frame-old picture); compositing the HUD of
frame `n` instead (fresher HUD, world one frame behind it) is a client setting (D2's Q2).

### 5.4 One frame, same-frame

As above, except that at `SwapBuffers` `m = n`: the client waits (on `ev_done`, at most `frame_wait_ms`)
for the result of the frame it just submitted. The game's frame then carries the whole round trip. It
exists for measurement and for hosts fast enough to hide it.

## 6. The control block

One section of 64 KiB, created by the host, duplicated into the client. The layout is fixed for major
version 1; fields are grouped in 64-byte lines so that each line has one writer. Strings are ASCII,
zero-padded. "c" = written by the client, "h" = by the host.

### 6.1 Header (offset 0, 512 bytes)

| Offset | Size | Type | Field | W | Meaning |
|---:|---:|---|---|---|---|
| 0 | 4 | u32 | `magic` | h | `0x43424E59` ("YNBC") |
| 4 | 2 | u16 | `major` | h | 1 |
| 6 | 2 | u16 | `minor` | h | 0 |
| 8 | 4 | u32 | `block_size` | h | bytes in use: `header_size + K × slot_stride` |
| 12 | 4 | u32 | `header_size` | h | 512 |
| 16 | 4 | u32 | `slot_count` | h | `K` |
| 20 | 4 | u32 | `slot_stride` | h | 512 |
| 24 | 8 | u64 | `qpc_frequency` | h | `QueryPerformanceFrequency`, shared by both sides' timestamps |
| 32 | 16 | u8[16] | `session_nonce` | h | as on the command line |
| 48 | 16 | — | reserved | | zero |
| 64 | 8 | u64 | `client_heartbeat_qpc` | c | QPC at the client's latest present |
| 72 | 8 | u64 | `in_submitted` | c | the latest frame id signalled on `fence_in` and announced |
| 80 | 8 | u64 | `generation` | c | the client's current generation |
| 88 | 4 | u32 | `client_state` | c | §6.4 |
| 92 | 4 | u32 | `client_status` | c | status code, §11.2 |
| 96 | 4 | u32 | `client_flags` | c | `CF_PIPELINED` 1, `CF_NR_ON` 2 (the user's A/B), `CF_JITTER` 4, `CF_OVERLAY` 8, `CF_HUD_FRESH` 16 |
| 100 | 4 | u32 | `pass_through_reason` | c | status code while the client shows pass-through, else 0 |
| 104 | 24 | — | reserved | | zero |
| 128 | 8 | u64 | `host_heartbeat_qpc` | h | QPC, updated at least every 100 ms while the host runs |
| 136 | 8 | u64 | `host_progress` | h | the latest frame id the host finished with (DONE, ABANDONED or FAILED); `fence_out ≥` it |
| 144 | 8 | u64 | `in_consumed` | h | the latest frame id whose inputs the host no longer reads |
| 152 | 8 | u64 | `generation_built` | h | the latest generation the host allocated |
| 160 | 4 | u32 | `host_state` | h | §6.4 |
| 164 | 4 | u32 | `host_status` | h | status code |
| 168 | 4 | u32 | `yn_backend` | h | `yn_backend` value AUTO chose (contract C1); 0 = none |
| 172 | 4 | u32 | `aa_stage` | h | `AA_NONE` 0, `AA_DLAA` 1, `AA_FSR_NATIVE` 2, `AA_XESS_NATIVE` 3 |
| 176 | 8 | u64 | `controls_revision_applied` | h | the latest controls revision the host applied |
| 184 | 8 | — | reserved | | zero |
| 192 | 4 | f32 | `gpu_ms_aa` | h | rolling mean over 120 frames |
| 196 | 4 | f32 | `gpu_ms_nr` | h | rolling mean (from `yn_session_stats`) |
| 200 | 4 | f32 | `gpu_ms_total` | h | rolling mean |
| 204 | 4 | f32 | `host_cpu_ms` | h | rolling mean of the host's CPU time per frame |
| 208 | 4 | f32 | `in_wait_ms` | h | rolling mean of the CPU wait for `fence_in` |
| 212 | 4 | f32 | `round_trip_ms` | h | rolling mean, `qpc_submit` → done |
| 216 | 4 | u32 | `frames_done` | h | session counter |
| 220 | 4 | u32 | `frames_abandoned` | h | session counter |
| 224 | 4 | u32 | `stalls` | h | GPU jobs over `gpu_wait_cap_ms` |
| 228 | 4 | u32 | `vram_mb` | h | the host process's local video memory use, if the API reports it |
| 232 | 24 | — | reserved | | zero |
| 256 | 8 | u64 | `controls_seq` | c | seqlock of the controls: odd while the client writes them |
| 264 | 8 | u64 | `controls_revision` | c | strictly increasing; the host ignores a revision ≤ the applied one |
| 272 | 4 | u32 | `nr_enabled` | c | 0/1 — the A/B switch |
| 276 | 4 | u32 | `style` | c | 0 A, 1 B, 2 C (model variants) |
| 280 | 4 | f32 | `intensity` | c | 0…1 |
| 284 | 4 | f32 | `tone` | c | 0…1 |
| 288 | 4 | f32 | `structure` | c | 0…1 |
| 292 | 4 | f32 | `skin` | c | 0…1, −1 = follow `structure` |
| 296 | 4 | u32 | `auto_mask` | c | 0/1 |
| 300 | 4 | f32 | `model_scale` | c | 0.25…1.0 |
| 304 | 4 | u32 | `composition` | c | 0 replace, 1 ratio (contract C2) |
| 308 | 4 | f32 | `residual_limit` | c | 0 = off |
| 312 | 4 | u32 | `aa_request` | c | `AA_*` the user asked for |
| 316 | 4 | f32 | `aa_sharpness` | c | 0…1 |
| 320 | 4 | u32 | `debug_view` | c | 0 off, 1 input colour, 2 output, 3 difference ×20, 4 motion, 5 control mask, 6 motion flags |
| 324 | 60 | — | reserved | | zero |
| 384 | 64 | char[64] | `host_message` | h | the latest status in words, for the overlay |
| 448 | 64 | char[64] | `client_message` | c | the latest status in words, for the host log |

Controls follow the program's conventions (the NVIDIA rule for history: a change of `style` or
`auto_mask`, or of `tone`/`structure`/`skin` by more than 1e-5, resets the temporal history — the
runtime applies it, contract C2). Non-finite floats reject the whole update; finite values are clamped to
the ranges above (`dlss5-neural-amd` `docs/x86bridge.md` lines 53 and 82: clamping, monotonic
revisions, no replay).

### 6.2 Slot record (offset `512 + s × 512`, 512 bytes)

| Offset | Size | Type | Field | W | Meaning |
|---:|---:|---|---|---|---|
| 0 | 8 | u64 | `seq` | c | seqlock: odd while the client writes the client part |
| 8 | 8 | u64 | `frame_id` | c | `n` |
| 16 | 8 | u64 | `generation` | c | `g` |
| 24 | 4 | u32 | `flags` | c | `SF_RESET` 1, `SF_CAMERA_CUT` 2, `SF_MV_VALID` 4, `SF_DEPTH_VALID` 8, `SF_MASK_VALID` 16, `SF_FLAGS_VALID` 32, `SF_JITTERED` 64, `SF_MV_HOST` 128, `SF_BARRIER` 256 (the frame read the back buffer after the capture — diagnostic) |
| 28 | 4 | u32 | `reset_reason` | c | 0 none, 1 first frame, 2 level load, 3 camera cut, 4 resize/generation, 5 controls, 6 user, 7 frames without a world in between |
| 32 | 64 | f32[16] | `view_cur` | c | world → eye of the main camera (the depth-0 modelview transform) |
| 96 | 64 | f32[16] | `proj_cur` | c | the world projection, **without** jitter |
| 160 | 64 | f32[16] | `view_prev` | c | the previous submitted frame's `view_cur` |
| 224 | 64 | f32[16] | `proj_prev` | c | the previous submitted frame's `proj_cur` |
| 288 | 8 | f32[2] | `jitter_px` | c | sub-pixel jitter applied this frame, pixels, in the image's own coordinates (§1), within [−0.5, 0.5]; 0 without jitter (the DLSS convention, Programming Guide §3.7.3) |
| 296 | 8 | f32[2] | `jitter_px_prev` | c | the previous frame's |
| 304 | 4 | f32 | `mv_scale_x` | c | 1.0 |
| 308 | 4 | f32 | `mv_scale_y` | c | 1.0 |
| 312 | 4 | f32 | `z_near` | c | world projection, informational |
| 316 | 4 | f32 | `z_far` | c | 0 = infinite |
| 320 | 8 | u64 | `qpc_capture` | c | QPC at the capture point |
| 328 | 8 | u64 | `qpc_submit` | c | QPC after the FRAME write |
| 336 | 4 | f32 | `client_cpu_ms` | c | CPU time of the capture work |
| 340 | 4 | f32 | `client_gpu_ms` | c | GPU time of the capture passes (timer query of an earlier frame), 0 if unknown |
| 344 | 4 | u32 | `world_draws` | c | diagnostic |
| 348 | 4 | u32 | `hud_draws` | c | diagnostic (of the previous frame) |
| 352 | 4 | u32 | `frame_class` | c | 1 gameplay, 2 cutscene, 3 other world |
| 356 | 4 | u32 | `origin` | c | `ORIGIN_TOP_LEFT` 1, `ORIGIN_BOTTOM_LEFT` 2 — applies to every input of this frame and to its output; equal to BUILD's for the generation (glhook: 2) |
| 360 | 24 | — | reserved | | zero |
| 384 | 4 | u32 | `state` | h | `SLOT_FREE` 0, `SLOT_IN_PROGRESS` 2, `SLOT_DONE` 3, `SLOT_ABANDONED` 4, `SLOT_FAILED` 5 |
| 388 | 4 | u32 | `result` | h | `R_NEURAL` 1, `R_PASS` 2 (output = input), `R_ERROR` 3, `R_TRANSPORT` 4 (`--transport-only`) |
| 392 | 8 | u64 | `done_frame_id` | h | the frame id the state refers to |
| 400 | 8 | u64 | `qpc_host_start` | h | |
| 408 | 8 | u64 | `qpc_host_done` | h | |
| 416 | 4 | f32 | `gpu_ms_aa` | h | this frame |
| 420 | 4 | f32 | `gpu_ms_nr` | h | this frame |
| 424 | 4 | f32 | `in_wait_ms` | h | this frame |
| 428 | 4 | u32 | `status` | h | status code |
| 432 | 80 | — | reserved | | zero |

**Publishing.** The client writes a slot only under SYNC-5, sets `seq` odd, writes offsets 8–383, sets
`seq` even with a release store, then sends FRAME. The host, on FRAME, reads `seq` (even), copies
offsets 8–383, re-reads `seq`; a changed `seq` or a `frame_id` other than the message's is a
`PROTOCOL_ERROR` (the client must not touch a submitted slot). The host part (384–511) has the host as its
only writer.

### 6.3 Why the matrices cross

The host does not need them for NR, which consumes motion vectors. They cross for three reasons: the
CPU-copy transport, where the host computes motion from depth and the matrices instead of receiving it
(`SF_MV_HOST`, §10); camera-cut detection on the host side as a second opinion; and diagnostics (a host
debug view that reprojects depth with the matrices must match the client's vectors).

### 6.4 States

| `client_state` | | `host_state` | |
|---|---|---|---|
| 0 | none | 0 | none |
| 1 | connecting | 1 | starting (devices, model) |
| 2 | building | 2 | ready (HELLO done) |
| 3 | running | 3 | built |
| 4 | pass-through (with `pass_through_reason`) | 4 | running |
| 5 | disabled by the user | 5 | stood down (with `host_status`) |
| | | 6 | exiting |

## 7. Messages

### 7.1 Framing

Every message is a 16-byte header followed by `body_bytes` bytes.

| Offset | Size | Type | Field |
|---:|---:|---|---|
| 0 | 4 | u32 | `magic` = `0x31424E59` ("YNB1") |
| 4 | 2 | u16 | `major` = 1 |
| 6 | 2 | u16 | `minor` = 0 |
| 8 | 4 | u32 | `kind` |
| 12 | 4 | u32 | `body_bytes` |

| Kind | Name | Direction | Body bytes | Reply |
|---:|---|---|---:|---|
| 1 | HELLO | c → h | 128 | HELLO_ACK |
| 2 | HELLO_ACK | h → c | 192 | — |
| 3 | BUILD | c → h | 64 | BUILD_ACK |
| 4 | BUILD_ACK | h → c | 64 + 32 × `slots` × R | — |
| 5 | BUILD_DONE | c → h | 32 | — |
| 6 | FRAME | c → h | 24 | none (the answer is in the control block) |
| 7 | DROP | c → h | 16 | DROP_ACK |
| 8 | DROP_ACK | h → c | 16 | — |
| 9 | QUIT | c → h | 0 | — |
| 10 | NOTIFY | h → c | 32 | none; unsolicited |

The pipe carries one conversation: a request whose reply has not been read will be answered into
whatever the requester reads next (`dlss5-neural-amd` `core/x86bridge/bridge_io.h` lines 45–53). The
client therefore reads the pipe on a worker thread that dispatches replies and NOTIFY; its render thread
only ever writes FRAME, bounded by `frame_write_timeout_ms`, and never waits for a reply. A message with a
wrong magic, an unknown major, an unknown kind or a `body_bytes` below its kind's v1 size is a
`PROTOCOL_ERROR` and ends the session.

### 7.2 Bodies

**HELLO** (128 bytes)

| Offset | Size | Type | Field | Meaning |
|---:|---:|---|---|---|
| 0 | 4 | u32 | `client_pid` | |
| 4 | 4 | u32 | `caps` | `CAP_MEMORY_OBJECT_WIN32` 1, `CAP_SEMAPHORE_WIN32` 2, `CAP_STENCIL_TEXTURING` 4, `CAP_DRAW_BUFFERS_BLEND` 8, `CAP_TIMER_QUERY` 16, `CAP_NV_DX_INTEROP2` 32 |
| 8 | 8 | u64 | `client_process` | handle value valid in the host (§2.2 step 5); 0 = duplication failed |
| 16 | 4 | u32 | `luid_low` | `GL_DEVICE_LUID_EXT` bytes 0–3; 0 with `luid_high` 0 = unknown |
| 20 | 4 | i32 | `luid_high` | bytes 4–7 |
| 24 | 4 | u32 | `node_mask` | `GL_DEVICE_NODE_MASK_EXT` |
| 28 | 4 | u32 | `gl_vendor_id` | PCI vendor derived from `GL_VENDOR`: `0x10DE`, `0x1002`, `0x8086`, 0 unknown |
| 32 | 4 | u32 | `gl_version` | major × 100 + minor of the game's context |
| 36 | 4 | u32 | `handle_types` | `HT_*` bits the client can import |
| 40 | 4 | u32 | `preferred_handle_type` | one `HT_*` bit |
| 44 | 4 | u32 | `requested_slots` | 2–4 |
| 48 | 4 | u32 | `flags` | `HELLO_PIPELINED` 1, `HELLO_JITTER` 2, `HELLO_DEBUG` 4 |
| 52 | 4 | u32 | reserved | 0 |
| 56 | 8 | u64 | `client_build` | build id |
| 64 | 16 | u8[16] | `session_nonce` | |
| 80 | 32 | char[32] | `client_version` | e.g. "glhook 0.1.0" |
| 112 | 16 | — | reserved | 0 |

**HELLO_ACK** (192 bytes)

| Offset | Size | Type | Field | Meaning |
|---:|---:|---|---|---|
| 0 | 4 | u32 | `result` | status code; 0 = accepted |
| 4 | 2 | u16 | `host_major` | |
| 6 | 2 | u16 | `host_minor` | |
| 8 | 4 | u32 | `host_pid` | |
| 12 | 4 | u32 | `handle_type` | the one `HT_*` bit chosen for the session |
| 16 | 8 | u64 | `host_process` | handle value valid in the client (`SYNCHRONIZE`) |
| 24 | 4 | u32 | `luid_low` | the adapter the host opened |
| 28 | 4 | i32 | `luid_high` | |
| 32 | 8 | u64 | `ctrl_section` | section handle valid in the client |
| 40 | 4 | u32 | `ctrl_size` | 65536 |
| 44 | 4 | u32 | `slots` | `K` granted |
| 48 | 4 | u32 | `host_caps` | `HC_AA_DLAA` 1, `HC_AA_FSR` 2, `HC_AA_XESS` 4, `HC_NR` 8, `HC_MV_HOST` 16, `HC_TRANSPORT_ONLY` 32 |
| 52 | 4 | u32 | `yn_api_version` | `yn_get_version()`: major << 16 \| minor |
| 56 | 4 | u32 | `yn_backend` | AUTO's choice; 0 = none (no NR: transport or AA only) |
| 60 | 4 | u32 | `aa_stage` | `AA_*` available by default |
| 64 | 8 | u64 | `ev_done` | event handle valid in the client |
| 72 | 8 | u64 | `host_build` | |
| 80 | 32 | char[32] | `model_id` | e.g. "dlssnr-310.8.0"; empty without a model |
| 112 | 32 | char[32] | `host_version` | |
| 144 | 48 | — | reserved | 0 |

**BUILD** (64 bytes)

| Offset | Size | Type | Field | Meaning |
|---:|---:|---|---|---|
| 0 | 8 | u64 | `generation` | previous + 1 |
| 8 | 4 | u32 | `width` | input |
| 12 | 4 | u32 | `height` | |
| 16 | 4 | u32 | `out_width` | v1: = `width` |
| 20 | 4 | u32 | `out_height` | v1: = `height` |
| 24 | 4 | u32 | `color_encoding` | `COLOR_LDR_PROXY` 1, `COLOR_LINEAR_HDR` 2 |
| 28 | 4 | u32 | `color_format` | DXGI value |
| 32 | 4 | u32 | `resources` | `RES_*` bits wanted |
| 36 | 4 | u32 | `mv_source` | `MV_CLIENT` 1, `MV_HOST` 2 |
| 40 | 4 | u32 | `transport` | `T_GPU` 1, `T_CPU_COPY` 2 |
| 44 | 4 | u32 | `flags` | `BUILD_DEPTH_REVERSED` 1 (never for DS2) |
| 48 | 4 | f32 | `paper_white` | `COLOR_LINEAR_HDR` only; else 0 |
| 52 | 4 | u32 | `origin` | `ORIGIN_TOP_LEFT` 1, `ORIGIN_BOTTOM_LEFT` 2 (glhook); every resource of the generation, the output included |
| 56 | 8 | — | reserved | 0 |

**BUILD_ACK** (64 bytes, then the descriptors)

| Offset | Size | Type | Field | Meaning |
|---:|---:|---|---|---|
| 0 | 4 | u32 | `result` | status code |
| 4 | 4 | u32 | `slots` | `K` |
| 8 | 8 | u64 | `generation` | echoed |
| 16 | 8 | u64 | `fence_in` | handle valid in the client (the same value for the whole session) |
| 24 | 8 | u64 | `fence_out` | idem |
| 32 | 8 | u64 | `fence_base` | the value both fences hold now; this generation's first frame is `fence_base + 1` |
| 40 | 4 | u32 | `resources` | `RES_*` granted; R = number of bits |
| 44 | 4 | u32 | `output_format` | the DXGI format actually created for `RES_OUTPUT` |
| 48 | 8 | u64 | `cpu_section` | `T_CPU_COPY` only, else 0 |
| 56 | 8 | u64 | `cpu_section_size` | bytes |

Then `slots × R` descriptors of 32 bytes, slot-major, resources in the order of their bits:

| Offset | Size | Type | Field | Meaning |
|---:|---:|---|---|---|
| 0 | 4 | u32 | `resource` | one `RES_*` bit |
| 4 | 4 | u32 | `dxgi_format` | |
| 8 | 8 | u64 | `handle` | valid in the client; 0 in `T_CPU_COPY` |
| 16 | 8 | u64 | `size` | GPU: the allocation size the import needs; CPU: the byte offset in the section |
| 24 | 4 | u32 | `row_pitch` | `T_CPU_COPY` only |
| 28 | 2 | u16 | `width` | |
| 30 | 2 | u16 | `height` | |

**BUILD_DONE** (32 bytes): `generation` u64 @0; `result` u32 @8 (status code); `failed_resource` u32 @12
(`RES_*`, 0 none); `failed_slot` u32 @16; `stage` u32 @20 (1 memory object, 2 handle import, 3 texture
storage, 4 FBO completeness, 5 semaphore import, 6 the round-trip proof); `gl_error` u32 @24;
reserved u32 @28.

**FRAME** (24 bytes): `frame_id` u64 @0; `generation` u64 @8; `slot` u32 @16; `flags` u32 @20
(`FRAME_TRANSPORT_ONLY` 1: copy colour to output and skip AA and NR this frame).

**DROP** (16 bytes): `generation` u64 @0; `reason` u32 @8 (status code); reserved u32 @12.
**DROP_ACK** (16 bytes): `generation` u64 @0; `result` u32 @8; reserved u32 @12.

**NOTIFY** (32 bytes): `event` u32 @0 (`EV_STOOD_DOWN` 1, `EV_DEVICE_LOST` 2, `EV_BACKEND_CHANGED` 3,
`EV_RESUMED` 4); `status` u32 @4; `generation` u64 @8; `frame_id` u64 @16; reserved u64 @24.

## 8. Watchdog, pacing and failure handling

### 8.1 Timeouts and budgets (proposed defaults)

| Parameter | Proposed | Side | Meaning and origin |
|---|---:|---|---|
| `launch_timeout_ms` | 60 000 | c | the host must open its pipe; the Feeder had to raise 15 s to 60 s for slow disks and antivirus scans (`src/dlss5-feed32.cpp` lines 1003–1011) |
| `hello_timeout_ms` | 15 000 | c | HELLO → HELLO_ACK |
| `build_timeout_ms` | 60 000 | c | BUILD → BUILD_ACK, includes the model load |
| `frame_write_timeout_ms` | 250 | c | a FRAME write can block only if the host stopped reading; the host's reader never waits on the GPU (SYNC-3), so this is far below the Feeder's 4 000 ms, which had to exceed its serve loop's 2 000 ms GPU waits |
| `pace_budget_ms` | max(4, 1.5 × median present interval), at most 33 | c | how long the pipelined client waits on `ev_done` for a late result before showing pass-through for this frame |
| `frame_wait_ms` | 50 | c | the same-frame client's wait |
| `in_wait_cap_ms` | 1 000 | h | the host's CPU wait for `fence_in` before abandoning the frame |
| `gpu_wait_cap_ms` | 2 000 | h | the host's CPU wait for its own GPU work; the Feeder's `gpu_timeout_ms` default, and the `dlss5-neural-amd` stall watch (single jobs of 3.8–4.2 s froze games and two close together locked a PC; it stands down after 2 s) |
| `host_hang_ms` | 3 000 | c | host heartbeat age with frames outstanding that counts as a hang |
| relaunch backoff | 1 s, 5 s, 30 s; at most 3 per session | c | the Feeder's retry schedule (`src/dlss5-feed32.cpp` lines 946–948) |

### 8.2 Pacing and pass-through (normative)

- **Never show a stale result.** A frame whose result is not ready goes out as the game drew it
  (pass-through: the captured colour of the same frame plus its HUD layer), never as a repeat of an older
  output composited with a newer HUD. `dlss5-neural-amd` removed exactly that option ("repeat the last
  result instead of waiting") from its OpenGL route.
- **Wait before skipping.** In steady state the client paces on the host: it waits up to
  `pace_budget_ms` on `ev_done` rather than skip. Frames that alternate between NR and no NR strobe —
  measured by `dlss5-neural-amd`: about 189 fps presented, about 64 distinct images per second, about 5 000
  of 7 554 frames uncorrected; with pacing 0 frames uncorrected (`docs/opengl-route.md` lines 188–201,
  261–266).
- **Hysteresis.** If more than 10 % of the frames of the last 60 miss the budget, the client enters
  pass-through for at least 1 000 ms with `TOO_SLOW` and tells the user through the overlay (lower the
  model scale); three such trips within 60 s keep it in pass-through until the user re-enables NR. In
  pass-through the client keeps submitting at most one frame in flight, so the host's timings stay
  visible.
- **What pass-through means outside gameplay** (menus, films, loading screens — no world phase): no
  capture, no HUD layer, no submission; the frame is drawn exactly as without glhook (`NO_WORLD`).

### 8.3 Failure cases

| Event | Detected by | Client | Host | Status |
|---|---|---|---|---|
| Host process exits or crashes | client: the host's process handle is signalled, or the pipe breaks | stop submitting; pass-through; no GPU wait can be pending (SYNC-2); relaunch with backoff | — | `HOST_EXITED` |
| Host hangs (heartbeat stale with frames outstanding) | client | as above; `TerminateProcess` after one more `host_hang_ms`; relaunch with backoff | — | `HOST_HUNG` |
| The client never signals `fence_in = n` (game hang, lost context) | host: `in_wait_cap_ms` | — | slot ABANDONED, CPU-signal `fence_out = n`, `host_progress = n`; after 3 in a row stand down and NOTIFY | `GPU_TIMEOUT` |
| A host GPU job exceeds `gpu_wait_cap_ms` | host completion thread | pass-through on NOTIFY | stand down: answer further FRAMEs as ABANDONED (CPU-signalled) until the client re-enables NR with a new controls revision | `GPU_TIMEOUT` |
| Device removed (D3D12 `DEVICE_REMOVED`, Vulkan `VK_ERROR_DEVICE_LOST`) | host | DROP; one rebuild with a new host; then pass-through for the session | release fences (`UINT64_MAX`), exit | `DEVICE_LOST` |
| Import fails | client (BUILD_DONE) | the next handle type, then `T_CPU_COPY`, then pass-through | releases that generation | `IMPORT_FAILED` |
| Version, nonce, PID or LUID mismatch | either | pass-through for the session | refuse and exit | `VERSION_MISMATCH`, `SECURITY`, `ADAPTER_MISMATCH` |
| The game exits | host: client process handle | — | drain, release fences, exit; the job kills it anyway | — |

## 9. Resize, context change, device loss and generations

- **Generations.** Every BUILD carries `generation = previous + 1`; every FRAME and slot record carries
  it; the host rejects a FRAME of any other generation, and the client discards any slot whose generation
  is not current (the Feeder's runtime generation; `dlss5-neural-amd` confirms generation and frame id in
  every ack — `core/x86bridge/bridge_ipc.h` lines 21–27, 89).
- **Resize.** The client detects a new back-buffer size at `SwapBuffers` (the default framebuffer's
  dimensions); it stops submitting, sends DROP for the old generation, BUILD for the new one, shows
  pass-through until BUILD_DONE, and sets `SF_RESET` (`reset_reason` 4) on the new generation's first
  frame. A resize does not reset the frame-id sequence.
- **Context change.** When the game's window context changes (`wglMakeCurrent` with another context on
  the window DC, or the context is destroyed), the client forgets — does not delete — the old context's GL
  objects (HANDLE-2), keeps the handles (HANDLE-1), and runs DROP/BUILD on the new context, re-importing
  the fences there (`dlss5-neural-amd`: "everything is keyed on `wglGetCurrentContext()`"; the Feeder:
  "the GL context changed; rebuilding on the new one"). DS2's pbuffer contexts (HDR, cube captures) are
  not the window context and never trigger this.
- **Device loss on the host** — §8.3.
- **History resets** the client requests with `SF_RESET` and `reset_reason`: the first frame of a session
  or generation, a level load, a camera cut, frames without a world phase in between (a loading screen),
  a user request. The host also resets on a controls change (contract C2) and on any abandoned frame.

## 10. The CPU-copy transport

**When.** The client lacks `GL_EXT_memory_object_win32` or `GL_EXT_semaphore_win32`, cannot read the LUID,
or every GPU handle type failed to import. Intel's Windows driver is the expected case (§4.8). Before
falling back, a client on Intel SHOULD probe `WGL_NV_DX_interop2` (D3D11 shared textures with
lock/unlock — the Feeder's written "design B", `docs/PLAN-OPENGL.md` lines 351–364); whether Intel's driver
offers it for this use is unverified, and it would be a new handle type in a minor version.

**How.** The host creates one pagefile-backed section, duplicated into the client (`cpu_section` in
BUILD_ACK), holding per slot: colour (RGBA8), depth (R32F), motion flags and control mask (R8 each) on
the way in, and the output (RGBA8) on the way back; motion is **not** transferred — the host computes it
from depth and the matrices of the slot record (`MV_HOST`, §6.3), with the same formula as the client
(`Phase_D2_GLHook.md`), in the declared origin. `glReadPixels` returns rows bottom-up — the
`ORIGIN_BOTTOM_LEFT` that glhook declares anyway, so neither side reorders anything. The client reads
back with `glReadPixels` into pixel-pack buffers, fenced with
`glFenceSync`, maps them a frame later and copies into the section; the host uploads into its own
resources. The way back is the mirror image (`glTexSubImage2D` from a pixel-unpack buffer). Notification is
the same FRAME message and `ev_done`; the fences are not used. `K` = 2 and the views are mapped once.

**Cost (estimate, not a measurement).** 10 bytes per pixel go to the host and 4 come back: at 1920×1080
that is 20.7 MB down and 8.3 MB up per frame, about 2.4–4.8 ms of transfer at 6–12 GB/s, overlapped by
pipelining, plus about 58 MB of `memcpy` split between the two processes (a few milliseconds of CPU on each
side), and one more frame of latency. At 3440×1440 multiply by 2.4. The order of magnitude agrees with
`dlss5-neural-amd`'s classic-D3D9 route, where "each frame crosses system memory twice. That costs a few
milliseconds per frame regardless of the Scale" (its README). In a 32-bit client the mapped views take
about 58 MB of address space at 1080p with `K` = 2 (calculation) — a reason to prefer a Large Address
Aware EXE (D1.5).

## 11. Logging and diagnostics

### 11.1 Logs

Both sides log to `yae-nr\logs\` (`glhook.log`, `host.log`), truncated at each launch with the previous run
kept as `.1`. Required lines: the versions and build ids of both sides; the GL renderer, version and
extension probe; the LUID on both sides and whether they match; every resource with its format, flags and
size (host) and its import result (client); every state change with its status code; the first `N` frames
in detail (`log_frames`, default 3); a summary every 600 frames — client CPU ms per frame, frame interval,
share of frames with NR, pacing waits, misses; host GPU ms by stage, round trip, abandoned frames; every
failure with the exact API call, its error code and the stage (the Feeder's practice: one line names the
slot, the format and the GL error). An unhandled-exception filter on the client names the faulting module
and offset and then chains to the previous filter (`dlss5-neural-amd` found driver faults far from their
cause this way).

### 11.2 Status codes

| Code | Name | Code | Name |
|---:|---|---:|---|
| 0 | `OK` | 11 | `TOO_SLOW` |
| 1 | `STARTING` | 12 | `HOST_HUNG` |
| 2 | `VERSION_MISMATCH` | 13 | `HOST_EXITED` |
| 3 | `ADAPTER_MISMATCH` | 14 | `PROTOCOL_ERROR` |
| 4 | `INTEROP_MISSING` | 15 | `GENERATION_STALE` |
| 5 | `IMPORT_FAILED` | 16 | `DISABLED_BY_USER` |
| 6 | `ALLOC_FAILED` | 17 | `NO_WORLD` |
| 7 | `BACKEND_UNAVAILABLE` | 18 | `BARRIER` |
| 8 | `MODEL_MISSING` | 19 | `RESIZING` |
| 9 | `DEVICE_LOST` | 20 | `CONTEXT_CHANGED` |
| 10 | `GPU_TIMEOUT` | 21 | `SECURITY` |

### 11.3 Diagnostic modes

- `--transport-only` (host) / `FRAME_TRANSPORT_ONLY`: the host copies colour to output; nothing else runs.
  Every way the transport can be wrong is then visible on screen — an orange sky is the channel order,
  black is memory that never aliased (`dlss5-neural-amd`'s `Stage=2`). The orientation is checked on the
  host side: its debug view of the network input (`debug_view` 1) must show the picture upright after
  the runtime has applied the declared origin.
- **Split screen**: the host copies only the left half, so a split image proves the output reaches the
  screen (the Feeder's `mode=1`).
- **Frame tags**: the loopback host writes the frame id into an 8×8 block of the output; the client reads
  it back in its debug build and checks that every composited frame shows `n − 1` (pipelined) or `n`
  (same-frame).
- **Debug views** (`debug_view`, §6.1) on the host; motion, mask and HUD-layer views on the client.

## 12. Security notes

- The pipe is local (`PIPE_REJECT_REMOTE_CLIENTS`), single-instance (`FILE_FLAG_FIRST_PIPE_INSTANCE`), with
  a DACL for the current user; its name carries the client PID and a random nonce; the host accepts only
  the PID and nonce of its command line and checks `GetNamedPipeClientProcessId`.
- The control block and the CPU section are unnamed sections, shared only by handle duplication — nothing
  to squat in a global namespace.
- The client starts the host by full path and never through `PATH`; the host restricts its DLL search to
  its own folder and System32; the installer's manifest lets the client check the host's SHA-256 (D4).
- Handles are duplicated with the rights the peer needs, into the one peer process.
- Every field is validated: sizes, formats, enumerations, generations, monotonic frame ids and revisions;
  non-finite floats reject an update; a malformed message ends the session.
- No network, no listening socket. Models and NVIDIA files never cross the bridge (P4).

## 13. Conformance tests

Two tools of this repository implement the host side without `yae-neural` (D2.5): **`ynb-loopback-host64`**
(echo: copies colour to output with D3D12, optional split and frame tags) and the same binary with
**`--fault <spec>`** (fault injection). A small x86 harness, **`ynb-client-test`**, runs the client side
in a hidden GL window without the game. Tests run on every GPU vendor at hand; results go into the D2 and
D3 documents with the driver version.

| # | Test | Pass |
|---|---|---|
| CT-01 | Handshake: right pair; wrong major; wrong nonce; wrong PID; second client; LUID mismatch | the right pair connects; each wrong case is refused with its status and the client stays in pass-through |
| CT-02 | Import and round trip per handle type and per format of §4.3 | bytes identical both ways for every resource of every slot (the harness writes patterns, the host echoes and verifies) |
| CT-03 | Origin and channel order (`--transport-only`, a gradient with a "top of the screen" marker) | the composite equals the original frame, 0 differing pixels; the host's input view, oriented by the declared origin, shows the marker at the top; a deliberately wrong origin in the slot record shows it at the bottom |
| CT-04 | Loopback in the game, pass-through exactness | with the echo host, the composite of the captured colour and the HUD layer differs from the frame drawn without glhook in ≤ 0.1 % of pixels, by ≤ 1/255 (clamping in the HUD layer, D2.2), on 20 reference frames |
| CT-05 | Frame tags, pipelined and same-frame, 10 000 frames | every composited frame shows `n − 1` (pipelined) or `n` (same-frame) |
| CT-06 | Slot races: the host delays each frame by a random 0–30 ms | no tag mismatch, no torn output (a tag block shows one id), no SYNC-5/6 violation in the logs |
| CT-07 | Hang (`--fault hang-after=600`): the host stops signalling | the game never freezes: the longest frame ≤ `pace_budget_ms` + 1 frame; pass-through within `host_hang_ms`; the host is replaced; no driver reset |
| CT-08 | Crash (`--fault crash-after=600`) | pass-through within one frame; relaunch per backoff; no driver reset |
| CT-09 | Slow host (`--fault delay=50`) | `TOO_SLOW` within 1 s; at most one NR ↔ pass-through transition per second (no strobe) |
| CT-10 | Resize churn: a new size every 500 ms for 60 s | no crash; handle count grows by at most `6 × K + 2` per generation; no GL error |
| CT-11 | Context change mid-session (the harness swaps contexts) | rebuild on the new context; no deletion attempted outside the owning context |
| CT-12 | Device loss (`--fault device-lost`) | one rebuild, then pass-through for the session |
| CT-13 | CPU-copy transport against the GPU transport | identical bytes delivered; the host's `MV_HOST` motion within 1e-3 px of the client's |
| CT-14 | Malformed messages (fuzzed headers and bodies) | the session ends with `PROTOCOL_ERROR`; no crash on either side |
| CT-15 | Soak: 60 min in the game with the echo host | handle count and committed memory of both processes flat after the first generation |

## 14. Design sources

| Element | Taken from | Reference |
|---|---|---|
| The host creates the shared set for a GL client; GL imports | DLSS5-Feeder, protocol v2 for OpenGL | `src/feed_ipc.h` lines 3–20; `docs/PLAN-OPENGL.md` §5 (tag v1.18.0-beta.2, commit `3907e2b`, 2026-10-06) |
| Two shared fences, frame number as the value; pipelined and same-frame shapes | Feeder | `src/feed_ipc.h` lines 19–34 |
| Refusal of another version at the header | Feeder; `dlss5-neural-amd` | `src/feed_ipc.h` lines 66–67; `docs/x86bridge.md` line 72 |
| The client duplicates its own process handle into the host | Feeder, protocol v4 | `src/feed_ipc.h` lines 149–154 |
| Allocation size passed for the GL import; dedicated memory; `GL_LAYOUT_GENERAL_EXT` with `ALLOW_SIMULTANEOUS_ACCESS`; `glFlush` after a signal | Feeder | `src/feed_gl.h` lines 473–594; `host/dlss5-feed-host64.cpp` lines 2959–2999 |
| CPU-signal on failure, release of every wait on exit | Feeder | `host/dlss5-feed-host64.cpp` lines 3786, 3868–3878 |
| A bounded pipe backlog; a worker thread with bounded waits off the render thread | Feeder | `host/dlss5-feed-host64.cpp` lines 3140–3165; `src/dlss5-feed32.cpp` lines 955–1021 |
| State guard around blits (sRGB, scissor); context churn → rebuild | Feeder | `src/feed_gl.h` lines 631–665; `docs/PLAN-OPENGL.md` §2(e) |
| Packed, fixed-width wire structures with asserted sizes and offsets; no `HANDLE`/`size_t`/`bool` | `dlss5-neural-amd` protocol v6 (v0.7.10, commit `af465d3`, 2026-10-04) | `docs/x86bridge.md` lines 55–57; `core/x86bridge/bridge_ipc.h` lines 69–84 |
| LUID in hello and ack; generation and frame id confirmed | `dlss5-neural-amd` | `core/x86bridge/bridge_ipc.h` lines 19–27, 89 |
| Transfers bounded by a timeout or the peer's death; one conversation per pipe | `dlss5-neural-amd` | `core/x86bridge/bridge_io.h` lines 15–42, 45–53 |
| Stand-down reasons; the GPU wait capped below the IPC timeout; the stall watch | `dlss5-neural-amd` | `core/x86bridge/bridge_ipc.h` line 45; `docs/x86bridge.md` lines 74, 86 |
| Pipelined presentation by default (+16 % to +41 %) | `dlss5-neural-amd`; Feeder `async_home` | `docs/x86bridge.md` line 95 |
| Never close imported handles; dedicated memory; the OPAQUE trap; RGBA crossing; CPU confirmation before a queue wait; pacing instead of strobing; MSAA resolve | `dlss5-neural-amd` OpenGL route | `docs/opengl-route.md` lines 72–86, 155–210, 255–268 |
| Monotonic revisions for settings, clamping, no replay | `dlss5-neural-amd` | `docs/x86bridge.md` lines 53, 82 |

**Not taken.** The flips of `dlss5-neural-amd`'s OpenGL route (YNB declares the image origin instead —
the frame contract C2's origin field); the Feeder's per-frame CPU-free host loop that queues a GPU wait on `fence_in` without
confirmation (replaced by SYNC-3, because YNB's host waits on its own thread); its synthetic DLSS request
(YNB carries the frame to `yae-neural`, not to an NGX contract); `dlss5-neural-amd`'s per-frame
request/acknowledge round trip on the pipe (YNB answers through the control block, so the render thread
never reads the pipe).

## 15. Open questions

1. **Freeze point.** The program document freezes this draft at M0 and v1 at the start of D3; the
   coordinator's brief says "frozen at M0". This document follows the program document.
2. **AMD in a 32-bit process with `HT_D3D12_RESOURCE`.** Only `D3D11_IMAGE` is measured there. If D2.5
   shows the D3D12 type failing on AMD x86, `HT_D3D11_IMAGE` becomes AMD's default and the host allocates
   on a D3D11 device for that client.
3. **Intel.** Which of `GL_EXT_memory_object_win32`, `WGL_NV_DX_interop2` or neither the Windows driver
   offers decides between a GPU transport and §10; nobody has measured it.
4. **Address space.** Whether imported memory objects consume the 32-bit client's virtual address space is
   measured in D2.5; if they do, `K` = 2 becomes the default.
5. **Same-frame default for slow hosts.** Whether a host that cannot hide its work (`round_trip_ms` above a
   frame) should run same-frame at a reduced model scale, or pipelined with pass-through, is decided from
   D3's measurements, not here.
