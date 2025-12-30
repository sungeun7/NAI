@echo off
REM 한국어 코드페이지 설정 (한글 깨짐 방지)
chcp 949 >nul 2>&1
setlocal enabledelayedexpansion

title AI Chatbot Program

REM Cleanup function 정의
goto :main

:cleanup
REM This function can be called with 'call' or 'goto'
if "%1"=="return" goto :eof

echo.
echo ========================================
echo   Stopping server...
echo ========================================
echo.

REM Load server PID from file if not already set
if not defined SERVER_PID (
    if exist server_pid.txt (
        set /p SERVER_PID=<server_pid.txt 2>nul
    )
)

REM If we have server PID, use it first (most reliable)
if defined SERVER_PID (
    echo [0/7] Closing server window using saved PID: %SERVER_PID%...
    REM Kill all child processes first (recursively)
    :kill_children
    for /f "tokens=2" %%c in ('wmic process where "ParentProcessId=%SERVER_PID%" get ProcessId 2^>nul ^| findstr /R "[0-9]"') do (
        if not "%%c"=="" (
            echo      Closing child process PID: %%c
            taskkill /PID %%c /F >nul 2>&1
            wmic process where "ProcessId=%%c" delete >nul 2>&1
            powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%c -Force } catch {}" >nul 2>&1
            REM Recursively kill grandchildren
            set CHILD_PID=%%c
            for /f "tokens=2" %%g in ('wmic process where "ParentProcessId=%%c" get ProcessId 2^>nul ^| findstr /R "[0-9]"') do (
                if not "%%g"=="" (
                    taskkill /PID %%g /F >nul 2>&1
                    wmic process where "ProcessId=%%g" delete >nul 2>&1
                )
            )
        )
    )
    REM Then kill the parent process
    taskkill /PID %SERVER_PID% /T /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    taskkill /PID %SERVER_PID% /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    wmic process where "ProcessId=%SERVER_PID%" delete >nul 2>&1
    timeout /t 1 /nobreak >nul
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %SERVER_PID% -Force } catch {}" >nul 2>&1
    REM Clean up PID file
    del server_pid.txt >nul 2>&1
)

REM Step 1: Kill server window by title (multiple methods)
echo [1/7] Stopping server window...
REM Method 1: PowerShell - Close window by title (most reliable)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$title = '*AI Chatbot Server*'; Get-Process | Where-Object {$_.MainWindowTitle -like $title} | ForEach-Object { try { Write-Host ('Closing server window PID: ' + $_.Id); Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch { Write-Host ('Error: ' + $_.Exception.Message) } }" 2>nul
timeout /t 2 /nobreak >nul

REM Method 2: PowerShell - Find and kill all cmd.exe processes running Maven
echo    Finding cmd.exe processes running Maven...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process cmd -ErrorAction SilentlyContinue | ForEach-Object { $proc = $_; try { $cmdLine = (Get-CimInstance Win32_Process -Filter \"ProcessId = $($proc.Id)\").CommandLine; if ($cmdLine -like '*spring-boot:run*' -or $cmdLine -like '*mvn*spring-boot*') { Write-Host ('Found Maven process PID: ' + $proc.Id); Stop-Process -Id $proc.Id -Force -ErrorAction Stop } } catch {} }" 2>nul
timeout /t 2 /nobreak >nul

REM Method 3: Find cmd.exe processes by command line
echo    Finding cmd.exe processes by command line...
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
        echo %%c | findstr /I "spring-boot:run" >nul
        if !errorlevel! equ 0 (
            echo    Found Maven server process PID: %%p
            taskkill /PID %%p /T /F >nul 2>&1
            timeout /t 1 /nobreak >nul
            taskkill /PID %%p /F >nul 2>&1
            timeout /t 1 /nobreak >nul
            wmic process where "ProcessId=%%p" delete >nul 2>&1
            powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%p -Force } catch {}" >nul 2>&1
        )
    )
)

REM Method 4: taskkill by window title (multiple attempts)
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1
timeout /t 1 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1
timeout /t 1 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1
timeout /t 1 /nobreak >nul

REM Step 2: Kill all CMD windows with server title
echo [2/7] Stopping CMD windows with server title...
for /f "tokens=2" %%p in ('tasklist /FI "WINDOWTITLE eq AI Chatbot Server*" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    echo    Closing server window PID: %%p
    REM Kill all child processes first
    for /f "tokens=2" %%c in ('wmic process where "ParentProcessId=%%p" get ProcessId 2^>nul ^| findstr /R "[0-9]"') do (
        if not "%%c"=="" (
            echo      Closing child process PID: %%c
            taskkill /PID %%c /F >nul 2>&1
            wmic process where "ProcessId=%%c" delete >nul 2>&1
            powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%c -Force } catch {}" >nul 2>&1
        )
    )
    REM Then kill the parent process
    taskkill /PID %%p /T /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    taskkill /PID %%p /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    REM Use wmic for more forceful termination
    wmic process where "ProcessId=%%p" delete >nul 2>&1
    REM Final attempt with PowerShell
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%p -Force } catch {}" >nul 2>&1
)

