@echo off
setlocal

echo ============================================================
echo   Installer Mod "Sposta nel Workspace" - Vivaldi
echo ============================================================
echo.
set /p VROOT="Percorso cartella Application di Vivaldi (es. H:\Vivaldi Standalone\Application): "

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Mod.ps1" -VivaldiAppRoot "%VROOT%"

echo.
pause
