with Instances;
with Board_GPIO;

with Gpio;

package Board is

   --  -------------------------------------------------------------------
   --  Buses (vendor-neutral facades over MCU-level instances)
   --
   --  Naming reflects the SoC wiring in the neorv32_mercury2 bitstream,
   --  not the application role.
   --  -------------------------------------------------------------------

   --  Console: UART0, FT2232H channel B (second USB serial port), 19200 8N1,
   --  the same settings as the bootloader, so one terminal session covers both.
   package Console renames Instances.Console;

   --  -------------------------------------------------------------------
   --  GPIO pins (board-specific assignments)
   --  -------------------------------------------------------------------

   Led_Blue   : Gpio.Pin renames Board_GPIO.Led_Blue;
   Led_Green  : Gpio.Pin renames Board_GPIO.Led_Green;
   Led_Orange : Gpio.Pin renames Board_GPIO.Led_Orange;

   --  The LED, when an application needs only one: the blue one.
   Led : Gpio.Pin renames Board_GPIO.Led_Blue;

   procedure Initialize;
   --  Opens the console, checks that the bitstream carries the NEORV32
   --  release the drivers were written for, and sets up the LEDs.
   --  On a version mismatch it prints both versions on the console and
   --  stops there, blinking all three LEDs. It does not return.

end Board;