REM Step 3: Kill Java processes FIRST (Maven's child processes)
echo [3/7] Stopping Java processes (Maven's child processes)...
REM First, kill all Java processes that might be Spring Boot
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq java.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    REM Check if this Java process is using port 8080
    netstat -ano 2^>nul | findstr ":8080" | findstr "%%p" >nul
    if !errorlevel! equ 0 (
        echo    Closing Spring Boot Java process PID: %%p
        taskkill /PID %%p /F >nul 2>&1
        timeout /t 1 /nobreak >nul
        wmic process where "ProcessId=%%p" delete >nul 2>&1
    )
)
REM Kill Java processes using port 8080
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":8080"') do (
    if not "%%p"=="" (
        echo    Closing Java process on port 8080 PID: %%p
        taskkill /PID %%p /F >nul 2>&1
        timeout /t 1 /nobreak >nul
        wmic process where "ProcessId=%%p" delete >nul 2>&1
    )
)
timeout /t 2 /nobreak >nul

REM Step 4: Kill Maven processes (after Java is killed)
echo [4/7] Stopping Maven processes...
REM Get all Maven PIDs and kill them with their children
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq mvn.cmd" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    echo    Closing Maven process PID: %%p (with children)...
    REM Kill all child processes first
    for /f "tokens=2" %%c in ('wmic process where "ParentProcessId=%%p" get ProcessId 2^>nul ^| findstr /R "[0-9]"') do (
        if not "%%c"=="" (
            echo      Closing child process PID: %%c
            taskkill /PID %%c /F >nul 2>&1
            wmic process where "ProcessId=%%c" delete >nul 2>&1
        )
    )
    REM Then kill Maven process itself
    taskkill /PID %%p /T /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    taskkill /PID %%p /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    wmic process where "ProcessId=%%p" delete >nul 2>&1
)
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq mvn.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    echo    Closing Maven process PID: %%p (with children)...
    REM Kill all child processes first
    for /f "tokens=2" %%c in ('wmic process where "ParentProcessId=%%p" get ProcessId 2^>nul ^| findstr /R "[0-9]"') do (
        if not "%%c"=="" (
            echo      Closing child process PID: %%c
            taskkill /PID %%c /F >nul 2>&1
            wmic process where "ProcessId=%%c" delete >nul 2>&1
        )
    )
    REM Then kill Maven process itself
    taskkill /PID %%p /T /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    taskkill /PID %%p /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    wmic process where "ProcessId=%%p" delete >nul 2>&1
)
REM Final attempt with taskkill
taskkill /FI "IMAGENAME eq mvn.cmd" /T /F >nul 2>&1
taskkill /FI "IMAGENAME eq mvn.exe" /T /F >nul 2>&1
timeout /t 2 /nobreak >nul

REM Step 5: Kill any remaining cmd.exe processes with server title
echo [5/7] Stopping remaining CMD processes...
for /f "tokens=2" %%p in ('tasklist /FI "WINDOWTITLE eq AI Chatbot Server*" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    echo    Closing remaining server window PID: %%p
    REM Kill all child processes
    for /f "tokens=2" %%c in ('wmic process where "ParentProcessId=%%p" get ProcessId 2^>nul ^| findstr /R "[0-9]"') do (
        if not "%%c"=="" (
            taskkill /PID %%c /F >nul 2>&1
            wmic process where "ProcessId=%%c" delete >nul 2>&1
        )
    )
    taskkill /PID %%p /T /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    taskkill /PID %%p /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    wmic process where "ProcessId=%%p" delete >nul 2>&1
    REM Use PowerShell for final attempt
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%p -Force } catch {}" >nul 2>&1
)

