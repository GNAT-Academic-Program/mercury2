with Debug_Generic;
with Board_Log;

package Debug is new Debug_Generic
  (Driver_Write => Board_Log.Write);