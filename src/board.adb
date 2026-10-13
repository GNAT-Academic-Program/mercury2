with Gpio_Types;
with Usart_Types;
with Board_GPIO;
with NEORV32_System;
with Debug;

with Last_Chance_Handler;
pragma Unreferenced (Last_Chance_Handler);

package body Board is

   --  -------------------------------------------------------------------
   --  GPIO initialization
   --  -------------------------------------------------------------------

   procedure Init_Led_Gpio is
      Cfg : constant Gpio_Types.Gpio_Config :=
        (Mode       => Gpio_Types.Output,
         Pull       => Gpio_Types.None,
         Drive      => Gpio_Types.Push_Pull,
         Speed      => Gpio_Types.Low_Speed,
         Init_State => Gpio_Types.Low);
   begin
      Gpio.Configure (Board_GPIO.Led_Blue, Cfg);
      Gpio.Configure (Board_GPIO.Led_Green, Cfg);
      Gpio.Configure (Board_GPIO.Led_Orange, Cfg);
   end Init_Led_Gpio;

   --  -------------------------------------------------------------------
   --  Version check
   --
   --  The neorv32 crate is written for one NEORV32 release. A bitstream of
   --  another release has different registers, and a driver on it fails in
   --  ways nobody can trace. So this is the first thing checked, and a
   --  mismatch stops here with a message instead of running on.
   --  -------------------------------------------------------------------

   procedure Halt_On_Version_Mismatch is
   begin
      Debug.Put_Line ("NEORV32 version mismatch");
      Debug.Put_Line
        ("  bitstream has   0x"
         & Debug.Hex (Natural (NEORV32_System.Hardware_Version)));
      Debug.Put_Line
        ("  drivers expect  0x"
         & Debug.Hex (Natural (NEORV32_System.Expected_Version)));
      Debug.Put_Line
        ("Load the bitstream of the matching neorv32_mercury2 release.");

      loop
         Gpio.Toggle (Board_GPIO.Led_Blue);
         Gpio.Toggle (Board_GPIO.Led_Green);
         Gpio.Toggle (Board_GPIO.Led_Orange);
         delay 0.1;
      end loop;
   end Halt_On_Version_Mismatch;

   --  -------------------------------------------------------------------
   --  Public entry point
   --  -------------------------------------------------------------------

   procedure Initialize is
   begin
      --  Console first, so the version check has somewhere to report.
      --  The UART pins are fixed in the gateware: no GPIO to configure.
      Console.Open
        ((Baud      => Usart_Types.B19200,
          Data_Bits => Usart_Types.Data_8,
          Parity    => Usart_Types.None,
          Stop_Bits => Usart_Types.Stop_1,
          Flow      => Usart_Types.None));

      Init_Led_Gpio;

      if not NEORV32_System.Version_Matches then
         Halt_On_Version_Mismatch;
      end if;
   end Initialize;

end Board;
