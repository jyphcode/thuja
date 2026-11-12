with Thuja.Widgets.Text_Fields;

package Demo.Text_Fields is
   package Text_Field renames Thuja.Widgets.Text_Fields;

   Title     : String(1..11) := "Text Inputs";

   type State is new Instance with record
      
      FirstName : Text_Field.State;
      LastName  : Text_Field.State;
      Email     : Text_Field.State;
   end record;

   overriding function Name (D : State) return String is (Title);
   overriding procedure Draw
     (D : in out State; Frame : in out Buffer; Area : Rect; Focused : Boolean);
   overriding procedure Update (D : in out State; E : Event; Used : out Boolean);
end Demo.Text_Fields;
