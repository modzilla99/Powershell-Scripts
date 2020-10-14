@echo off

"%~dp0Elevate.exe" powershell.exe -ExecutionPolicy Unrestricted -File "%~dp0Install.ps1" -ScriptPath "%~dp0Install.ps1" -Reboot 0