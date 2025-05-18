@echo off

set VERSION=2.5

rem printing greetings

echo mpoolpro mining setup script v%VERSION%.
echo ^(please report issues to support@mpoolpro.pro email^)
echo.

net session >nul 2>&1
if %errorLevel% == 0 (set ADMIN=1) else (set ADMIN=0)

rem command line arguments
set WALLET=%1
rem this one is optional
set EMAIL=%2

rem checking prerequisites

if [%WALLET%] == [] (
  echo Script usage:
  echo ^> setup_mpool.pro_miner.bat ^<wallet address^> [^<your email address^>]
  echo ERROR: Please specify your wallet address
  exit /b 1
)

for /f "delims=." %%a in ("%WALLET%") do set WALLET_BASE=%%a
call :strlen "%WALLET_BASE%", WALLET_BASE_LEN
if %WALLET_BASE_LEN% == 106 goto WALLET_LEN_OK
if %WALLET_BASE_LEN% ==  95 goto WALLET_LEN_OK
echo ERROR: Wrong wallet address length (should be 106 or 95): %WALLET_BASE_LEN%
exit /b 1

:WALLET_LEN_OK

if ["%USERPROFILE%"] == [""] (
  echo ERROR: Please define USERPROFILE environment variable to your user directory
  exit /b 1
)

if not exist "%USERPROFILE%" (
  echo ERROR: Please make sure user directory %USERPROFILE% exists
  exit /b 1
)

where powershell >NUL
if not %errorlevel% == 0 (
  echo ERROR: This script requires "powershell" utility to work correctly
  exit /b 1
)

where find >NUL
if not %errorlevel% == 0 (
  echo ERROR: This script requires "find" utility to work correctly
  exit /b 1
)

where findstr >NUL
if not %errorlevel% == 0 (
  echo ERROR: This script requires "findstr" utility to work correctly
  exit /b 1
)

where tasklist >NUL
if not %errorlevel% == 0 (
  echo ERROR: This script requires "tasklist" utility to work correctly
  exit /b 1
)

if %ADMIN% == 1 (
  where sc >NUL
  if not %errorlevel% == 0 (
    echo ERROR: This script requires "sc" utility to work correctly
    exit /b 1
  )
)

rem calculating port

set /a "EXP_MONERO_HASHRATE = %NUMBER_OF_PROCESSORS% * 700 / 1000"

if [%EXP_MONERO_HASHRATE%] == [] ( 
  echo ERROR: Can't compute projected Monero hashrate
  exit 
)

