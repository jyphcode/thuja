with Thuja;
with Thuja.Widgets.Blocks;
with Thuja.Widgets.Labels;

package body Demo.Placeholder is

   package Blocks renames Thuja.Widgets.Blocks;
   package Labels renames Thuja.Widgets.Labels;

   ----------
   -- Make --
   ----------

   function Make (Title : String) return State is
     ((Length => Title'Length, Title => Title));

   ----------
   -- Draw --
   ----------

   overriding procedure Draw
     (D : in out State; Frame : in out Buffer; Area : Rect; Focused : Boolean)
   is
   begin
      Blocks.Draw (Frame, Area, D.Title, Border (Focused));
      Labels.Draw
        (Frame, Thuja.Inset (Area, 1), "Not built yet.", Dim (Plain));
   end Draw;

   ------------
   -- Update --
   ------------

   overriding procedure Update (D : in out State; E : Event; Used : out Boolean) is
      pragma Unreferenced (D, E);
   begin
      Used := False;
   end Update;

end Demo.Placeholder;
