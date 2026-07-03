@echo off
setlocal

cd /d "%~dp0"

call scripts/settings_windows.bat

set CONFIG=fomm/config/vox-adv-256.yaml

for /f "delims=" %%i in ('conda info --base') do set "CONDA_BASE=%%i"
call "%CONDA_BASE%\condabin\conda.bat" activate %CONDA_ENV_NAME%

if not exist "fomm\config\vox-adv-256.yaml" (
  echo Missing fomm submodule. Run scripts\install_windows.bat first.
  exit /B 1
)

python -c "import cv2, yaml, zmq, msgpack_numpy, face_alignment" >nul 2>&1
if errorlevel 1 (
  echo Installing missing Python packages for Windows...
  call pip install -r requirements_windows.txt || exit /B 1
)

set PYTHONPATH=%PYTHONPATH%;%CD%;%CD%\fomm
call python afy/cam_fomm.py --config %CONFIG% --relative --adapt_scale --no-pad --checkpoint vox-adv-cpk.pth.tar %*
