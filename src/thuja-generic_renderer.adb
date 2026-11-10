with Bedrock.Colors; use Bedrock.Colors;
with Thuja.Styles;   use Thuja.Styles;
with Thuja.UTF8;

package body Thuja.Generic_Renderer is

   ESC   : constant Character := Character'Val (16#1B#);
   CSI   : constant String := ESC & "[";
   Reset : constant String := CSI & "0m";
   Erase : constant String := CSI & "2J";

   function Image (N : Natural) return String;
   --  N in decimal, no leading space.

   function Move_To (X, Y : Pixels) return String;
   --  Cursor to cell (X, Y). The terminal counts from 1.

   function Select_Style (S : Style) return String;
   --  One SGR sequence that sets exactly S, whatever was in force.

   function Printable (C : Wide_Wide_Character) return Wide_Wide_Character;
   --  C, or a space if C is a control character. Cell contents must
   --  never be able to send a command to the terminal.

   procedure Emit_Cell (X, Y : Pixels; C : Cell);

   procedure Emit_Cursor (C : Cursor_Info);

   -----------
   -- Image --
   -----------

   function Image (N : Natural) return String is
      Text : constant String := N'Image;
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   -------------
   -- Move_To --
   -------------

   function Move_To (X, Y : Pixels) return String is
     (CSI & Image (Natural (Y) + 1) & ";" & Image (Natural (X) + 1) & "H");

   ------------------
   -- Select_Style --
   ------------------

   function Select_Style (S : Style) return String is

      function RGB (C : Color) return String is
        (Image (Natural (C.R)) & ";" & Image (Natural (C.G)) & ";" & Image (Natural (C.B)));

   begin
      return CSI & "0"
        & (if S.Attr.Bold then ";1" else "")
        & (if S.Attr.Dim then ";2" else "")
        & (if S.Attr.Italic then ";3" else "")
        & (if S.Attr.Underline then ";4" else "")
        & (if S.Attr.Inverse then ";7" else "")
        & (if S.Attr.Strikethrough then ";9" else "")
        & (if Is_Default (S.Foreground) then "" else ";38;2;" & RGB (S.Foreground))
        & (if Is_Default (S.Background) then "" else ";48;2;" & RGB (S.Background))
        & "m";
   end Select_Style;

   ---------------
   -- Printable --
   ---------------

   function Printable (C : Wide_Wide_Character) return Wide_Wide_Character is
      Code : constant Natural := Wide_Wide_Character'Pos (C);
   begin
      if Code < 16#20# or else Code in 16#7F# .. 16#9F# then
         return ' ';
      end if;

      return C;
   end Printable;

   ---------------
   -- Emit_Cell --
   ---------------

   procedure Emit_Cell (X, Y : Pixels; C : Cell) is
   begin
      Emit (Move_To (X, Y) & Select_Style (C.Style) & UTF8.Encode (Printable (C.Glyph)));
   end Emit_Cell;

   ----------
   -- Diff --
   ----------

   procedure Diff (Before, After : Buffer) is
      Changed : Boolean := False;
   begin
      --  Hide the Cursor if it was visible
      --  To avoid a flicker
      if Cursor (Before).Visible
      then
         Emit (CSI & "?25l");
      end if;

      for Y in 0 .. After.Height - 1 loop
         for X in 0 .. After.Width - 1 loop
            if Get (After, X, Y) /= Get (Before, X, Y) then
               Emit_Cell (X, Y, Get (After, X, Y));
               Changed := True;
            end if;
         end loop;
      end loop;

      if Changed then
         Emit (Reset);
      end if;

      if (Changed and then Cursor (After).Visible)
        or else Cursor (Before) /= Cursor (After)
      then
         Emit_Cursor (Cursor (After));
      end if;
   end Diff;

   ----------
   -- Full --
   ----------

   procedure Full (After : Buffer) is
   begin
      Emit (Reset & Erase);

      for Y in 0 .. After.Height - 1 loop
         for X in 0 .. After.Width - 1 loop
            if Get (After, X, Y) /= Blank then
               Emit_Cell (X, Y, Get (After, X, Y));
            end if;
         end loop;
      end loop;

      Emit (Reset);

      if Cursor (After).Visible
      then
         Emit_Cursor (Cursor (After));
      end if;
   end Full;

   ----------------------
   -- Show/Hide Cursor --
   ----------------------

   procedure Emit_Cursor (C : Cursor_Info) is
   begin
      if not C.Visible then
         Emit (CSI & "?25l");
         return;
      end if;

      case C.Style is
         when Default =>
            Emit (CSI & "0 q");

         when Bar =>
            Emit (CSI & "5 q");

         when Block =>
            Emit (CSI & "2 q");
      end case;

      Emit (Move_To (C.X, C.Y));
      Emit (CSI & "?25h");
   end Emit_Cursor;

end Thuja.Generic_Renderer;
