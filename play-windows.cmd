@echo off
setlocal
set "CITY_ENGINE=godot"
if defined CITY_GODOT_EXE set "CITY_ENGINE=%CITY_GODOT_EXE%"
"%CITY_ENGINE%" --version >nul 2>&1
if errorlevel 1 (
  echo Install Godot 4.7.1, then add it to PATH or set CITY_GODOT_EXE.
  pause
  exit /b 1
)
if not exist "%~dp0player-data" mkdir "%~dp0player-data"
if not exist "%~dp0.godot\global_script_class_cache.cfg" (
  "%CITY_ENGINE%" --headless --path "%~dp0." --import --log-file "%~dp0player-data\import.log"
  if errorlevel 1 exit /b 1
)
start "" "%CITY_ENGINE%" --path "%~dp0." --log-file "%~dp0player-data\city.log" -- --save-dir="%~dp0player-data"
