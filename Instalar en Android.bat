@echo off
rem Compila el APK de depuracion y lo instala en el movil conectado por USB.
set GODOT=%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe
set ADB=D:\AndroidSdk\platform-tools\adb.exe
cd /d "%~dp0"
if not exist build mkdir build
echo Compilando APK...
"%GODOT%" --headless --path . --export-debug "Android" build\CozyMinigolf.apk >build\export.log 2>&1 || goto error
echo Instalando en el movil...
"%ADB%" -d install -r build\CozyMinigolf.apk || goto error
"%ADB%" -d shell monkey -p com.minigolf2026.game -c android.intent.category.LAUNCHER 1 >nul 2>&1
echo Listo: el juego se esta abriendo en el movil.
pause
exit /b 0
:error
echo Algo ha fallado. Comprueba que el movil esta conectado por USB con la depuracion USB activada
echo y que has aceptado el aviso "Permitir depuracion USB" en la pantalla del movil.
echo Detalles de la compilacion en build\export.log
pause
exit /b 1
