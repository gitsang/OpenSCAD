@echo off
rem =====================================================================
rem  3030 工作台 —— 自检 / 预览 一键脚本
rem     run_check.bat            自检
rem     run_check.bat --quick    跳过慢的体积探测
rem     run_check.bat --png      顺便生成 4 张预览图
rem =====================================================================
cd /d "%~dp0"
set PY="C:\Program Files\FreeCAD 1.1\bin\python.exe"
if not exist %PY% set PY=python

%PY% check.py %* > _check.log 2>&1
set RC=%ERRORLEVEL%
echo. >> _check.log
echo [exit=%RC%] >> _check.log
type _check.log
exit /b %RC%
