@echo off
rem Runs the shared Preview tool on the website in this folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\Preview.ps1" -SiteFolder "%~dp0."
