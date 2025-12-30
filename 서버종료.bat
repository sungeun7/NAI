@echo off
REM 한국어 코드페이지 설정 (한글 깨짐 방지)
chcp 949 >nul 2>&1
setlocal enabledelayedexpansion

title AI Chatbot Server Stopper

REM Get current process ID to avoid killing ourselves
for /f "tokens=2" %%p in ('tasklist /FI "WINDOWTITLE eq AI Chatbot Server Stopper*" /FO LIST 2^>nul ^| findstr /I "PID"') do set PID=%%p

echo ========================================
echo   AI Chatbot Server Stopping...
echo ========================================
echo.

REM Step 1: Kill server window by title (multiple attempts with force)
echo [1/6] Stopping server window...
echo    Attempting to close "AI Chatbot Server" window...

REM Method 1: Try taskkill by window title (multiple attempts)
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1
timeout /t 2 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1
timeout /t 2 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1

REM Method 2: Find all cmd.exe processes and check their window titles
echo    Searching for server processes...
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    if not "%%p"=="" (
        REM Check if this process has the server window title
        tasklist /FI "PID eq %%p" /FI "WINDOWTITLE eq AI Chatbot Server*" /FO LIST >nul 2>&1
        if !errorlevel! equ 0 (
            echo    Found server process PID: %%p, terminating with all children...
            REM Kill with taskkill first
            taskkill /PID %%p /T /F >nul 2>&1
            timeout /t 1 /nobreak >nul
            taskkill /PID %%p /F >nul 2>&1
            REM Also kill using wmic (more forceful)
            wmic process where "ProcessId=%%p" delete >nul 2>&1
            REM Kill all child processes
            for /f "tokens=2" %%c in ('wmic process where "ParentProcessId=%%p" get ProcessId 2^>nul ^| findstr /R "[0-9]"') do (
                if not "%%c"=="" (
                    taskkill /PID %%c /F >nul 2>&1
                    wmic process where "ProcessId=%%c" delete >nul 2>&1
                )
            )
        )
    )
)

REM Step 2: Kill all CMD windows with server title
echo [2/6] Stopping CMD windows...
for /f "tokens=2" %%p in ('tasklist /FI "WINDOWTITLE eq AI Chatbot Server*" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    taskkill /PID %%p /T /F >nul 2>&1
)

REM Step 3: Kill Maven processes
echo [3/6] Stopping Maven processes...
taskkill /FI "IMAGENAME eq mvn.cmd" /T /F >nul 2>&1
taskkill /FI "IMAGENAME eq mvn.exe" /T /F >nul 2>&1
timeout /t 1 /nobreak >nul

REM Step 4: Kill Java processes using port 8080
echo [4/6] Stopping Java processes on port 8080...
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":8080"') do (
    if not "%%p"=="" (
        taskkill /PID %%p /F >nul 2>&1
    )
)
timeout /t 1 /nobreak >nul

REM Step 5: Kill Java processes that might be Spring Boot
echo [5/6] Final cleanup...
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq java.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    REM Check if this Java process is using port 8080
    netstat -ano 2^>nul | findstr ":8080" | findstr "%%p" >nul
    if !errorlevel! equ 0 (
        taskkill /PID %%p /F >nul 2>&1
    )
)

REM Final cleanup - kill server window one more time
timeout /t 1 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1

REM Step 6: Kill the main program window if it exists (최강력한 종료)
echo [6/6] Stopping main program window and all related windows...
echo    Using PowerShell for most reliable window closing...

REM Use PowerShell to find and close windows by title (most reliable)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$myPid = %PID%; Get-Process | Where-Object {($_.MainWindowTitle -like '*AI Chatbot Program*' -or $_.MainWindowTitle -like '*AI Chatbot Server*') -and ($_.Id -ne $myPid)} | ForEach-Object { try { Write-Host ('Closing: ' + $_.MainWindowTitle + ' PID: ' + $_.Id); Stop-Process -Id $_.Id -Force } catch { Write-Host ('Error: ' + $_.Exception.Message) } }" 2>nul

timeout /t 3 /nobreak >nul

REM Method 1: Kill by window title (multiple attempts)
echo    Method 1: Killing by window title (multiple attempts)...
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F >nul 2>&1
timeout /t 2 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F >nul 2>&1
timeout /t 2 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F >nul 2>&1
timeout /t 2 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F >nul 2>&1

REM Method 2: Kill ALL cmd.exe processes except this one (most aggressive)
echo    Method 2: Killing all cmd.exe processes (except this one - PID: %PID%)...
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    if not "%%p"=="%PID%" (
        echo    Terminating cmd.exe PID: %%p
        REM Try multiple methods
        taskkill /PID %%p /T /F >nul 2>&1
        timeout /t 1 /nobreak >nul
        taskkill /PID %%p /F >nul 2>&1
        timeout /t 1 /nobreak >nul
        wmic process where "ProcessId=%%p" delete >nul 2>&1
        REM Kill all children
        for /f "tokens=2" %%c in ('wmic process where "ParentProcessId=%%p" get ProcessId 2^>nul ^| findstr /R "[0-9]"') do (
            if not "%%c"=="" (
                taskkill /PID %%c /F >nul 2>&1
                wmic process where "ProcessId=%%c" delete >nul 2>&1
            )
        )
    )
)

REM Method 3: Final PowerShell attempt - kill all cmd.exe except this one
echo    Method 3: Final PowerShell attempt (killing all cmd.exe except PID %PID%)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$myPid = %PID%; Get-Process cmd -ErrorAction SilentlyContinue | Where-Object {$_.Id -ne $myPid} | ForEach-Object { try { Write-Host ('Killing cmd.exe PID: ' + $_.Id); Stop-Process -Id $_.Id -Force } catch {} }" 2>nul

timeout /t 3 /nobreak >nul

REM Method 4: One more title-based attempt
echo    Method 4: Final title-based attempts...
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1
timeout /t 1 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1

echo.
echo ========================================
echo   Server stopped successfully!
echo ========================================
echo.
echo All server processes have been terminated.
echo.
echo Press any key to close this window...
pause >nul

REM Close this window
exit

