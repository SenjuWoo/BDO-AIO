@echo off
title BDO Modding AIO - 2026
cd /d "%~dp0"
set "BDO_AIO_HOME=%~dp0"
start "" powershell.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -Command "try { & (Join-Path $env:BDO_AIO_HOME 'bdo_aio_gui.ps1') } catch { Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show($_.Exception.Message + [Environment]::NewLine + 'Use START-CLASSIC.bat for the classic console.', 'BDO-AIO startup error') }"
if errorlevel 1 (
  echo.
    echo The dashboard launcher could not open. Read the message above.
    echo You can still use START-CLASSIC.bat.
  pause
)
