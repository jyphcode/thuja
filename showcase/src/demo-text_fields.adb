with Thuja;
with Thuja.Widgets.Blocks;
with Thuja.Layout;   use Thuja.Layout;

package body Demo.Text_Fields is

   package Blocks renames Thuja.Widgets.Blocks;

   ----------
   -- Draw --
   ----------

   overriding procedure Draw
     (D : in out State; Frame : in out Buffer; Area : Rect; Focused : Boolean)
   is
      Fields : constant Rect_Array :=
        Split
         (Area  => Area,
          Along => Column,
          Items => [Fixed (3), Fixed (3), Fixed (3)],
          Gap   => 1);
   begin
      Blocks.Draw (Frame, Area, Title, Border (Focused));

      Text_Field.Draw (Frame, Blocks.Inner (Fields (1)), D.FirstName, "First Name");
      Text_Field.Draw (Frame, Blocks.Inner (Fields (2)), D.LastName, "Last Name");
      Text_Field.Draw (Frame, Blocks.Inner (Fields (3)), D.Email, "Email");

   end Draw;

   ------------
   -- Update --
   ------------

   overriding procedure Update (D : in out State; E : Event; Used : out Boolean) is
   begin
      --  Offer the event to the widgets that exist
      --  @TODO eventually replace with focus and event dispatcher
      Text_Field.Handle (D.Firstname, E, Used);
      Text_Field.Handle (D.LastName, E, Used);
      Text_Field.Handle (D.Email, E, Used);
   end Update;

end Demo.Text_Fields;
