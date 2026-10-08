@echo off
rem Abre el juego con todos los mundos desbloqueados (para probar).
start "" "%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -- --unlock-all
