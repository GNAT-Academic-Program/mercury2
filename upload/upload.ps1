# Upload a program to the NEORV32 bootloader on the Mercury 2 and run it (Windows).
# Do not run this file directly: use upload.bat, which starts it the right way.
#
#   .\upload\upload.bat examples\bin\blinky          finds the serial port on its own
#   .\upload\upload.bat examples\bin\blinky COM4     uses this port
#
# Before running this, reset the board so the bootloader is waiting:
# touch DIO 0 to GND, or power-cycle. The bootloader waits 8 seconds.
#
# What it does: turns the ELF into the bootloader's executable format
# (same bytes as NEORV32's image_gen -t exe), sends it, starts it, then shows
# what the program prints. Press Escape to quit.
param([string]$Elf, [string]$Port)
$Baud = 19200   # the bootloader's rate, and the rate Board.Initialize uses

if (-not $Elf -or -not (Test-Path $Elf)) {
  Write-Host "Usage: .\upload\upload.bat <elf file> [COM port]"
  Write-Host "Example: .\upload\upload.bat examples\bin\blinky"
  exit 1
}
$Elf = (Resolve-Path $Elf).Path
$Exe = "$Elf" + "_exe.bin"

# --- 1. ELF to raw binary ----------------------------------------------------
# riscv64-elf-objcopy comes with the Alire toolchain. "alr exec" puts it on the
# PATH, but only from inside a crate: the ELF lives in <crate>\bin, so go there.
$Crate = Split-Path (Split-Path $Elf)
$Raw = [System.IO.Path]::GetTempFileName()
if (Get-Command riscv64-elf-objcopy -ErrorAction SilentlyContinue) {
  & riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data $Elf $Raw
} else {
  Push-Location $Crate
  & alr -q exec -- riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data $Elf $Raw
  Pop-Location
}
if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: objcopy failed."
  exit 1
}

# --- 2. Add the bootloader header --------------------------------------------
# Header, four little-endian 32-bit words: signature 0x214F454E ("NEO!"),
# load address (0 = IMEM), size in bytes, bitwise NOT of the sum of all words.
$data = [System.IO.File]::ReadAllBytes($Raw)
Remove-Item $Raw
$pad = (4 - $data.Length % 4) % 4
if ($pad -ne 0) { $data += [byte[]]::new($pad) }
[uint64]$sum = 0
for ($i = 0; $i -lt $data.Length; $i += 4) {
  $sum = ($sum + [System.BitConverter]::ToUInt32($data, $i)) % 4294967296
}
[uint32]$check = 4294967295 - $sum
$header = [System.BitConverter]::GetBytes([uint32]0x214F454E) +
          [System.BitConverter]::GetBytes([uint32]0) +
          [System.BitConverter]::GetBytes([uint32]$data.Length) +
          [System.BitConverter]::GetBytes($check)
[System.IO.File]::WriteAllBytes($Exe, $header + $data)
Write-Host "Executable: $Exe ($($data.Length) bytes of code and data)"

# --- 3. Find the serial port -------------------------------------------------
if (-not $Port) {
  # Channel B of an FTDI chip: its device id ends with "B\0000".
  $ports = @(Get-PnpDevice -Class Ports -PresentOnly | Where-Object { $_.InstanceId -like "FTDIBUS\*B\0000" })
  if ($ports.Count -eq 0) {
    Write-Host "ERROR: no serial port found for the board."
    Write-Host "Plug it in. If Windows shows the board but no port, enable 'Load VCP' on"
    Write-Host "'USB Serial Converter B' in Device Manager (see the neorv32_mercury2 README)."
    exit 1
  }
  if ($ports.Count -gt 1) {
    Write-Host "More than one board found. Run again with the port of your board, for example:"
    Write-Host "  .\upload\upload.bat $Elf COM4"
    $ports | ForEach-Object { Write-Host "  $($_.FriendlyName)" }
    exit 1
  }
  if ($ports[0].FriendlyName -match "\((COM\d+)\)") {
    $Port = $Matches[1]
  } else {
    Write-Host "ERROR: could not read the port number of '$($ports[0].FriendlyName)'."
    exit 1
  }
}

# --- 4. Talk to the bootloader -----------------------------------------------
$serial = New-Object System.IO.Ports.SerialPort $Port, $Baud, "None", 8, "One"
$serial.ReadTimeout = 1000
try {
  $serial.Open()
} catch {
  Write-Host "ERROR: cannot open $Port. Another program is using it, or it does not exist."
  Write-Host "Close the other program (a console window, PuTTY, Tera Term), then run this again."
  exit 1
}

# Reads from the port until the text appears or the time runs out.
function Wait-For([string]$Pattern, [int]$Seconds) {
  $buffer = ""
  $expire = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $expire) {
    try { $buffer += $serial.ReadExisting() } catch {}
    if ($buffer.Contains($Pattern)) { return $true }
    Start-Sleep -Milliseconds 50
  }
  Write-Host ""
  Write-Host "ERROR: the bootloader did not answer `"$Pattern`"."
  Write-Host "Reset the board (DIO 0 to GND, or power-cycle), then run this again within 8 seconds."
  return $false
}

$serial.Write(" ")                   # stop the auto-boot countdown
Start-Sleep -Milliseconds 200
$serial.Write("u")                   # upload command
if (-not (Wait-For "Awaiting" 5)) { $serial.Close(); exit 1 }
Write-Host "Uploading..."
$bytes = [System.IO.File]::ReadAllBytes($Exe)
$serial.Write($bytes, 0, $bytes.Length)
if (-not (Wait-For "OK" ([int]($bytes.Length / ($Baud / 10)) + 5))) { $serial.Close(); exit 1 }
$serial.Write("e")                   # execute
Write-Host "Running. Press Escape to quit."
Write-Host ""

try {
  while ($true) {
    if ($serial.BytesToRead) { Write-Host -NoNewline $serial.ReadExisting() }
    if ([Console]::KeyAvailable) {
      $key = [Console]::ReadKey($true)
      if ($key.Key -eq "Escape") { break }
      if ($key.Key -eq "Enter") { $serial.Write("`n") } else { $serial.Write($key.KeyChar) }
    }
    Start-Sleep -Milliseconds 10
  }
} finally {
  $serial.Close()
  Write-Host ""
}
