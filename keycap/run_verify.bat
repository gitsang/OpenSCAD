@echo off
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
"C:\Program Files\FreeCAD 1.1\bin\python.exe" -u verify.py > _verify_out.txt 2>&1
set RC=%ERRORLEVEL%
type _verify_out.txt
echo EXIT=%RC%
exit /b %RC%
