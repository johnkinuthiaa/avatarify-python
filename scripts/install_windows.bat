@echo off
setlocal

cd /d "%~dp0\.."

REM Check prerequisites
call conda --version >nul 2>&1 && ( echo conda found ) || ( echo conda not found. Please refer to the README and install Miniconda. && exit /B 1)
REM call git --version >nul 2>&1 && ( echo git found ) || ( echo git not found. Please refer to the README and install Git. && exit /B 1)

call scripts/settings_windows.bat

set ENV_EXISTS=0
set RECREATE_ENV=0
call conda env list | findstr /R /C:"^%CONDA_ENV_NAME% " >nul && set ENV_EXISTS=1
for /f "delims=" %%i in ('conda info --base') do set "CONDA_BASE=%%i"
if "%ENV_EXISTS%"=="1" (
  call "%CONDA_BASE%\condabin\conda.bat" activate %CONDA_ENV_NAME% || set RECREATE_ENV=1
  if "%RECREATE_ENV%"=="0" (
    for /f "delims=" %%v in ('python -c "import sys; print(str(sys.version_info[0]) + \".\" + str(sys.version_info[1]))"') do set "PYVER=%%v"
    if not "%PYVER%"=="3.7" set RECREATE_ENV=1
  )
)

if "%ENV_EXISTS%"=="0" set RECREATE_ENV=1

if "%RECREATE_ENV%"=="1" (
  echo Recreating clean conda env %CONDA_ENV_NAME%...
  call conda remove -y -n %CONDA_ENV_NAME% --all >nul 2>&1
  call conda create -y -n %CONDA_ENV_NAME% python=3.7 || exit /B 1
)

call "%CONDA_BASE%\condabin\conda.bat" activate %CONDA_ENV_NAME% || exit /B 1

call conda install -y --force-reinstall numpy==1.19.0 scikit-image python-blosc==1.7.0 -c conda-forge || exit /B 1
call conda install -y --force-reinstall pytorch==1.7.1 torchvision==0.8.2 cudatoolkit=11.0 -c pytorch || exit /B 1
call conda install -y --force-reinstall vs2015_runtime || exit /B 1
call conda install -y -c anaconda git || exit /B 1
call python -m pip install --upgrade pip setuptools wheel || exit /B 1

REM ###FOMM###
call rmdir fomm /s /q
call git clone https://github.com/alievk/first-order-model.git fomm || exit /B 1

call python -m pip install --upgrade --force-reinstall --no-cache-dir -r requirements_windows.txt || exit /B 1

REM Pip may pull a different torch build via transitive deps; force canonical pair back.
call conda install -y --force-reinstall pytorch==1.7.1 torchvision==0.8.2 cudatoolkit=11.0 -c pytorch >nul 2>&1

call python -c "import torch" >nul 2>&1
if errorlevel 1 (
  echo GPU-enabled PyTorch failed to load. Switching to CPU-only PyTorch...
  call conda remove -y pytorch torchvision cudatoolkit cpuonly >nul 2>&1
  call conda install -y pytorch==1.7.1 torchvision==0.8.2 cpuonly -c pytorch || exit /B 1
)