REM Step 6: Final cleanup - kill any remaining Java processes
echo [6/7] Final cleanup - any remaining Java processes...
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq java.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    REM Check command line for Spring Boot
    for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
        echo %%c | findstr /I "spring-boot" >nul
        if !errorlevel! equ 0 (
            echo    Closing remaining Spring Boot Java process PID: %%p
            taskkill /PID %%p /F >nul 2>&1
            wmic process where "ProcessId=%%p" delete >nul 2>&1
        )
    )
)

REM Step 7: Close this program window (AI Chatbot Program)
echo [7/7] Closing program window...
echo.
echo ========================================
echo   All processes stopped successfully!
echo ========================================
echo.

REM Close this window using multiple methods
echo Closing this window...

REM Method 1: PowerShell (most reliable)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$title = '*AI Chatbot Program*'; Get-Process | Where-Object {$_.MainWindowTitle -like $title} | ForEach-Object { try { Stop-Process -Id $_.Id -Force } catch {} }" 2>nul
timeout /t 1 /nobreak >nul

REM Method 2: Close by window title
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /F >nul 2>&1
timeout /t 1 /nobreak >nul

REM Method 3: Find and use current window PID
for /f "tokens=2" %%p in ('tasklist /FI "WINDOWTITLE eq AI Chatbot Program*" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    taskkill /PID %%p /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    wmic process where "ProcessId=%%p" delete >nul 2>&1
    timeout /t 1 /nobreak >nul
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%p -Force } catch {}" >nul 2>&1
)

REM Method 4: Find and close by command line
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
        echo %%c | findstr /I "실행.bat" >nul
        if !errorlevel! equ 0 (
            taskkill /PID %%p /F >nul 2>&1
            timeout /t 1 /nobreak >nul
        )
    )
)

REM Final exit - force close this window using multiple methods
timeout /t 1 /nobreak >nul

REM Get current cmd.exe process PID that's running this script
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
        echo %%c | findstr /I "실행.bat" >nul
        if !errorlevel! equ 0 (
            REM Close this specific process
            taskkill /PID %%p /F >nul 2>&1
            timeout /t 1 /nobreak >nul
            wmic process where "ProcessId=%%p" delete >nul 2>&1
            timeout /t 1 /nobreak >nul
            powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%p -Force } catch {}" >nul 2>&1
        )
    )
)

REM Close this window - find and close current cmd.exe process running this script
echo Closing this window...
set WINDOW_CLOSED=0

REM Method 1: Find by command line (most reliable)
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
        echo %%c | findstr /I "실행.bat" >nul
        if !errorlevel! equ 0 (
            echo Closing window (PID: %%p)...
            REM Try multiple methods to close
            taskkill /PID %%p /F >nul 2>&1
            timeout /t 1 /nobreak >nul
            wmic process where "ProcessId=%%p" delete >nul 2>&1
            timeout /t 1 /nobreak >nul
            powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%p -Force } catch {}" >nul 2>&1
            timeout /t 1 /nobreak >nul
            set WINDOW_CLOSED=1
            goto :window_closed
        )
    )
)
:window_closed

REM Method 2: Close by window title
if !WINDOW_CLOSED! equ 0 (
    echo Closing window by title...
    taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$title = '*AI Chatbot Program*'; Get-Process | Where-Object {$_.MainWindowTitle -like $title} | ForEach-Object { try { Stop-Process -Id $_.Id -Force } catch {} }" >nul 2>&1
    timeout /t 1 /nobreak >nul
)

REM Method 3: Final attempt - close all cmd.exe windows with this title
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /F >nul 2>&1
timeout /t 1 /nobreak >nul

REM Final exit - force close
exit

:main

echo ========================================
echo   AI Chatbot Program Starting...
echo ========================================
echo.

REM Check Java - Try multiple methods
set JAVA_FOUND=0
set JAVA_CMD=

REM Method 1: Check if java is in PATH
where java >nul 2>&1
if %errorlevel% equ 0 (
    set "JAVA_CMD=java"
    set JAVA_FOUND=1
    goto :java_found
)

REM Method 2: Check JAVA_HOME environment variable
if defined JAVA_HOME (
    if exist "%JAVA_HOME%\bin\java.exe" (
        set "JAVA_CMD=%JAVA_HOME%\bin\java.exe"
        set JAVA_FOUND=1
        goto :java_found
    )
)

