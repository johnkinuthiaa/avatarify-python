@echo off
setlocal

cd /d "%~dp0\.."

REM Check prerequisites
call conda --version >nul 2>&1 && ( echo conda found ) || ( echo conda not found. Please refer to the README and install Miniconda. && exit /B 1)
REM call git --version >nul 2>&1 && ( echo git found ) || ( echo git not found. Please refer to the README and install Git. && exit /B 1)

call scripts/settings_windows.bat

set ENV_EXISTS=0
call conda env list | findstr /R /C:"^%CONDA_ENV_NAME% " >nul && set ENV_EXISTS=1
if "%ENV_EXISTS%"=="0" (
  call conda create -y -n %CONDA_ENV_NAME% python=3.7 || exit /B 1
) else (
  echo Conda env %CONDA_ENV_NAME% already exists. Reusing it.
)
for /f "delims=" %%i in ('conda info --base') do set "CONDA_BASE=%%i"
call "%CONDA_BASE%\condabin\conda.bat" activate %CONDA_ENV_NAME% || exit /B 1

call conda install -y numpy==1.19.0 scikit-image python-blosc==1.7.0 -c conda-forge
call conda install -y pytorch==1.7.1 torchvision cudatoolkit=11.0 -c pytorch
call conda install -y vs2015_runtime
call conda install -y -c anaconda git
call python -m pip install --upgrade pip setuptools wheel

REM ###FOMM###
call rmdir fomm /s /q
call git clone https://github.com/alievk/first-order-model.git fomm

call pip install -r requirements_windows.txt || exit /B 1

call python -c "import torch" >nul 2>&1
if errorlevel 1 (
  echo GPU-enabled PyTorch failed to load. Installing CPU-only PyTorch for compatibility...
  call conda install -y pytorch==1.7.1 torchvision cpuonly -c pytorch || exit /B 1
)
