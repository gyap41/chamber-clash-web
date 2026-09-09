@echo off
cd /d C:\GameCreate\chamber-clash
set LOGFILE=C:\GameCreate\chamber-clash\.local\logs\claude-run-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%.log
set LOGFILE=%LOGFILE: =0%
if not exist C:\GameCreate\chamber-clash\.local\logs mkdir C:\GameCreate\chamber-clash\.local\logs
echo ==== git status ==== > "%LOGFILE%"
git status >> "%LOGFILE%" 2>&1
echo. >> "%LOGFILE%"
echo ==== git log -1 ==== >> "%LOGFILE%"
git log -1 >> "%LOGFILE%" 2>&1
echo. >> "%LOGFILE%"
echo ==== git diff --stat ==== >> "%LOGFILE%"
git diff --stat >> "%LOGFILE%" 2>&1
echo. >> "%LOGFILE%"
echo ==== run_tests.ps1 ==== >> "%LOGFILE%"
powershell -ExecutionPolicy Bypass -File "C:\GameCreate\chamber-clash\run_tests.ps1" >> "%LOGFILE%" 2>&1
echo. >> "%LOGFILE%"
echo ==== DONE, log written to %LOGFILE% ==== >> "%LOGFILE%"
notepad "%LOGFILE%"
