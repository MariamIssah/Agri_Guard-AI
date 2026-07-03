@echo off
cd /d "c:\Users\awini\ag-ai\backend\fastapi"

:: Kill any existing instance on port 8002
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8002 "') do (
    taskkill /PID %%a /F >nul 2>&1
)
timeout /t 2 >nul

:: Start FastAPI
echo Starting AgriGuard API on port 8002...
start "" "c:\Users\awini\ag-ai\.venv\Scripts\python.exe" -m uvicorn app:app --host 0.0.0.0 --port 8002
timeout /t 4 >nul

:: Re-establish ADB tunnel
echo Setting up ADB tunnel...
adb reverse tcp:8002 tcp:8002

echo Done. API is live at http://localhost:8002
pause
