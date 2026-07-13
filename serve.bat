@echo off
echo Starting VaultLocal on http://192.168.1.188:8080
echo.
echo Open this on your iPhone: http://192.168.1.188:8080
echo Press Ctrl+C to stop.
echo.
cd /d "C:\Users\jesus\Documents\Development\vault"
python -m http.server 8080
pause
