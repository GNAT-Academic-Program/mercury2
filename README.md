# mercury2

Board support package for the MicroNova Mercury 2 running the
[neorv32_mercury2](https://github.com/GNAT-Academic-Program/neorv32_mercury2)
bitstream.

## Overview

`mercury2` is the board crate of the GAP NEORV32 stack. It instantiates the
[neorv32](https://github.com/GNAT-Academic-Program/neorv32_ghal) drivers for
the wiring of this board and gives applications a `Board` package, the same
way `stm32f746g_disco` and `nucleo_g431kb` do for their boards.

```
Application (examples/blinky)
    |
Board crate (mercury2)   <- this crate
    |
MCU crate (neorv32)
    |
Generic interfaces (gpio_generic, usart_generic, debug_generic)
```

## What the board offers today

With the current bitstream the SoC exposes the three user LEDs and the
console UART. That is what this crate covers.

| `Board` name | Hardware |
|---|---|
| `Console` | UART0 on FT2232H channel B, the second USB serial port. 19200 8N1, same as the bootloader, so one terminal covers both |
| `Led_Blue`, `Led` | D3, GPIO 0. Also the bootloader status LED |
| `Led_Green` | D4, GPIO 1 |
| `Led_Orange` | D5, GPIO 2 |

`Board.Initialize` opens the console, checks that the bitstream carries the
NEORV32 release the drivers were written for (v1.13.6), and configures the
LEDs. On a version mismatch it prints both versions and stops, blinking all
three LEDs.

`Debug.Put_Line` writes to the console. The last chance handler prints the
exception on the console and blinks the blue LED fast.

The SRAM, the ADC, the DAC, the headers and the Ethernet PHY need gateware
first. They come with later bitstreams.

## Requirements

- [Alire](https://alire.ada.dev/) 2.0 or newer and git. The RISC-V toolchain
  is fetched by Alire.
- A Mercury 2 with the neorv32_mercury2 bitstream loaded, connected over USB.

## Build the example

From the root of this repo:

```
cd examples
```

```
alr build
```

Result: `examples/bin/blinky`.

## Run it on the board

The bootloader in the bitstream takes the program over the serial port. The
upload script converts the ELF, sends it, starts it, and then shows what the
program prints. Press Escape to quit.

1. Reset the board so the bootloader is waiting: touch DIO 0 to GND, or
   power-cycle. The bootloader waits 8 seconds for a command.
2. Run the upload script from the root of this repo.

Linux:

```
bash upload/upload.sh examples/bin/blinky
```

Windows:

```
.\upload\upload.bat examples\bin\blinky
```

The script finds the board's serial port on its own. If it cannot, it says
so and tells you how to pass the port by hand.

Expected output:

```
blinky on mercury2
tick 1
tick 2
```

and the blue LED toggles every half second.

Linux may refuse the serial port without `sudo`; the script prints the exact
command to run in that case. Windows may need "Load VCP" enabled once on
"USB Serial Converter B" in Device Manager; the neorv32_mercury2 README has
the steps.

## In application code

```ada
with Board;
with Gpio;
with Debug;

procedure Main is
begin
   Board.Initialize;
   Debug.Put_Line ("hello");
   loop
      Gpio.Toggle (Board.Led);
      delay 0.5;
   end loop;
end Main;
```

The project file needs the runtime, as in `examples/mercury2_examples.gpr`:

```ada
with "runtime_build.gpr";
with "ravenscar_build.gpr";

for Target use runtime_build'Target;
for Runtime ("Ada") use runtime_build'Runtime ("Ada");

package Linker is
   for Switches ("Ada") use Runtime_Build.Linker_Switches;
end Linker;
```

## Integration

Add to your `alire.toml`:

```toml
[[depends-on]]
mercury2 = "*"

[[pins]]
mercury2 = { url = "https://github.com/GNAT-Academic-Program/mercury2.git", branch = "main" }
```

## Layout

```
src/board.ads, board.adb        Board: console, LEDs, Initialize
src/board_gpio.ads              every GPIO pin used, in one place
src/instances.ads               driver instances: UART0 -> Console
src/debug/                      Debug output and the last chance handler
examples/                       mercury2_examples crate: blinky
upload/                         upload scripts for Linux and Windows
```

## Dependencies

- `neorv32`: NEORV32 drivers (GPIO, UART, SYSINFO)
- `light_tasking_neorv32`: the Ada runtime
- `debug_generic`: generic debug output

## License

MIT OR Apache-2.0 WITH LLVM-exception
