package Demo.Keyboard is
   type State is new Instance with record
      Last : Event := No_Event;
   end record;

   overriding function Name (D : State) return String is ("Keyboard");
   overriding procedure Draw
     (D : in out State; Frame : in out Buffer; Area : Rect; Focused : Boolean);
   overriding procedure Update (D : in out State; E : Event; Used : out Boolean);
end Demo.Keyboard;
