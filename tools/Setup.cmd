@echo off
rem One time: install Node.js if needed, then sign in to Cloudflare.
where node >nul 2>nul || (winget install --id OpenJS.NodeJS.LTS --exact & echo Node.js installed. Close this window and run Setup again. & pause & exit /b)
rem Sign in from a folder with no cloudflare.config.ts, which cf would otherwise try to load.
cd /d "%TEMP%"
call npx --yes cf@1.0.0-beta.27 auth login
pause
