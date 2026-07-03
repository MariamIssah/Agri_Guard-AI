"""
AgriGuard API watchdog — keeps uvicorn alive, restarts on crash.
Run: python run_api.py
"""
import subprocess
import sys
import time
import os

VENV_PYTHON = r"c:\Users\awini\ag-ai\.venv\Scripts\python.exe"
WORK_DIR    = r"c:\Users\awini\ag-ai\backend\fastapi"
CMD = [VENV_PYTHON, "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8002"]

def main():
    restart_count = 0
    while True:
        print(f"\n[watchdog] Starting API (restart #{restart_count})...")
        proc = subprocess.Popen(CMD, cwd=WORK_DIR)
        proc.wait()
        code = proc.returncode
        print(f"[watchdog] Process exited with code {code}. Restarting in 3s...")
        restart_count += 1
        time.sleep(3)

if __name__ == "__main__":
    main()
