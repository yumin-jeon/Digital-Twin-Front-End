@echo off
chcp 65001 > nul
setlocal EnableExtensions

REM ========= Repo root (this .bat file folder) =========
set "PROJECT_DIR=%~dp0"
pushd "%PROJECT_DIR%"

REM ========= CONFIG =========
set "HTTP_PORT=8000"

REM Cesium HTML (space -> %%20 for URL)
set "CESIUM_HTML_FILE=main\html_original\cesium_improved-code73_baseline_Jeju_F4.html"
set "CESIUM_URL=main/html_original/cesium_improved-code73_baseline_Jeju_F4.html"

set "MATLAB_SCRIPT=main\main_InteractiveSatControlvJeju.m"
set "PYTHON_RELAY=main\websocket_relay_Jeju.py"
set "PYTHON_EXE=python"
REM ==========================

echo ============================================================
echo    Satellite Control Simulation Launcher
echo ============================================================
echo.
echo Repo root: %PROJECT_DIR%
echo.

REM ========= sanity check =========
call :checkfile "setup_path.m"
call :checkfile "%MATLAB_SCRIPT%"
call :checkfile "%PYTHON_RELAY%"
call :checkfile "%CESIUM_HTML_FILE%"
echo.

REM ========= 1) WebSocket Relay =========
echo [1/4] Starting WebSocket Relay...
start "WebSocket_Relay" cmd /k ""%PYTHON_EXE%" "%PYTHON_RELAY%""
timeout /t 2 /nobreak > nul

REM ========= 2) HTTP Server =========
echo [2/4] Starting HTTP Server (port %HTTP_PORT%)...
start "HTTP_Server" cmd /k ""%PYTHON_EXE%" -m http.server %HTTP_PORT%""
timeout /t 2 /nobreak > nul

REM ========= 3) Open Browser =========
echo [3/4] Opening Cesium in Browser...
start "" "http://localhost:%HTTP_PORT%/%CESIUM_URL%"

REM ========= 4) MATLAB (setup_path -> main) =========
echo [4/4] Starting MATLAB (setup_path -> main script)...
start "MATLAB" matlab -nosplash -r "try; cd('%PROJECT_DIR%'); setup_path; run('%PROJECT_DIR%%MATLAB_SCRIPT%'); catch ME; disp(getReport(ME,'extended')); end"

echo.
echo ============================================================
echo  All services started!
echo    - WebSocket: ws://localhost:8765
echo    - HTTP: http://localhost:%HTTP_PORT%
echo    - MATLAB: %MATLAB_SCRIPT%
echo ============================================================
echo.
pause
popd
exit /b 0

:checkfile
if exist "%~1" (
  echo [OK] %~1
  exit /b 0
) else (
  echo [ERROR] Missing file: %~1
  echo        Current folder: %CD%
  pause
  exit /b 1
)

