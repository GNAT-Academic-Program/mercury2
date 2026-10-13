--  Board_GPIO: complete GPIO pin map for the Mercury 2 with the
--  neorv32_mercury2 bitstream. Every pin used on this board is declared here.
--
--  On NEORV32 the GPIO numbers are not FPGA pins: the gateware decides which
--  FPGA pin each GPIO line drives. The FPGA pins below are quoted from the
--  constraints of neorv32_mercury2 (vivado/mercury2/mercury2.xdc).
--
--  UART0 has no GPIO: its two wires go straight from the SoC to the FT2232H
--  in the gateware. There is nothing to configure on the software side.

with Gpio;
with NEORV32_GPIO;

package Board_GPIO is

   --  D3, blue user LED, active-high. Also the bootloader status LED.
   Led_Blue : constant Gpio.Pin := NEORV32_GPIO.Make_Pin (0);   --  M1

   --  D4, green user LED, active-high.
   Led_Green : constant Gpio.Pin := NEORV32_GPIO.Make_Pin (1);  --  A14

   --  D5, orange user LED, active-high.
   Led_Orange : constant Gpio.Pin := NEORV32_GPIO.Make_Pin (2); --  A13

end Board_GPIO;
