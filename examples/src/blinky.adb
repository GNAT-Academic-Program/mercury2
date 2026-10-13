with Board;
with Gpio;
with Debug;

procedure Blinky is
   Count : Natural := 0;
begin
   Board.Initialize;
   Debug.Put_Line ("blinky on mercury2");

   loop
      Gpio.Toggle (Board.Led);
      Count := Count + 1;
      Debug.Put_Line ("tick" & Debug.Img (Count));
      delay 0.5;
   end loop;
end Blinky;
