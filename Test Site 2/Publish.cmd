@echo off
rem Publish the public folder of this site to Cloudflare.
cd /d "%~dp0"
choice /m "Publish this site now"
if errorlevel 2 exit /b
if not exist node_modules call npm ci --no-audit --no-fund
call npx cf deploy
pause
