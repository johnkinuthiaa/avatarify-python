# Copilot instructions for `avatarify-python`

## Build, test, and lint commands

Use the existing platform scripts; they encode required env setup, dependencies, and runtime flags.

| Purpose | Command |
| --- | --- |
| Install (Linux, local GPU mode) | `bash scripts/install.sh` |
| Install (macOS client/remote mode) | `bash scripts/install_mac.sh` |
| Install (Windows) | `scripts\install_windows.bat` |
| Download model weights (`vox-adv-cpk.pth.tar`) | `bash scripts/download_data.sh` |
| Run (Linux) | `bash run.sh` |
| Run (Linux, CPU/no CUDA) | `bash run.sh --no-gpus` |
| Run (Linux, Docker) | `bash run.sh --docker` |
| Run (macOS helper script) | `bash run_mac.sh --is-client --in-addr <host:5557> --out-addr <host:5558>` |
| Run (Windows) | `run_windows.bat` |
| Build Docker image | `docker build -t avatarify .` |

There is no repository test suite or lint configuration checked in (no `pytest`/`unittest` tests, and no configured lint runner like `ruff`, `flake8`, or `pylint`), so there is no full-suite or single-test command to run in this repo as-is.

## High-level architecture

- **Entry points are shell/batch scripts**: `run.sh`, `run_mac.sh`, and `run_windows.bat` activate Conda env `avatarify`, set `PYTHONPATH` to include repo root + `fomm`, then start `afy/cam_fomm.py`.
- **Main application loop**: `afy/cam_fomm.py` handles camera capture, avatar loading/switching, UI/keyboard controls, calibration flow, and optional virtual camera streaming.
- **Prediction backends (3 modes) selected by CLI flags**:
  - **Local mode** (default): `cam_fomm.py` uses `afy/predictor_local.py` for in-process FOMM inference.
  - **Client mode** (`--is-client`): `cam_fomm.py` uses `afy/predictor_remote.py`, which sends requests over ZeroMQ and receives predictions asynchronously.
  - **Worker mode** (`--is-worker`): `cam_fomm.py` starts `afy/predictor_worker.py`, which hosts `PredictorLocal` behind ZeroMQ and multiprocessing queues.
- **Networking protocol**: `afy/networking.py` defines custom `SerializingSocket` helpers for metadata + binary payload transfer (`msgpack` for metadata/method args, JPEG buffers for frames).
- **Camera and frame utilities**: `afy/camera_selector.py` probes/selects camera and persists choice in `cam.yaml`; `afy/videocaptureasync.py` provides threaded capture; `afy/utils.py` centralizes logging/timing/crop/pad/resize helpers.
- **External model code**: `fomm/` (first-order-model) is cloned by install scripts and required at runtime via `PYTHONPATH`.

## Key codebase conventions

- **Global CLI options are parsed at import time** in `afy/arguments.py` (`opt = parser.parse_args()`), and many modules import/use `opt` directly. Keep new CLI flags centralized there and avoid alternate parsers.
- **Runtime behavior is script-driven**: update `run*.{sh,bat}` and `scripts/settings*.{sh,bat}` when changing startup defaults (e.g., env name, virtual cam id, worker/client defaults).
- **Logging convention**: long-running processes log to `var/log/*.log` via `Tee`/`Logger`; follow that pattern for new background/process components.
- **Remote inference convention**: treat non-`predict` calls as **critical** RPCs; `predict` is intentionally lossy/non-blocking under queue pressure to keep real-time throughput.
- **Image path and color handling**:
  - Avatar assets are expected in `./avatars` by default (`--avatars` can override).
  - OpenCV reads/writes BGR, while most processing in `cam_fomm.py` uses RGB conversions (`[..., ::-1]`); preserve these conversions when editing frame logic.
- **Platform assumptions**:
  - Linux virtual camera defaults to `/dev/video9` (`scripts/settings.sh`).
  - macOS is expected to run in remote/client mode.
  - Windows flow is tied to Conda + batch scripts.
