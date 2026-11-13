with Thuja.Widgets.Generic_Lists;

package Demo.HTop is

   function Process_Count return Natural;
   function Process_Row (Index : Positive) return String;

   package Process_Lists is new Thuja.Widgets.Generic_Lists
     (Count => Process_Count,
      Text  => Process_Row);

   type State is new Instance with record
      Procs       : Process_Lists.State;
      Ticks       : Natural := 0;
      Sort_By_Mem : Boolean := False;
      CPU_Total   : Natural := 18;
      Mem_Total   : Natural := 36;
   end record;

   overriding function Name (D : State) return String is ("HTop");

   overriding procedure Draw
     (D       : in out State;
      Frame   : in out Buffer;
      Area    : Rect;
      Focused : Boolean);

   overriding procedure Update
     (D    : in out State;
      E    : Event;
      Used : out Boolean);

end Demo.HTop;