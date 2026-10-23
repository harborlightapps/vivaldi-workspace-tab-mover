@echo off
setlocal
rem Vivaldi Workspace Tab Mover - thin launcher / lanciatore sottile.
rem All questions (folder path, confirmation) are asked by Uninstall-Mod.ps1 (bilingual).
rem Tutte le domande (percorso, conferma) le fa Uninstall-Mod.ps1 (bilingue).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Mod.ps1"
echo.
pause