REM Method 3: Search in Program Files\Java
if exist "C:\Program Files\Java" (
    for /d %%j in ("C:\Program Files\Java\jdk*") do (
        if exist "%%j\bin\java.exe" (
            set "JAVA_CMD=%%j\bin\java.exe"
            set JAVA_FOUND=1
            goto :java_found
        )
    )
    for /d %%j in ("C:\Program Files\Java\jre*") do (
        if exist "%%j\bin\java.exe" (
            set "JAVA_CMD=%%j\bin\java.exe"
            set JAVA_FOUND=1
            goto :java_found
        )
    )
)

REM Method 4: Search in Program Files (x86)\Java
if exist "C:\Program Files (x86)\Java" (
    for /d %%j in ("C:\Program Files (x86)\Java\jdk*") do (
        if exist "%%j\bin\java.exe" (
            set "JAVA_CMD=%%j\bin\java.exe"
            set JAVA_FOUND=1
            goto :java_found
        )
    )
    for /d %%j in ("C:\Program Files (x86)\Java\jre*") do (
        if exist "%%j\bin\java.exe" (
            set "JAVA_CMD=%%j\bin\java.exe"
            set JAVA_FOUND=1
            goto :java_found
        )
    )
)

REM Method 5: Search using ProgramFiles variable
if defined ProgramFiles (
    if exist "%ProgramFiles%\Java" (
        for /d %%j in ("%ProgramFiles%\Java\jdk*") do (
            if exist "%%j\bin\java.exe" (
                set "JAVA_CMD=%%j\bin\java.exe"
                set JAVA_FOUND=1
                goto :java_found
            )
        )
        for /d %%j in ("%ProgramFiles%\Java\jre*") do (
            if exist "%%j\bin\java.exe" (
                set "JAVA_CMD=%%j\bin\java.exe"
                set JAVA_FOUND=1
                goto :java_found
            )
        )
    )
)

:java_found
if %JAVA_FOUND% equ 0 (
    echo [ERROR] Java not found.
    echo.
    echo Please install Java 17 or higher from:
    echo https://www.oracle.com/java/technologies/downloads/
    echo.
    echo Or download OpenJDK from:
    echo https://adoptium.net/
    echo.
    echo After installation, make sure to:
    echo 1. Set JAVA_HOME environment variable
    echo 2. Add Java bin directory to PATH
    echo 3. Restart your computer
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

REM Check Java version
echo Checking Java version...
"%JAVA_CMD%" -version 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Could not verify Java version
)
echo.

REM Set JAVA_HOME if not set and we found Java
if not defined JAVA_HOME (
    if not "%JAVA_CMD%"=="java" (
        REM Extract JAVA_HOME from Java path
        for %%i in ("%JAVA_CMD%") do (
            set "JAVA_DIR=%%~dpi"
        )
        for %%i in ("%JAVA_DIR%..") do (
            set "JAVA_HOME=%%~fi"
        )
        REM Remove trailing backslash
        if "%JAVA_HOME:~-1%"=="\" set "JAVA_HOME=%JAVA_HOME:~0,-1%"
        echo Setting JAVA_HOME to: %JAVA_HOME%
        set "JAVA_HOME=%JAVA_HOME%"
    )
)

REM Check Maven (local Maven first, then system Maven)
set MAVEN_CMD=
if exist "apache-maven-3.9.12\bin\mvn.cmd" (
    set "MAVEN_CMD=apache-maven-3.9.12\bin\mvn.cmd"
    echo Using local Maven
) else (
    where mvn >nul 2>&1
    if %errorlevel% equ 0 (
        set "MAVEN_CMD=mvn"
        echo Using system Maven
    ) else (
        echo [ERROR] Maven not found.
        echo Please use the included Maven or install Maven on your system.
        echo.
        echo Press any key to exit...
        pause >nul
        exit /b 1
    )
)
echo.

REM Build and run
echo Building project...
call "%MAVEN_CMD%" clean package -DskipTests
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)
echo.

echo ========================================
echo   Starting server...
echo   Browser will open automatically
echo   Press Ctrl+C to stop server
echo ========================================
echo.

