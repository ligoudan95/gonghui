@echo off
REM ====================================================================
REM gonghui DEMO - programmer selfcheck (M0 batch 4)
REM Usage: run from repo root -> cmd /c DEMO\selfcheck.cmd
REM   1) resolve godot binary: %GODOT_BIN% -> where godot -> fail w/ guide
REM   2) run gdUnit4 full test suite (res://tests)
REM   3) run headless data validation -> reports/validation_report.txt
REM   4) summary + exit code (0 = all green)
REM ====================================================================
setlocal enabledelayedexpansion
chcp 65001 >nul
cd /d "%~dp0"

set "GODOT="
REM GODOT_BIN takes precedence, but only if the file really exists
REM (stale env var on this machine points to a removed 4.7.1 path)
if defined GODOT_BIN (
    if exist "%GODOT_BIN%" (
        set "GODOT=%GODOT_BIN%"
    ) else (
        echo [selfcheck] warning: GODOT_BIN points to a missing file, fall back to PATH lookup
    )
)
if not defined GODOT (
    for /f "delims=" %%i in ('where godot 2^>nul') do (
        set "GODOT=%%i"
        goto :godot_found
    )
)
if not defined GODOT goto :godot_missing
:godot_found
echo [selfcheck] godot binary: %GODOT%
echo.

REM ---- step 1: gdUnit4 full suite ----
set "TEST_LOG=%TEMP%\gonghui_selfcheck_tests.log"
REM C-9: gdUnit4 runner path is addon-version pinned - bump addon => re-verify this line
"%GODOT%" --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c > "%TEST_LOG%" 2>&1
set "TEST_RC=!errorlevel!"
echo [selfcheck] ---- gdUnit4 tests (exit %TEST_RC%) ----
findstr /C:"Overall Summary" /C:"Executed test cases" /C:"Exit code" "%TEST_LOG%"
echo.

REM ---- step 2: headless data validation ----
set "VAL_LOG=%TEMP%\gonghui_selfcheck_validation.log"
REM R4-07: remove stale report before run (user:// persists across runs)
if exist "%USER_REPORT%" del "%USER_REPORT%"
"%GODOT%" --headless -s res://tools/run_validation.gd > "%VAL_LOG%" 2>&1
set "VAL_RC=!errorlevel!"
echo [selfcheck] ---- data validation (exit %VAL_RC%) ----
REM S5-8: report path moved to user:// (= %APPDATA%\Godot\app_userdata\<project>)
REM C-9: project name "gonghui" mirrors project.godot application/config/name - rename project => sync next line
set "USER_REPORT=%APPDATA%\Godot\app_userdata\gonghui\reports\validation_report.txt"
if exist "%USER_REPORT%" (
    type "%USER_REPORT%"
) else (
    type "%VAL_LOG%"
)
echo.

REM ---- step 3: summary ----
REM note: no bare ")" inside if-blocks (closes the block early)
echo [selfcheck] ================= summary =================
if "%TEST_RC%"=="0" (
    echo [selfcheck] gdUnit4 tests      : PASS - exit 0
) else (
    echo [selfcheck] gdUnit4 tests      : FAIL - exit %TEST_RC%, see %TEST_LOG%
)
if "%VAL_RC%"=="0" (
    echo [selfcheck] data validation    : PASS - exit 0
) else (
    echo [selfcheck] data validation    : FAIL - exit %VAL_RC%, see %VAL_LOG%
)
if "%TEST_RC%"=="0" if "%VAL_RC%"=="0" (
    echo [selfcheck] ALL GREEN
    exit /b 0
)
echo [selfcheck] FAILURES PRESENT
exit /b 1

:godot_missing
echo [selfcheck] ERROR: godot binary not found.
echo [selfcheck] set either:
echo [selfcheck]   1) environment variable GODOT_BIN to full path of godot.exe
echo [selfcheck]   2) or add godot.exe directory to PATH
exit /b 2
