--  The frame: a grid of cells the application draws into.
--
--  Drawing never fails and never writes outside the buffer: every
--  operation clips. A widget handed a rectangle that is half off the
--  screen, or no bigger than nothing, simply draws what fits. That one
--  rule is what lets layouts shrink to any terminal size without a
--  single Constraint_Error.
--
--  PLACEHOLDER. One cell holds one character and every character is
--  taken to be one column wide. Characters that take two columns (CJK,
--  most emoji) and combining marks, which take none, are not handled.

with Thuja.Styles; use Thuja.Styles;

package Thuja.Buffers with SPARK_Mode is

   type Cell is record
      Glyph : Wide_Wide_Character := ' ';
      Style : Styles.Style        := Plain;
   end record;

   Blank : constant Cell := (' ', Plain);

   type Buffer (Width : Column_Count; Height : Row_Count) is private;
   --  Width x Height cells. A new buffer is all Blank. Cell (0, 0) is
   --  the top-left one.

   function Area (B : Buffer) return Rect is
     (Make (0, 0, B.Width, B.Height))
     with Post => In_Range (Area'Result);

   function Has (B : Buffer; X, Y : Pixels) return Boolean is
     (X in 0 .. B.Width - 1 and then Y in 0 .. B.Height - 1);

   function Get (B : Buffer; X, Y : Pixels) return Cell
     with Pre => Has (B, X, Y);

   ---------------------------------------------------------------------
   --  Drawing. Everything clips to the buffer.
   ---------------------------------------------------------------------

   procedure Clear (B : in out Buffer);
   --  Every cell back to Blank.

   procedure Set (B : in out Buffer; X, Y : Pixels; C : Cell)
     with Post => (if Has (B, X, Y) then Get (B, X, Y) = C);
   --  One cell. Nothing happens if (X, Y) is outside.

   procedure Fill (B : in out Buffer; Area : Rect; C : Cell);
   --  Every cell of Area that is inside the buffer.

   procedure Copy (Source : Buffer; Target : in out Buffer);
   --  Source onto Target, top-left corners together. Cells of Target
   --  that Source does not cover are left as they are.

   procedure Put
     (B    : in out Buffer;
      X, Y : Pixels;
      Text : String;
      S    : Style;
      Clip : Rect);
   --  Text on row Y starting at column X, one cell per character, left
   --  to right. Only the cells inside Clip (and the buffer) are written.
   --  Text is Latin-1: each Character is one cell.

   procedure Put_Wide
     (B    : in out Buffer;
      X, Y : Pixels;
      Text : Wide_Wide_String;
      S    : Style;
      Clip : Rect);
   --  Same, for any Unicode text.

   ---------------------------------------------------------------------
   --  Reading a frame as text, for tests and snapshots
   ---------------------------------------------------------------------

   function Row_Image (B : Buffer; Y : Pixels) return Wide_Wide_String
     with Pre => Y in 0 .. B.Height - 1;
   --  The characters of row Y. Styles are not shown.

   type Cursor_Style is
   (Default,
    Bar,
    Block);

   type Cursor_Info is record
      Visible : Boolean      := False;
      X       : Pixels       := 0;
      Y       : Pixels       := 0;
      Style   : Cursor_Style := Default;
   end record;

   function Cursor (B : Buffer) return Cursor_Info;

   procedure Set_Cursor_Style (B : in out Buffer; Style : Cursor_Style);

   procedure Set_Cursor
   (B          : in out Buffer;
    X, Y       : Pixels;
    Container  : Rect)
    with Pre =>
      In_Range (Container)
      and then X >= 0
      and then Y >= 0
      and then X < Container.Extent.Width
      and then Y < Container.Extent.Height;

private

   type Cell_Grid is array (Pixels range <>, Pixels range <>) of Cell;
   --  Indexed (row, column), both from 1: Ada does not allow
   --  "0 .. Height - 1" on a discriminant, so cell (X, Y) of the public
   --  interface is stored at (Y + 1, X + 1).

   type Buffer (Width : Column_Count; Height : Row_Count) is record
      Cells : Cell_Grid (1 .. Height, 1 .. Width);
      Cursor_Request : Cursor_Info;
      Cursor_Style_State : Cursor_Style := Default;
   end record;

   function Get (B : Buffer; X, Y : Pixels) return Cell is (B.Cells (Y + 1, X + 1));

end Thuja.Buffers;
