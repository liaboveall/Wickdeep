@echo off
rem Run the game with the local Godot 4.7.2 editor binary.
set "GODOT=%USERPROFILE%\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.7.2 not found at %GODOT%
  echo Download it from https://godotengine.org and update this file.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