if %EXP_MONERO_HASHRATE% gtr 8192 ( set PORT=18192 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 4096 ( set PORT=14096 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 2048 ( set PORT=12048 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 1024 ( set PORT=11024 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  512 ( set PORT=10512 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  256 ( set PORT=10256 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  128 ( set PORT=10128 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr   64 ( set PORT=10064 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr   32 ( set PORT=10032 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr   16 ( set PORT=10016 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr    8 ( set PORT=10008 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr    4 ( set PORT=10004 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr    2 ( set PORT=10002 & goto PORT_OK )
set PORT=10001

:PORT_OK

rem printing intentions

set "LOGFILE=%USERPROFILE%\mpoolpro\xmrig.log"

echo I will download, setup and run in background Monero CPU miner with logs in %LOGFILE% file.
echo If needed, miner in foreground can be started by %USERPROFILE%\mpoolpro\miner.bat script.
echo Mining will happen to %WALLET% wallet.

if not [%EMAIL%] == [] (
  echo ^(and %EMAIL% email as password to modify wallet options later at https://mpoolpro.pro site^)
)

echo.

if %ADMIN% == 0 (
  echo Since I do not have admin access, mining in background will be started using your startup directory script and only work when your are logged in this host.
) else (
  echo Mining in background will be performed using mpool_miner service.
)

echo.
echo JFYI: This host has %NUMBER_OF_PROCESSORS% CPU threads, so projected Monero hashrate is around %EXP_MONERO_HASHRATE% KH/s.
echo.

pause

rem start doing stuff: preparing miner

echo [*] Removing previous mpoolpro miner (if any)
sc stop mpool_miner
sc delete mpool_miner
taskkill /f /t /im xmrig.exe

:REMOVE_DIR0
echo [*] Removing "%USERPROFILE%\mpoolpro" directory
timeout 5
rmdir /q /s "%USERPROFILE%\mpoolpro" >NUL 2>NUL
IF EXIST "%USERPROFILE%\mpoolpro" GOTO REMOVE_DIR0

echo [*] Downloading mpoolpro advanced version of xmrig to "%USERPROFILE%\xmrig.zip"
powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/mpoolpro/xmrig_setup/master/xmrig.zip', '%USERPROFILE%\xmrig.zip')"
if errorlevel 1 (
  echo ERROR: Can't download mpoolpro advanced version of xmrig
  goto MINER_BAD
)

echo [*] Unpacking "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\mpoolpro"
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\xmrig.zip', '%USERPROFILE%\mpoolpro')"
if errorlevel 1 (
  echo [*] Downloading 7za.exe to "%USERPROFILE%\7za.exe"
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/mpoolpro/xmrig_setup/master/7za.exe', '%USERPROFILE%\7za.exe')"
  if errorlevel 1 (
    echo ERROR: Can't download 7za.exe to "%USERPROFILE%\7za.exe"
    exit /b 1
  )
  echo [*] Unpacking stock "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\mpoolpro"
  "%USERPROFILE%\7za.exe" x -y -o"%USERPROFILE%\mpoolpro" "%USERPROFILE%\xmrig.zip" >NUL
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\xmrig.zip"

echo [*] Checking if advanced version of "%USERPROFILE%\mpoolpro\xmrig.exe" works fine ^(and not removed by antivirus software^)
powershell -Command "$out = cat '%USERPROFILE%\mpoolpro\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 1,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\mpoolpro\config.json'" 
"%USERPROFILE%\mpoolpro\xmrig.exe" --help >NUL
if %ERRORLEVEL% equ 0 goto MINER_OK
:MINER_BAD

if exist "%USERPROFILE%\mpoolpro\xmrig.exe" (
  echo WARNING: Advanced version of "%USERPROFILE%\mpoolpro\xmrig.exe" is not functional
) else (
  echo WARNING: Advanced version of "%USERPROFILE%\mpoolpro\xmrig.exe" was removed by antivirus
)

echo [*] Looking for the latest version of Monero miner
for /f tokens^=2^ delims^=^" %%a IN ('powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $str = $wc.DownloadString('https://github.com/xmrig/xmrig/releases/latest'); $str | findstr msvc-win64.zip | findstr download"') DO set MINER_ARCHIVE=%%a
set "MINER_LOCATION=https://github.com%MINER_ARCHIVE%"

echo [*] Downloading "%MINER_LOCATION%" to "%USERPROFILE%\xmrig.zip"
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%MINER_LOCATION%', '%USERPROFILE%\xmrig.zip')"
if errorlevel 1 (
  echo ERROR: Can't download "%MINER_LOCATION%" to "%USERPROFILE%\xmrig.zip"
  exit /b 1
)

:REMOVE_DIR1
echo [*] Removing "%USERPROFILE%\mpoolpro" directory
timeout 5
rmdir /q /s "%USERPROFILE%\mpoolpro" >NUL 2>NUL
IF EXIST "%USERPROFILE%\mpoolpro" GOTO REMOVE_DIR1

echo [*] Unpacking "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\mpoolpro"
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\xmrig.zip', '%USERPROFILE%\mpoolpro')"
if errorlevel 1 (
  echo [*] Downloading 7za.exe to "%USERPROFILE%\7za.exe"
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/mpoolpro/xmrig_setup/master/7za.exe', '%USERPROFILE%\7za.exe')"
  if errorlevel 1 (
    echo ERROR: Can't download 7za.exe to "%USERPROFILE%\7za.exe"
    exit /b 1
  )
  echo [*] Unpacking advanced "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\mpoolpro"
  "%USERPROFILE%\7za.exe" x -y -o"%USERPROFILE%\mpoolpro" "%USERPROFILE%\xmrig.zip" >NUL
  if errorlevel 1 (
    echo ERROR: Can't unpack "%USERPROFILE%\xmrig.zip" to "%USERPROFILE%\mpoolpro"
    exit /b 1
  )
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\xmrig.zip"

echo [*] Checking if stock version of "%USERPROFILE%\mpoolpro\xmrig.exe" works fine ^(and not removed by antivirus software^)
powershell -Command "$out = cat '%USERPROFILE%\mpoolpro\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 0,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\mpoolpro\config.json'" 
"%USERPROFILE%\mpoolpro\xmrig.exe" --help >NUL
if %ERRORLEVEL% equ 0 goto MINER_OK

if exist "%USERPROFILE%\mpoolpro\xmrig.exe" (
  echo WARNING: Stock version of "%USERPROFILE%\mpoolpro\xmrig.exe" is not functional
) else (
  echo WARNING: Stock version of "%USERPROFILE%\mpoolpro\xmrig.exe" was removed by antivirus
)

exit /b 1

:MINER_OK

echo [*] Miner "%USERPROFILE%\mpoolpro\xmrig.exe" is OK

for /f "tokens=*" %%a in ('powershell -Command "hostname | %%{$_ -replace '[^a-zA-Z0-9]+', '_'}"') do set PASS=%%a
if [%PASS%] == [] (
  set PASS=na
)
if not [%EMAIL%] == [] (
  set "PASS=%PASS%:%EMAIL%"
)

powershell -Command "$out = cat '%USERPROFILE%\mpoolpro\config.json' | %%{$_ -replace '\"url\": *\".*\",', '\"url\": \"gulf.mpoolpro.stream:%PORT%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\mpoolpro\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\mpoolpro\config.json' | %%{$_ -replace '\"user\": *\".*\",', '\"user\": \"%WALLET%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\mpoolpro\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\mpoolpro\config.json' | %%{$_ -replace '\"pass\": *\".*\",', '\"pass\": \"%PASS%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\mpoolpro\config.json'" 
powershell -Command "$out = cat '%USERPROFILE%\mpoolpro\config.json' | %%{$_ -replace '\"max-cpu-usage\": *\d*,', '\"max-cpu-usage\": 100,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\mpoolpro\config.json'" 
set LOGFILE2=%LOGFILE:\=\\%
powershell -Command "$out = cat '%USERPROFILE%\mpoolpro\config.json' | %%{$_ -replace '\"log-file\": *null,', '\"log-file\": \"%LOGFILE2%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\mpoolpro\config.json'" 

copy /Y "%USERPROFILE%\mpoolpro\config.json" "%USERPROFILE%\mpoolpro\config_background.json" >NUL
powershell -Command "$out = cat '%USERPROFILE%\mpoolpro\config_background.json' | %%{$_ -replace '\"background\": *false,', '\"background\": true,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\mpoolpro\config_background.json'" 

rem preparing script
(
echo @echo off
echo tasklist /fi "imagename eq xmrig.exe" ^| find ":" ^>NUL
echo if errorlevel 1 goto ALREADY_RUNNING
echo start /low %%~dp0xmrig.exe %%^*
echo goto EXIT
echo :ALREADY_RUNNING
echo echo Monero miner is already running in the background. Refusing to run another one.
echo echo Run "taskkill /IM xmrig.exe" if you want to remove background miner first.
echo :EXIT
) > "%USERPROFILE%\mpoolpro\miner.bat"

rem preparing script background work and work under reboot

if %ADMIN% == 1 goto ADMIN_MINER_SETUP

if exist "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" (
  set "STARTUP_DIR=%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
  goto STARTUP_DIR_OK
)
if exist "%USERPROFILE%\Start Menu\Programs\Startup" (
  set "STARTUP_DIR=%USERPROFILE%\Start Menu\Programs\Startup"
  goto STARTUP_DIR_OK  
)

echo ERROR: Can't find Windows startup directory
exit /b 1

:STARTUP_DIR_OK
echo [*] Adding call to "%USERPROFILE%\mpoolpro\miner.bat" script to "%STARTUP_DIR%\mpool_miner.bat" script
(
echo @echo off
echo "%USERPROFILE%\mpoolpro\miner.bat" --config="%USERPROFILE%\mpoolpro\config_background.json"
) > "%STARTUP_DIR%\mpool_miner.bat"

echo [*] Running miner in the background
call "%STARTUP_DIR%\mpool_miner.bat"
goto OK

:ADMIN_MINER_SETUP

echo [*] Downloading tools to make mpool_miner service to "%USERPROFILE%\nssm.zip"
powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/mpoolpro/xmrig_setup/master/nssm.zip', '%USERPROFILE%\nssm.zip')"
if errorlevel 1 (
  echo ERROR: Can't download tools to make mpool_miner service
  exit /b 1
)

echo [*] Unpacking "%USERPROFILE%\nssm.zip" to "%USERPROFILE%\mpoolpro"
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\nssm.zip', '%USERPROFILE%\mpoolpro')"
if errorlevel 1 (
  echo [*] Downloading 7za.exe to "%USERPROFILE%\7za.exe"
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/mpoolpro/xmrig_setup/master/7za.exe', '%USERPROFILE%\7za.exe')"
  if errorlevel 1 (
    echo ERROR: Can't download 7za.exe to "%USERPROFILE%\7za.exe"
    exit /b 1
  )
  echo [*] Unpacking "%USERPROFILE%\nssm.zip" to "%USERPROFILE%\mpoolpro"
  "%USERPROFILE%\7za.exe" x -y -o"%USERPROFILE%\mpoolpro" "%USERPROFILE%\nssm.zip" >NUL
  if errorlevel 1 (
    echo ERROR: Can't unpack "%USERPROFILE%\nssm.zip" to "%USERPROFILE%\mpoolpro"
    exit /b 1
  )
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\nssm.zip"

echo [*] Creating mpool_miner service
sc stop mpool_miner
sc delete mpool_miner
"%USERPROFILE%\mpoolpro\nssm.exe" install mpool_miner "%USERPROFILE%\mpoolpro\xmrig.exe"
if errorlevel 1 (
  echo ERROR: Can't create mpool_miner service
  exit /b 1
)
"%USERPROFILE%\mpoolpro\nssm.exe" set mpool_miner AppDirectory "%USERPROFILE%\mpoolpro"
"%USERPROFILE%\mpoolpro\nssm.exe" set mpool_miner AppPriority BELOW_NORMAL_PRIORITY_CLASS
"%USERPROFILE%\mpoolpro\nssm.exe" set mpool_miner AppStdout "%USERPROFILE%\mpoolpro\stdout"
"%USERPROFILE%\mpoolpro\nssm.exe" set mpool_miner AppStderr "%USERPROFILE%\mpoolpro\stderr"

echo [*] Starting mpool_miner service
"%USERPROFILE%\mpoolpro\nssm.exe" start mpool_miner
if errorlevel 1 (
  echo ERROR: Can't start mpool_miner service
  exit /b 1
)

echo
echo Please reboot system if mpool_miner service is not activated yet (if "%USERPROFILE%\mpoolpro\xmrig.log" file is empty)
goto OK

:OK
echo
echo [*] Setup complete
pause
exit /b 0

:strlen string len
setlocal EnableDelayedExpansion
set "token=#%~1" & set "len=0"
for /L %%A in (12,-1,0) do (
  set/A "len|=1<<%%A"
  for %%B in (!len!) do if "!token:~%%B,1!"=="" set/A "len&=~1<<%%A"
)
endlocal & set %~2=%len%
exit /b





