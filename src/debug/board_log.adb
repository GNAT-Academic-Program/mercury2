with Board;

package body Board_Log is
   procedure Write (Buf : Storage_Array) is
      Written : Storage_Offset;
   begin
      Board.Console.Write (Buf, Written);
   end Write;
end Board_Log;
