@echo off
REM Copies the Tallymark folder into the game's AddOns folder.
REM Change ADDONS_DIR if your game is installed somewhere else.
set "ADDONS_DIR=C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"

setlocal
set "SRC=%~dp0..\Tallymark"
set "PAUSE_AT_END=1"
if /i "%~1"=="--no-pause" set "PAUSE_AT_END=0"

REM Note: no echo of paths inside ( ) blocks. The ")" in "(x86)" would break them.
if not exist "%ADDONS_DIR%" goto :notfound

robocopy "%SRC%" "%ADDONS_DIR%\Tallymark" /MIR /NJH /NJS /NFL /NDL /NP >nul
if %ERRORLEVEL% GEQ 8 goto :copyfailed

echo Tallymark installed to:
echo   %ADDONS_DIR%\Tallymark
echo New or renamed files: restart the game. Lua changes only: /reload
set "RESULT=0"
goto :end

:notfound
echo AddOns folder not found:
echo   %ADDONS_DIR%
echo Edit ADDONS_DIR at the top of this script.
set "RESULT=1"
goto :end

:copyfailed
echo Copy failed. The folder may be read-only or need admin rights.
set "RESULT=1"
goto :end

:end
if "%PAUSE_AT_END%"=="1" pause
exit /b %RESULT%
