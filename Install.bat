@echo off
setlocal
rem Vivaldi Workspace Tab Mover - thin launcher / lanciatore sottile.
rem All questions (folder path, language) are asked by Install-Mod.ps1 (bilingual).
rem Tutte le domande (percorso, lingua) le fa Install-Mod.ps1 (bilingue).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Mod.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" goto done
rem Error: the window stays open so you can read the message / Errore: la finestra resta aperta per leggere il messaggio.
pause
exit /b %RC%
:done
echo This window closes by itself in 6 seconds. / Questa finestra si chiude da sola tra 6 secondi.
ping -n 7 127.0.0.1 >nul
exit /b 0
