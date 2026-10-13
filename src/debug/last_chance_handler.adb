with Board;
with Gpio;
with System; use System;
with System.Storage_Elements; use System.Storage_Elements;

package body Last_Chance_Handler is

   procedure Last_Chance_Handler (Msg : System.Address; Line : Integer) is

      procedure Console_Write (S : String) is
         Written : Storage_Offset;
         Buf     : Storage_Array (1 .. S'Length);
      begin
         for I in S'Range loop
            Buf (Storage_Offset (I - S'First + 1)) := Storage_Element (Character'Pos (S (I)));
         end loop;
         Board.Console.Write (Buf, Written);
      end Console_Write;

      function Msg_String return String is
         Max : constant := 128;
         S   : String (1 .. Max);
         Len : Natural := 0;
         P   : Address := Msg;
      begin
         loop
            exit when Len = Max;
            declare
               E : Storage_Element;
               for E'Address use P;
               pragma Import (Ada, E);
            begin
               exit when E = 0;
               Len := Len + 1;
               S (Len) := Character'Val (Natural (E));
               P := P + 1;
            end;
         end loop;
         return S (1 .. Len);
      end Msg_String;

   begin
      Board.Initialize;

      Console_Write ("CRASH at line ");
      Console_Write (Integer'Image (Line));
      Console_Write (": ");
      Console_Write (Msg_String);
      Console_Write ("" & ASCII.CR & ASCII.LF);

      loop
         Gpio.Toggle (Board.Led);
         delay 0.05;
      end loop;
   end Last_Chance_Handler;

end Last_Chance_Handler;
