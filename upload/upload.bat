@echo off
rem Upload a program to the NEORV32 bootloader on the Mercury 2 and run it (Windows).
rem   .\upload\upload.bat examples\bin\blinky          finds the serial port on its own
rem   .\upload\upload.bat examples\bin\blinky COM4     uses this port
rem Starts upload.ps1 next to this file with the policy that lets a local script run.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0upload.ps1" %*
