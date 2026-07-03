@echo off
setlocal

cd /d "%~dp0"

call scripts/settings_windows.bat

set CONFIG=fomm/config/vox-adv-256.yaml
set KMP_DUPLICATE_LIB_OK=TRUE
set OPENCV_VIDEOIO_PRIORITY_MSMF=0

for /f "delims=" %%i in ('conda info --base') do set "CONDA_BASE=%%i"
call "%CONDA_BASE%\condabin\conda.bat" activate %CONDA_ENV_NAME%

REM Set PYTHONPATH early so all python checks below use the correct env modules
set PYTHONPATH=%CD%;%CD%\fomm

if not exist "fomm\config\vox-adv-256.yaml" (
  echo Missing fomm submodule. Run scripts\install_windows.bat first.
  exit /B 1
)

python -c "import cv2, yaml, zmq, msgpack_numpy, face_alignment, requests" >nul 2>&1
if errorlevel 1 (
  echo Installing missing Python packages for Windows...
  call python -m pip install --upgrade --force-reinstall --no-cache-dir -r requirements_windows.txt || exit /B 1
)

python -c "import torch, torchvision, sys; sys.exit(0 if torch.__version__.startswith('1.7.1') and torchvision.__version__.startswith('0.8.2') else 1)" >nul 2>&1
if errorlevel 1 (
  echo Repairing Torch/Torchvision versions...
  call conda remove -y pytorch torchvision cudatoolkit cpuonly >nul 2>&1
  call conda install -y pytorch==1.7.1 torchvision==0.8.2 cudatoolkit=11.0 -c pytorch >nul 2>&1
)

python -c "import torch" >nul 2>&1
if errorlevel 1 (
  echo PyTorch GPU build failed to load. Switching to CPU-only PyTorch...
  call conda remove -y pytorch torchvision cudatoolkit cpuonly >nul 2>&1
  call conda install -y pytorch==1.7.1 torchvision==0.8.2 cpuonly -c pytorch || exit /B 1
)

REM Pre-launch: clear any corrupted face_alignment model cache so the app
REM auto-recovers instead of crashing with a zip-archive error.
python -c ^
  "import torch, pathlib;" ^
  "d = pathlib.Path(torch.hub.get_dir()) / 'checkpoints';" ^
  "[f.unlink() for f in (d.iterdir() if d.exists() else []) if f.is_file() and any(m in f.name.lower() for m in ('fan','face-alignment','face_alignment','depth')) and f.stat().st_size < 1024 * 1024]" ^
  >nul 2>&1

REM Ensure log directory exists (Tee/Logger open files in var\log on startup)
if not exist "var\log" mkdir "var\log"

call python afy/cam_fomm.py --config %CONFIG% --relative --adapt_scale --no-pad --checkpoint vox-adv-cpk.pth.tar %*
