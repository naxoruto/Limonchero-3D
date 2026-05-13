@echo off
setlocal

rem Build the Limonchero backend launcher for Windows

cd /d %~dp0

echo [INFO] Verificando el entorno virtual...
if not exist venv (
  python -m venv venv
)

echo [INFO] Activando el entorno virtual...
call venv\Scripts\activate.bat

echo [INFO] Actualizando pip...
python -m pip install --upgrade pip

echo [INFO] Instalando dependencias de requiments.txt...
pip install -r backend\requirements.txt

echo [INFO] Instalando PyInstaller...
pip install pyinstaller

echo [INFO] Compilando ejecutable con PyInstaller (esto puede tardar unos minutos)...
pyinstaller --clean --noconfirm --onefile --name limonchero-backend --paths backend --hidden-import config --hidden-import main --collect-data faster_whisper backend\launcher.py

echo.
echo Build complete. Output: %~dp0dist\limonchero-backend.exe
endlocal
pause
