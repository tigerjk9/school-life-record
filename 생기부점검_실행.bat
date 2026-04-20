@echo off
chcp 65001 > nul
title 생활기록부 점검 프로그램

echo 서버를 시작합니다...
cd /d "%~dp0"

:: 가상환경이 있으면 활성화
if exist ".venv\Scripts\activate.bat" call .venv\Scripts\activate.bat

:: 서버 시작 (백그라운드)
start /min "" python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000

:: 서버 준비 대기 (2초)
timeout /t 2 /nobreak > nul

:: 브라우저 열기
start http://127.0.0.1:8000

echo 브라우저가 열렸습니다.
echo 프로그램을 종료하려면 이 창을 닫으세요.
echo.
pause
