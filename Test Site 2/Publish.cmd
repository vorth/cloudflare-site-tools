@echo off
rem Runs the shared Publish tool on the website in this folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\Publish.ps1" -SiteFolder "%~dp0."
