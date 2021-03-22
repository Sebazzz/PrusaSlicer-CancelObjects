@echo off
pushd %~dp0
where /q pwsh
IF ERRORLEVEL 1 (
    pwsh -NoProfile -NonInteractive -File Add-CancelObjects.ps1 %*
) else (
    powershell.exe -NoProfile -NonInteractive -File Add-CancelObjects.ps1 %*
)
SET SCRIPTERROR=%ERRORLEVEL%
popd
EXIT /B %SCRIPTERROR%