REM Start server in separate window and capture its PID
echo Starting server in separate window...
start "AI Chatbot Server" cmd /k "%MAVEN_CMD% spring-boot:run"

REM Wait for server window to start
echo Waiting 3 seconds for server window to start...
timeout /t 3 /nobreak >nul

REM Get the server window process ID for monitoring (multiple attempts)
set SERVER_PID=
for /f "tokens=2" %%p in ('tasklist /FI "WINDOWTITLE eq AI Chatbot Server*" /FO LIST 2^>nul ^| findstr /I "PID"') do set SERVER_PID=%%p
if not defined SERVER_PID (
    timeout /t 2 /nobreak >nul
    for /f "tokens=2" %%p in ('tasklist /FI "WINDOWTITLE eq AI Chatbot Server*" /FO LIST 2^>nul ^| findstr /I "PID"') do set SERVER_PID=%%p
)
if not defined SERVER_PID (
    timeout /t 2 /nobreak >nul
    for /f "tokens=2" %%p in ('tasklist /FI "WINDOWTITLE eq AI Chatbot Server*" /FO LIST 2^>nul ^| findstr /I "PID"') do set SERVER_PID=%%p
)
if defined SERVER_PID (
    echo Server window started with PID: %SERVER_PID%
    REM Save PID to file for cleanup
    echo %SERVER_PID% > server_pid.txt 2>nul
) else (
    REM Try to find by command line
    timeout /t 2 /nobreak >nul
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
        for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
            echo %%c | findstr /I "spring-boot:run" >nul
            if !errorlevel! equ 0 (
                set SERVER_PID=%%p
                echo %SERVER_PID% > server_pid.txt 2>nul
                echo Server process found by command line, PID: %SERVER_PID%
                goto :pid_found
            )
        )
    )
    :pid_found
)

REM Also get Maven and Java PIDs for later cleanup
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq mvn.cmd" /FO LIST 2^>nul ^| findstr /I "PID"') do set MAVEN_PID=%%p
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq java.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do set JAVA_PID=%%p

REM Wait for server to start and open browser
echo.
echo ========================================
echo   Waiting for server to start...
echo ========================================
echo Server is starting... Please wait...
echo (This may take a few seconds...)
echo.

REM Wait for server to be ready (check port 8080) - faster and more reliable
set SERVER_READY=0
set WAIT_COUNT=0

REM Give server a moment to start
echo Waiting for server to start...
timeout /t 3 /nobreak >nul

:wait_for_server
timeout /t 1 /nobreak >nul
set /a WAIT_COUNT+=1
echo Checking server... (Attempt !WAIT_COUNT!/8)

REM Check if port is listening - if yes, open browser immediately
netstat -ano 2>nul | findstr ":8080" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo [SUCCESS] Port 8080 is listening!
    echo [INFO] Opening browser now...
    set SERVER_READY=1
    goto :server_ready
) else (
    if !WAIT_COUNT! leq 3 (
        echo [INFO] Port 8080 not listening yet, waiting...
    )
)

REM If we've waited long enough, try opening browser anyway
if !WAIT_COUNT! geq 8 (
    echo.
    echo [INFO] Opening browser (server should be ready)
    echo.
    set SERVER_READY=1
    goto :server_ready
)
goto :wait_for_server

:server_ready
echo.
echo ========================================
echo   OPENING BROWSER NOW!
echo ========================================
echo.

REM Open browser - Try multiple browsers
echo.
echo [INFO] Attempting to open browser at http://localhost:8080
echo.
set BROWSER_OPENED=0

REM Method 1: Windows default browser (most reliable - try multiple times)
echo [METHOD 1] Opening Windows default browser...
start http://localhost:8080
timeout /t 1 /nobreak >nul
start http://localhost:8080
timeout /t 1 /nobreak >nul
cmd /c start http://localhost:8080
set BROWSER_OPENED=1
timeout /t 2 /nobreak >nul

REM Method 2: PowerShell (as backup)
echo [METHOD 2] Trying PowerShell method...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process 'http://localhost:8080'" 2>&1
timeout /t 1 /nobreak >nul

REM Method 3: Edge (as backup)
if exist "C:\Program Files\Microsoft\Edge\Application\msedge.exe" (
    echo [METHOD 3] Trying Edge...
    start "" "C:\Program Files\Microsoft\Edge\Application\msedge.exe" "http://localhost:8080"
    timeout /t 1 /nobreak >nul
)
if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
    start "" "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" "http://localhost:8080"
    timeout /t 1 /nobreak >nul
)

