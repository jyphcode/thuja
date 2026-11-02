with Thuja.Layout; use Thuja.Layout;
with Thuja.Widgets.Blocks;
with Thuja.Widgets.Labels;

package body Demo.Keyboard is

   package Blocks renames Thuja.Widgets.Blocks;
   package Labels renames Thuja.Widgets.Labels;

   function Image (N : Natural) return String;
   function Describe (Mods : Modifiers) return String;

   -----------
   -- Image --
   -----------

   function Image (N : Natural) return String is
      Text : constant String := N'Image;
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   --------------
   -- Describe --
   --------------

   function Describe (Mods : Modifiers) return String is
     ((if Mods.Ctrl then "Ctrl " else "")
      & (if Mods.Alt then "Alt " else "")
      & (if Mods.Shift then "Shift " else "")
      & (if Mods = No_Modifiers then "none" else ""));

   ----------
   -- Draw --
   ----------

   overriding procedure Draw
     (D : in out State; Frame : in out Buffer; Area : Rect; Focused : Boolean)
   is
      Info : constant Rect_Array :=
        Split (Blocks.Inner (Area), Column,
               [Fixed (1), Fixed (1), Fixed (1), Flex, Fixed (1)]);

      E : Event renames D.Last;
   begin
      Blocks.Draw (Frame, Area, "Keyboard", Border (Focused));

      Labels.Draw (Frame, Info (1), "kind : " & E.Kind'Image);

      case E.Kind is
         when Key_Down =>
            Labels.Draw (Frame, Info (2), "key  : " & E.Key'Image);
            Labels.Draw (Frame, Info (3), "mods : " & Describe (E.Mods));

         when Text_Input =>
            Labels.Draw (Frame, Info (2), "text : " & E.Text (1 .. E.Length));

         when Window_Resized =>
            Labels.Draw
              (Frame, Info (2),
               "size : " & Image (Natural (E.Size.Width)) & " x "
               & Image (Natural (E.Size.Height)));

         when others =>
            null;
      end case;

      Labels.Draw (Frame, Info (5), "Press keys to see how they decode.");
   end Draw;

   ------------
   -- Update --
   ------------

   overriding procedure Update (D : in out State; E : Event; Used : out Boolean) is
   begin
      D.Last := E;
      Used := True;
   end Update;

end Demo.Keyboard;
