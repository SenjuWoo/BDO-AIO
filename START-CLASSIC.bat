@echo off
title BDO Modding AIO - Classic console
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bdo_aio.ps1"
if errorlevel 1 pause