REM Method 4: Chrome (as backup)
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    echo [METHOD 4] Trying Chrome...
    start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" "http://localhost:8080"
    timeout /t 1 /nobreak >nul
)
if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
    start "" "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" "http://localhost:8080"
    timeout /t 1 /nobreak >nul
)

REM Method 5: Firefox (as backup)
if exist "C:\Program Files\Mozilla Firefox\firefox.exe" (
    echo [METHOD 5] Trying Firefox...
    start "" "C:\Program Files\Mozilla Firefox\firefox.exe" "http://localhost:8080"
    timeout /t 1 /nobreak >nul
)
if exist "C:\Program Files (x86)\Mozilla Firefox\firefox.exe" (
    start "" "C:\Program Files (x86)\Mozilla Firefox\firefox.exe" "http://localhost:8080"
    timeout /t 1 /nobreak >nul
)

REM Method 6: Additional methods as final backup
echo [METHOD 6] Trying additional methods...
rundll32 url.dll,FileProtocolHandler http://localhost:8080
timeout /t 1 /nobreak >nul

:browser_opened

echo.
echo ========================================
echo   Browser opening commands executed!
echo ========================================
echo.

REM Verify browser was opened by checking for browser processes
timeout /t 3 /nobreak >nul
set BROWSER_FOUND=0
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq msedge.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do set BROWSER_FOUND=1
if !BROWSER_FOUND! equ 0 (
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq chrome.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do set BROWSER_FOUND=1
)
if !BROWSER_FOUND! equ 0 (
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq firefox.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do set BROWSER_FOUND=1
)

if !BROWSER_FOUND! equ 1 (
    echo [SUCCESS] Browser opened successfully!
    echo.
) else (
    echo [WARNING] Browser may not have opened automatically.
    echo.
    echo Trying to open browser again with different methods...
    timeout /t 1 /nobreak >nul
    start http://localhost:8080
    timeout /t 1 /nobreak >nul
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process 'http://localhost:8080'"
    timeout /t 1 /nobreak >nul
    cmd /c start http://localhost:8080
    timeout /t 2 /nobreak >nul
    echo.
    echo If browser still did not open, please manually go to:
    echo   http://localhost:8080
    echo.
)
echo.

REM Wait a moment for browser to start and connect
timeout /t 5 /nobreak >nul

REM Get browser process ID - try multiple methods (wait longer for browser to connect)
set BROWSER_PID=
echo [INFO] 브라우저 PID 찾는 중...

REM Method 1: Check which process is using port 8080 (most reliable)
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":8080" ^| findstr "ESTABLISHED"') do (
    if not "%%p"=="" (
        REM Check if this PID is a browser process
        tasklist /FI "PID eq %%p" 2^>nul | findstr /I "chrome.exe msedge.exe firefox.exe iexplore.exe" >nul
        if !errorlevel! equ 0 (
            set BROWSER_PID=%%p
            echo [SUCCESS] 브라우저 PID 찾음: %BROWSER_PID%
            goto :browser_pid_saved
        )
    )
)
:browser_pid_saved

REM Method 2: Find browser processes with localhost:8080 in command line (if Method 1 failed)
if not defined BROWSER_PID (
    REM Try to find browser process that has localhost:8080 in command line
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq msedge.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
        for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
            echo %%c | findstr /I "localhost:8080" >nul
            if !errorlevel! equ 0 (
                set BROWSER_PID=%%p
                goto :browser_pid_found
            )
        )
    )
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq chrome.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
        for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
            echo %%c | findstr /I "localhost:8080" >nul
            if !errorlevel! equ 0 (
                set BROWSER_PID=%%p
                goto :browser_pid_found
            )
        )
    )
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq firefox.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
        for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
            echo %%c | findstr /I "localhost:8080" >nul
            if !errorlevel! equ 0 (
                set BROWSER_PID=%%p
                goto :browser_pid_found
            )
        )
    )
    :browser_pid_found
)

