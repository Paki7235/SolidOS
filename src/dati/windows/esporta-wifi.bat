@echo off
rem Esporta le reti Wi-Fi di Windows (con password) per importarle nel nuovo sistema.
rem Esegui questo file dalla chiavetta: le reti vengono salvate nella cartella "Reti Wi-Fi esportate".
set DEST=%~dp0Reti Wi-Fi esportate
mkdir "%DEST%" 2>nul
netsh wlan export profile key=clear folder="%DEST%"
echo.
echo Fatto. Le reti sono in "%DEST%".
pause
