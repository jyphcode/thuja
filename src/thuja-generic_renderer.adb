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

   ----------
   -- Diff --
   ----------

   procedure Diff (Before, After : Buffer) is
      Changed      : Boolean := False;
      Cursor_X     : Integer := -1;
      Cursor_Y     : Integer := -1;
      Active_Style : Style;
      Style_Set    : Boolean := False;
      C            : Cell;
   begin

      for Y in 0 .. After.Height - 1 loop
         for X in 0 .. After.Width - 1 loop

            C := Get (After, X, Y);

            if C /= Get (Before, X, Y) then

               --  If not in position, jump cursor
               if Integer (X) /= Cursor_X or else Integer (Y) /= Cursor_Y then
                  Emit (Move_To (X, Y));
               end if;

               --  If different from active state, emit style
               if not Style_Set or else C.Style /= Active_Style then
                  Emit (Select_Style (C.Style));
                  Active_Style := C.Style;
                  Style_Set := True;
               end if;

               --  Print char
               Emit (UTF8.Encode (Printable (C.Glyph)));

               --  Update cursor position
               Cursor_X := Integer (X) + 1;
               Cursor_Y := Integer (Y);
               Changed := True;

            end if;
         end loop;
      end loop;

      if Changed then
         Emit (Reset);
      end if;
   end Diff;

   ----------
   -- Full --
   ----------

   procedure Full (After : Buffer) is
      Cursor_X     : Integer := -1;
      Cursor_Y     : Integer := -1;
      Active_Style : Style;
      Style_Set    : Boolean := False;
      C            : Cell;
   begin
      Emit (Reset & Erase);

      for Y in 0 .. After.Height - 1 loop
         for X in 0 .. After.Width - 1 loop

            C := Get (After, X, Y);

            if C /= Blank then
               if Integer (X) /= Cursor_X or else Integer (Y) /= Cursor_Y then
                  Emit (Move_To (X, Y));
               end if;

               if not Style_Set or else C.Style /= Active_Style then
                  Emit (Select_Style (C.Style));
                  Active_Style := C.Style;
                  Style_Set := True;
               end if;

               Emit (UTF8.Encode (Printable (C.Glyph)));
               Cursor_X := Integer (X) + 1;
               Cursor_Y := Integer (Y);
            end if;
         end loop;
      end loop;

      Emit (Reset);
   end Full;

end Thuja.Generic_Renderer;