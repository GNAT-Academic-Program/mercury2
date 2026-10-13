#!/usr/bin/env bash
# Upload a program to the NEORV32 bootloader on the Mercury 2 and run it (Linux).
#
#   bash upload/upload.sh examples/bin/blinky                 finds the serial port on its own
#   bash upload/upload.sh examples/bin/blinky /dev/ttyUSB1    uses this port
#
# Before running this, reset the board so the bootloader is waiting:
# touch DIO 0 to GND, or power-cycle. The bootloader waits 8 seconds.
#
# What it does: turns the ELF into the bootloader's executable format
# (same bytes as NEORV32's image_gen -t exe), sends it, starts it, then shows
# what the program prints. Press Escape to quit.
set -euo pipefail

elf=${1:-}
port=${2:-}
baud=19200   # the bootloader's rate, and the rate Board.Initialize uses

if [ -z "$elf" ] || [ ! -f "$elf" ]; then
  echo "Usage: bash $0 <elf file> [serial port]"
  echo "Example: bash $0 examples/bin/blinky"
  exit 1
fi
elf=$(cd "$(dirname "$elf")" && pwd)/$(basename "$elf")
exe=${elf}_exe.bin

# --- 1. ELF to raw binary ----------------------------------------------------
# riscv64-elf-objcopy comes with the Alire toolchain. "alr exec" puts it on the
# PATH, but only from inside a crate: the ELF lives in <crate>/bin, so go there.
crate=$(dirname "$(dirname "$elf")")
raw=$(mktemp)
trap 'rm -f "$raw"' EXIT
if command -v riscv64-elf-objcopy >/dev/null 2>&1; then
  riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data "$elf" "$raw"
else
  (cd "$crate" && alr -q exec -- riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data "$elf" "$raw")
fi

# --- 2. Add the bootloader header --------------------------------------------
# Header, four little-endian 32-bit words: signature 0x214F454E ("NEO!"),
# load address (0 = IMEM), size in bytes, bitwise NOT of the sum of all words.
size=$(stat -c%s "$raw")
pad=$(( (4 - size % 4) % 4 ))
if [ "$pad" -ne 0 ]; then
  head -c "$pad" /dev/zero >> "$raw"
  size=$(( size + pad ))
fi
sum=$(od -An -t u4 -v "$raw" | awk '{ for (i = 1; i <= NF; i++) s = (s + $i) % 4294967296 } END { printf "%d", s }')
check=$(( 4294967295 - sum ))

le32 () {   # print a 32-bit value as 4 little-endian bytes
  local v=$1
  printf "\\x$(printf %02x $(( v        & 255 )))"
  printf "\\x$(printf %02x $(( v >> 8   & 255 )))"
  printf "\\x$(printf %02x $(( v >> 16  & 255 )))"
  printf "\\x$(printf %02x $(( v >> 24  & 255 )))"
}
{ le32 $((16#214F454E)); le32 0; le32 "$size"; le32 "$check"; cat "$raw"; } > "$exe"
echo "Executable: $exe ($size bytes of code and data)"

# --- 3. Find the serial port -------------------------------------------------
if [ -z "$port" ]; then
  # Channel B of an FTDI chip is USB interface 1: its name ends with "-if01-port0".
  shopt -s nullglob
  found=(/dev/serial/by-id/*-if01-port0)
  if [ ${#found[@]} -eq 0 ]; then
    echo "ERROR: no serial port found for the board."
    echo "Plug it in. If you just flashed it, bring the serial ports back with:"
    echo "  sudo modprobe ftdi_sio"
    exit 1
  fi
  if [ ${#found[@]} -gt 1 ]; then
    echo "More than one board found. Run again with the port of your board, one of:"
    for p in "${found[@]}"; do echo "  bash $0 $1 $p"; done
    exit 1
  fi
  port=${found[0]}
fi
if [ ! -e "$port" ]; then
  echo "ERROR: $port does not exist."
  exit 1
fi
if [ ! -r "$port" ] || [ ! -w "$port" ]; then
  echo "ERROR: no permission on $port. Run again with sudo:"
  echo "  sudo bash $0 $1 $port"
  exit 1
fi

# --- 4. Talk to the bootloader -----------------------------------------------
stty -F "$port" "$baud" cs8 -cstopb -parenb raw -echo -hup clocal cread
exec 3<>"$port"

# Reads from the port until the text appears or the time runs out.
wait_for () {
  local pattern=$1 seconds=$2 buffer="" ch
  local expire=$(( SECONDS + seconds ))
  while [ $SECONDS -lt $expire ]; do
    if IFS= read -r -n 1 -u 3 -t 1 ch; then
      buffer+=$ch
      case "$buffer" in *"$pattern"*) return 0 ;; esac
    fi
  done
  echo
  echo "ERROR: the bootloader did not answer \"$pattern\"."
  echo "Reset the board (DIO 0 to GND, or power-cycle), then run this again within 8 seconds."
  return 1
}

printf ' ' >&3                       # stop the auto-boot countdown
sleep 0.2
printf 'u' >&3                       # upload command
wait_for "Awaiting" 5
echo "Uploading..."
cat "$exe" >&3
wait_for "OK" $(( size / (baud / 10) + 5 ))
printf 'e' >&3                       # execute
echo "Running. Press Escape to quit."
echo

cat <&3 &
reader=$!
trap 'kill "$reader" 2>/dev/null; rm -f "$raw"; echo' EXIT
while IFS= read -rsn1 key; do
  [ "$key" = $'\e' ] && break
  [ -z "$key" ] && key=$'\n'
  printf '%s' "$key" >&3
done