REM Show message
echo.
echo ========================================
echo   Server is running in separate window!
echo   Browser should be open at http://localhost:8080
echo ========================================
echo.
echo Server window: "AI Chatbot Server"
if defined BROWSER_PID (
    echo Browser PID: %BROWSER_PID% (모니터링 중...)
    echo 브라우저를 닫으면 자동으로 종료됩니다.
) else (
    echo Browser PID: 찾을 수 없음 (자동 감지 모드)
    echo 브라우저를 닫으면 자동으로 종료됩니다.
)
echo.
echo ========================================
echo   자동 종료 모드 활성화
echo ========================================
echo   브라우저를 닫으면 서버와 실행창이 자동으로 종료됩니다.
echo   이 창에서 Ctrl+C를 누르면 즉시 종료할 수 있습니다.
echo ========================================
echo.
echo 모니터링 중... (1초마다 브라우저 상태 확인)
echo.

REM Monitor loop - check browser and server every 1 second (automatic mode)
:monitor_loop
timeout /t 1 /nobreak >nul

REM Check if browser process still exists - prioritize saved PID
set BROWSER_EXISTS=0

REM Method 1: Check specific browser PID if we found one earlier (MOST RELIABLE)
if defined BROWSER_PID (
    REM Check if browser PID still exists
    tasklist /FI "PID eq %BROWSER_PID%" 2^>nul | findstr /I "%BROWSER_PID%" >nul
    if !errorlevel! equ 0 (
        REM Browser PID still exists - browser is open
        set BROWSER_EXISTS=1
        goto :browser_check_done
    ) else (
        REM Browser PID no longer exists - browser was closed (MOST RELIABLE INDICATOR)
        set BROWSER_EXISTS=0
        echo [INFO] 브라우저 PID %BROWSER_PID%가 더 이상 존재하지 않습니다. 브라우저가 닫혔습니다.
        goto :browser_check_done
    )
)

REM Method 2: Check if any browser is connected to port 8080 (fallback if no PID saved)
if !BROWSER_EXISTS! equ 0 (
    for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":8080" ^| findstr "ESTABLISHED"') do (
        if not "%%p"=="" (
            REM Check if this PID is a browser process
            tasklist /FI "PID eq %%p" 2^>nul | findstr /I "chrome.exe msedge.exe firefox.exe iexplore.exe" >nul
            if !errorlevel! equ 0 (
                set BROWSER_EXISTS=1
                goto :browser_check_done
            )
        )
    )
)

REM Method 3: Check for any browser process with localhost:8080 in command line (final fallback)
if !BROWSER_EXISTS! equ 0 (
    REM Check Edge (most common)
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq msedge.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
        for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
            echo %%c | findstr /I "localhost:8080" >nul
            if !errorlevel! equ 0 (
                set BROWSER_EXISTS=1
                goto :browser_check_done
            )
        )
    )
    REM Check Chrome
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq chrome.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
        for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
            echo %%c | findstr /I "localhost:8080" >nul
            if !errorlevel! equ 0 (
                set BROWSER_EXISTS=1
                goto :browser_check_done
            )
        )
    )
    REM Check Firefox
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq firefox.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
        for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
            echo %%c | findstr /I "localhost:8080" >nul
            if !errorlevel! equ 0 (
                set BROWSER_EXISTS=1
                goto :browser_check_done
            )
        )
    )
)

:browser_check_done

REM If browser doesn't exist, close everything
if !BROWSER_EXISTS! equ 0 (
    echo.
    echo ========================================
    echo   브라우저가 닫혔습니다!
    echo   서버와 실행창을 종료합니다...
    echo ========================================
    echo.
    timeout /t 1 /nobreak >nul
    
    REM Run cleanup to stop server and close window
    goto :cleanup
)

REM Check if server window still exists
tasklist /FI "WINDOWTITLE eq AI Chatbot Server*" /FO LIST 2^>nul | findstr /I "PID" >nul
if !errorlevel! neq 0 (
    echo.
    echo 서버 창이 닫혔습니다. 실행창을 종료합니다...
    timeout /t 1 /nobreak >nul
    goto :cleanup
)

REM Check if Java process on port 8080 still exists (server is running)
set SERVER_RUNNING=0
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":8080"') do (
    if not "%%p"=="" (
        set SERVER_RUNNING=1
        goto :server_check_done
    )
)
:server_check_done
if !SERVER_RUNNING! equ 0 (
    echo.
    echo 서버가 종료되었습니다. 실행창을 종료합니다...
    timeout /t 1 /nobreak >nul
    goto :cleanup
)

goto :monitor_loop


