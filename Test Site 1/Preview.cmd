@echo off
rem Preview this site at http://localhost:8787. Close the window to stop.
cd /d "%~dp0"
if not exist node_modules call npm ci --no-audit --no-fund
call npx cf dev
pause
