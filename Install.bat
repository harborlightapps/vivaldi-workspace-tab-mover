@echo off
setlocal
rem Vivaldi Workspace Tab Mover - thin launcher / lanciatore sottile.
rem All questions (folder path, language) are asked by Install-Mod.ps1 (bilingual).
rem Tutte le domande (percorso, lingua) le fa Install-Mod.ps1 (bilingue).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Mod.ps1"
echo.
pause