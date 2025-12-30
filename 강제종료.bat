@echo off
REM 관리자 권한 확인 및 요청
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ========================================
    echo   관리자 권한이 필요합니다!
    echo ========================================
    echo.
    echo 이 스크립트를 관리자 권한으로 실행합니다...
    echo.
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit
)

REM 한국어 코드페이지 설정 (한글 깨짐 방지)
chcp 949 >nul 2>&1
setlocal enabledelayedexpansion

title AI Chatbot 강제 종료

echo ========================================
echo   AI Chatbot 강제 종료 (관리자 권한)
echo ========================================
echo.
echo 경고: 이 스크립트는 모든 AI Chatbot 관련 창을 강제로 종료합니다.
echo.
pause

REM Get current process ID - multiple methods
set MY_PID=
for /f "tokens=2" %%p in ('tasklist /FI "WINDOWTITLE eq AI Chatbot 강제 종료*" /FO LIST 2^>nul ^| findstr /I "PID"') do set MY_PID=%%p
if not defined MY_PID (
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
        wmic process where "ProcessId=%%p" get CommandLine 2^>nul | findstr /I "강제종료.bat" >nul
        if !errorlevel! equ 0 set MY_PID=%%p
    )
)
if not defined MY_PID set MY_PID=0

echo.
echo [1/5] PowerShell로 모든 AI Chatbot 창 종료...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$myPid = %MY_PID%; Get-Process | Where-Object {($_.MainWindowTitle -like '*AI Chatbot*') -and ($_.Id -ne $myPid)} | ForEach-Object { try { Write-Host ('강제 종료: ' + $_.MainWindowTitle + ' (PID: ' + $_.Id + ')'); Stop-Process -Id $_.Id -Force } catch { Write-Host ('오류: ' + $_.Exception.Message) } }"

timeout /t 3 /nobreak >nul

echo.
echo [2/5] taskkill로 창 제목으로 종료...
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1
timeout /t 2 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1
timeout /t 2 /nobreak >nul
taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F >nul 2>&1

echo.
echo [3/5] 모든 cmd.exe 프로세스 확인 및 종료 (현재 프로세스 제외 - PID: %MY_PID%)...
echo    실행 중인 모든 cmd.exe 프로세스:
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO LIST 2^>nul ^| findstr /I "PID"') do (
    if not "%%p"=="" (
        echo.
        echo    ========================================
        echo    PID: %%p 확인 중...
        REM Get window title for this process
        for /f "tokens=*" %%t in ('tasklist /FI "PID eq %%p" /FO LIST 2^>nul ^| findstr /I "Window"') do (
            echo    창 제목: %%t
        )
        REM Get command line
        for /f "tokens=*" %%c in ('wmic process where "ProcessId=%%p" get CommandLine 2^>nul') do (
            echo    명령줄: %%c
        )
        
        if not "%%p"=="%MY_PID%" (
            echo    >>> 이 프로세스를 종료합니다...
            REM Try multiple methods with more force
            taskkill /PID %%p /T /F >nul 2>&1
            timeout /t 2 /nobreak >nul
            taskkill /PID %%p /F >nul 2>&1
            timeout /t 1 /nobreak >nul
            wmic process where "ProcessId=%%p" delete >nul 2>&1
            timeout /t 1 /nobreak >nul
            REM Try PowerShell
            powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%p -Force -ErrorAction Stop; Write-Host 'PowerShell로 종료 성공' } catch { Write-Host 'PowerShell 종료 실패' }" 2>nul
            REM Kill children recursively
            for /f "tokens=2" %%c in ('wmic process where "ParentProcessId=%%p" get ProcessId 2^>nul ^| findstr /R "[0-9]"') do (
                if not "%%c"=="" (
                    echo      자식 프로세스 종료: PID %%c
                    taskkill /PID %%c /F >nul 2>&1
                    wmic process where "ProcessId=%%c" delete >nul 2>&1
                    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Stop-Process -Id %%c -Force } catch {}" 2>nul
                )
            )
        ) else (
            echo    >>> 현재 프로세스이므로 건너뜁니다.
        )
    )
)

timeout /t 3 /nobreak >nul

echo.
echo [4/5] PowerShell로 최종 정리...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$myPid = %MY_PID%; Get-Process cmd -ErrorAction SilentlyContinue | Where-Object {$_.Id -ne $myPid} | ForEach-Object { try { Write-Host ('최종 종료: PID ' + $_.Id); Stop-Process -Id $_.Id -Force } catch {} }"

timeout /t 2 /nobreak >nul

echo.
echo [5/5] Maven 및 Java 프로세스 종료...

taskkill /FI "IMAGENAME eq mvn.cmd" /T /F >nul 2>&1
taskkill /FI "IMAGENAME eq mvn.exe" /T /F >nul 2>&1
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":8080"') do (
    if not "%%p"=="" (
        echo    포트 8080 사용 프로세스 종료: PID %%p
        taskkill /PID %%p /F >nul 2>&1
    )
)

echo.
echo ========================================
echo   강제 종료 완료!
echo ========================================
echo.
echo 모든 AI Chatbot 관련 프로세스 종료를 시도했습니다.
echo.
echo 만약 여전히 창이 남아있다면:
echo 1. 작업 관리자(Ctrl+Shift+Esc)를 열고
echo 2. "프로세스" 탭에서 "cmd.exe"를 찾아
echo 3. "AI Chatbot" 관련 프로세스를 수동으로 종료하세요.
echo.
echo 또는 다음 명령을 관리자 권한 명령 프롬프트에서 실행하세요:
echo   taskkill /FI "WINDOWTITLE eq AI Chatbot Program*" /T /F
echo   taskkill /FI "WINDOWTITLE eq AI Chatbot Server*" /T /F
echo.
echo 이 창을 닫으려면 아무 키나 누르세요...
pause >nul
exit

