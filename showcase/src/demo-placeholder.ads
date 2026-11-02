package Demo.Placeholder is
   type State (Length : Positive) is new Instance with record
      Title : String (1 .. Length);
   end record;

   function Make (Title : String) return State
     with Pre => Title'Length > 0;

   overriding function Name (D : State) return String is (D.Title);
   overriding procedure Draw
     (D : in out State; Frame : in out Buffer; Area : Rect; Focused : Boolean);
   overriding procedure Update (D : in out State; E : Event; Used : out Boolean);
end Demo.Placeholder;
