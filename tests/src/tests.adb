--  Unit tests. Plain Ada, no framework: each Check prints PASS/FAIL
--  and the program exits non-zero if anything failed. Add a test for
--  every behaviour you implement; CI runs this on every push.
--
--  None of these tests needs a terminal. Input is decoded from string
--  literals, frames are compared as text, and what the renderer would
--  send is compared byte for byte.
--
--  Todo lines document what the seed does not do yet. They never fail
--  the run. When one prints DONE, turn it into a Check.

with Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;

with Bedrock.Input;  use Bedrock.Input;
with Bedrock.Screen; use Bedrock.Screen;

with Thuja;          use Thuja;
with Thuja.Buffers;  use Thuja.Buffers;
with Thuja.Generic_Renderer;
with Thuja.Input;
with Thuja.Layout;   use Thuja.Layout;
with Thuja.Styles;   use Thuja.Styles;
with Thuja.UTF8;
with Thuja.Widgets.Blocks;
with Thuja.Widgets.Gauges;
with Thuja.Widgets.Generic_Lists;
with Thuja.Widgets.Text_Fields;
with Thuja.Widgets.Labels;

procedure Tests is

   Failures : Natural := 0;
   Pending  : Natural := 0;

   procedure Check (Name : String; Condition : Boolean) is
   begin
      if Condition then
         Put_Line ("PASS  " & Name);
      else
         Put_Line ("FAIL  " & Name);
         Failures := Failures + 1;
      end if;
   end Check;

   procedure Todo (Name : String; Condition : Boolean) is
   begin
      if Condition then
         Put_Line ("DONE  " & Name & "   (make it a Check)");
      else
         Put_Line ("TODO  " & Name);
         Pending := Pending + 1;
      end if;
   end Todo;

   ESC : constant Character := Character'Val (16#1B#);

   ---------------------------------------------------------------------
   --  Helpers
   ---------------------------------------------------------------------

   --  A row of a frame as plain ASCII, so expected results can be
   --  written as ordinary string literals:
   --    border lines '-' and '|', corners '+', gauge '#' and '.'.
   function Row (B : Buffer; Y : Pixels) return String is
      Wide   : constant Wide_Wide_String := Row_Image (B, Y);
      Result : String (Wide'Range);
   begin
      for I in Wide'Range loop
         Result (I) :=
           (case Wide_Wide_Character'Pos (Wide (I)) is
               when 16#2500# => '-',
               when 16#2502# => '|',
               when 16#250C# | 16#2510# | 16#2514# | 16#2518# => '+',
               when 16#2588# => '#',
               when 16#2591# => '.',
               when 0 .. 127 => Character'Val (Wide_Wide_Character'Pos (Wide (I))),
               when others   => '?');
      end loop;

      return Result;
   end Row;

   --  Everything the decoder produces for Bytes, then for a Flush.
   type Event_List is array (Positive range <>) of Event;

   function Decode (Bytes : String) return Event_List is
      D      : Thuja.Input.Decoder;
      E      : Event;
      Result : Event_List (1 .. Bytes'Length + 1);
      Last   : Natural := 0;
   begin
      for Byte of Bytes loop
         Thuja.Input.Feed (D, Byte, E);

         if E.Kind /= None then
            Last := Last + 1;
            Result (Last) := E;
         end if;
      end loop;

      Thuja.Input.Flush (D, E);

      if E.Kind /= None then
         Last := Last + 1;
         Result (Last) := E;
      end if;

      return Result (1 .. Last);
   end Decode;

   function Is_Key (E : Event; K : Key; Mods : Modifiers := No_Modifiers) return Boolean is
     (E.Kind = Key_Down and then E.Key = K and then E.Mods = Mods);

   function Is_Text (E : Event; Text : String) return Boolean is
     (E.Kind = Text_Input and then E.Length = Text'Length
      and then E.Text (1 .. E.Length) = Text);

   --  The renderer, writing into a string.
   Sent : Unbounded_String;

   procedure Collect (Bytes : String) is
   begin
      Append (Sent, Bytes);
   end Collect;

   package Renderer is new Thuja.Generic_Renderer (Emit => Collect);

   ---------------------------------------------------------------------
   --  Geometry
   ---------------------------------------------------------------------

   procedure Test_Geometry is
      A : constant Rect := Make (0, 0, 10, 5);
      B : constant Rect := Make (8, 3, 10, 10);
   begin
      Check ("Right",                 Right (A) = 10);
      Check ("Bottom",                Bottom (A) = 5);
      Check ("Intersection",          Intersection (A, B) = Make (8, 3, 2, 2));
      Check ("Intersection, apart",   Is_Empty (Intersection (A, Make (20, 20, 5, 5))));
      Check ("Inset",                 Inset (A, 1) = Make (1, 1, 8, 3));
      Check ("Inset, too small",      Is_Empty (Inset (A, 3)));
      Check ("Inside",                Inside (Make (1, 1, 2, 2), A));
      Check ("not Inside",            not Inside (B, A));
      Check ("empty is Inside",       Inside (Make (99, 99, 0, 0), A));
   end Test_Geometry;

   ---------------------------------------------------------------------
   --  Buffers
   ---------------------------------------------------------------------

   procedure Test_Buffers is
      B : Buffer (8, 2);
   begin
      Check ("new buffer is blank",   Row (B, 0) = "        ");

      Put (B, 2, 0, "abc", Plain, Clip => Area (B));
      Check ("Put",                   Row (B, 0) = "  abc   ");

      Put (B, 6, 1, "wxyz", Plain, Clip => Area (B));
      Check ("Put clips at the right edge", Row (B, 1) = "      wx");

      Put (B, -2, 0, "12345", Plain, Clip => Area (B));
      Check ("Put clips at the left edge",  Row (B, 0) = "345bc   ");

      Put (B, 0, 1, "hidden", Plain, Clip => Make (1, 1, 3, 1));
      Check ("Put clips to Clip",     Row (B, 1) = " idd  wx");

      Put (B, 0, 5, "nowhere", Plain, Clip => Area (B));
      Set (B, 100, 100, ('!', Plain));
      Check ("drawing outside is ignored", Row (B, 0) = "345bc   ");

      Fill (B, Make (6, 0, 50, 50), ('.', Plain));
      Check ("Fill clips",            Row (B, 0) = "345bc .." and then Row (B, 1) = " idd  ..");

      Clear (B);
      Check ("Clear",                 Row (B, 0) = "        ");

      Check ("UTF-8, 1 byte",         Thuja.UTF8.Encode ('A') = "A");
      Check ("UTF-8, 2 bytes",
             Thuja.UTF8.Encode (Wide_Wide_Character'Val (16#E9#))
             = Character'Val (16#C3#) & Character'Val (16#A9#));
      Check ("UTF-8, 3 bytes",
             Thuja.UTF8.Encode (Wide_Wide_Character'Val (16#2500#))
             = Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#80#));
   end Test_Buffers;

   ---------------------------------------------------------------------
   --  Layout
   ---------------------------------------------------------------------

   procedure Test_Layout is
      Area : constant Rect := Make (0, 0, 80, 24);
      Rows : constant Rect_Array := Split (Area, Column, [Fixed (3), Flex, Fixed (1)]);
      Cols : constant Rect_Array := Split (Rows (2), Row, [Flex (1), Flex (3)], Gap => 2);
      Tiny : constant Rect_Array :=
        Split (Make (0, 0, 80, 4), Column, [Fixed (3), Flex, Fixed (3)]);
   begin
      Check ("fixed, first",          Rows (1) = Make (0, 0, 80, 3));
      Check ("flex takes the rest",   Rows (2) = Make (0, 3, 80, 20));
      Check ("fixed, last",           Rows (3) = Make (0, 23, 80, 1));
      Check ("weights share 1 to 3",  Cols (1).Extent.Width = 19 and then Cols (2).Extent.Width = 59);
      Check ("gap between items",     Cols (2).Origin.X = 21);
      Check ("no cell left over",     Right (Cols (2)) = 80);
      Check ("too small: stays inside",
             (for all R of Tiny => Inside (R, Make (0, 0, 80, 4))));
      Check ("too small: last items shrink",
             Tiny (2).Extent.Height = 0 and then Tiny (3).Extent.Height = 1);
   end Test_Layout;

   ---------------------------------------------------------------------
   --  Input
   ---------------------------------------------------------------------

   procedure Test_Input is
      Ctrl : constant Modifiers := (Ctrl => True, others => False);
      Alt  : constant Modifiers := (Alt => True, others => False);

      Text      : constant Event_List := Decode ("hi");
      Up        : constant Event_List := Decode (ESC & "[A");
      Mixed     : constant Event_List := Decode ("a" & ESC & "[Db");
      Lone      : constant Event_List := Decode ([1 => ESC]);
      Twice     : constant Event_List := Decode ([ESC, ESC]);
      Interrupt : constant Event_List := Decode ([1 => Character'Val (3)]);
      Alt_X     : constant Event_List := Decode (ESC & "x");
      Unknown   : constant Event_List := Decode (ESC & "[1;2;3;4z" & "k");
      Endless   : constant Event_List := Decode (ESC & "[" & [1 .. 500 => '9'] & "x");

      Accent    : constant Event_List := Decode (Character'Val (16#C3#) & Character'Val (16#A9#));
      Delete    : constant Event_List := Decode (ESC & "[3~");
      Ctrl_Right : constant Event_List := Decode (ESC & "[1;5C");
      F1        : constant Event_List := Decode (ESC & "OP");
      F5        : constant Event_List := Decode (ESC & "[15~");
      Click     : constant Event_List := Decode (ESC & "[<0;10;5M");
   begin
      Check ("text",                  Text'Length = 2 and then Is_Text (Text (1), "h")
                                      and then Is_Text (Text (2), "i"));
      Check ("Enter",                 Is_Key (Decode ([1 => ASCII.CR]) (1), Key_Return));
      Check ("Tab",                   Is_Key (Decode ([1 => ASCII.HT]) (1), Key_Tab));
      Check ("Backspace",             Is_Key (Decode ([1 => ASCII.DEL]) (1), Key_Backspace));
      Check ("arrow",                 Up'Length = 1 and then Is_Key (Up (1), Key_Up));
      Check ("text, arrow, text",     Mixed'Length = 3 and then Is_Text (Mixed (1), "a")
                                      and then Is_Key (Mixed (2), Key_Left)
                                      and then Is_Text (Mixed (3), "b"));
      Check ("lone ESC is Escape, after Flush",
             Lone'Length = 1 and then Is_Key (Lone (1), Key_Escape));
      Check ("ESC ESC is Escape twice",
             Twice'Length = 2 and then Is_Key (Twice (2), Key_Escape));
      Check ("Ctrl + C",              Interrupt'Length = 1 and then Is_Key (Interrupt (1), Key_C, Ctrl));
      Check ("Alt + x",               Alt_X'Length = 1 and then Is_Key (Alt_X (1), Key_X, Alt));
      Check ("unknown sequence is dropped whole, not leaked as text",
             Unknown'Length = 1 and then Is_Text (Unknown (1), "k"));
      Check ("endless sequence is abandoned",
             Endless'Length > 0 and then Endless'Length <= 500);

      Check ("UTF-8 text: e acute is one Text_Input of 2 bytes",
            Accent'Length = 1 and then Accent (1).Kind = Text_Input
            and then Accent (1).Length = 2);
      Todo ("Delete (CSI 3 ~)",
            Delete'Length = 1 and then Is_Key (Delete (1), Key_Delete));
      Todo ("Ctrl + Right (CSI 1;5 C)",
            Ctrl_Right'Length = 1 and then Is_Key (Ctrl_Right (1), Key_Right, Ctrl));
      Check ("F1 (SS3 P)",
            F1'Length = 1 and then Is_Key (F1 (1), Key_F1));
      Todo ("F5 (CSI 15 ~)",
            F5'Length = 1 and then Is_Key (F5 (1), Key_F5));
      Todo ("mouse click (SGR 1006)",
            Click'Length = 1 and then Click (1).Kind = Mouse_Down);
   end Test_Input;

   ---------------------------------------------------------------------
   --  Renderer
   ---------------------------------------------------------------------

   procedure Test_Renderer is
      Reset  : constant String := ESC & "[0m";
      Erase  : constant String := ESC & "[2J";
      Red    : constant Style  := Colored ((255, 0, 0, 255));
      Blue   : constant Style  := Colored ((0, 0, 255, 255));
      Before : Buffer (10, 3);
      After  : Buffer (10, 3);
      Typed  : Buffer (10, 3);
      Gaps   : Buffer (10, 3);
      Styles : Buffer (10, 3);
   begin
      Sent := Null_Unbounded_String;
      Renderer.Diff (Before, After);
      Check ("no change, no bytes",   Length (Sent) = 0);

      Set (After, 2, 1, ('A', Plain));
      Sent := Null_Unbounded_String;
      Renderer.Diff (Before, After);
      Check ("one cell: move, style, character",
             To_String (Sent) = ESC & "[2;3H" & Reset & "A" & Reset);

      Set (After, 2, 1, ('A', Bold (Colored ((255, 0, 128, 255)))));
      Sent := Null_Unbounded_String;
      Renderer.Diff (Before, After);
      Check ("style: bold, 24-bit foreground",
             To_String (Sent) = ESC & "[2;3H" & ESC & "[0;1;38;2;255;0;128m" & "A" & Reset);

      Set (After, 2, 1, (Wide_Wide_Character'Val (16#1B#), Plain));
      Sent := Null_Unbounded_String;
      Renderer.Diff (Before, After);
      Check ("a control character in a cell never reaches the terminal",
             To_String (Sent) = ESC & "[2;3H" & Reset & " " & Reset);

      Sent := Null_Unbounded_String;
      Renderer.Full (Before);
      Check ("full frame of a blank buffer: clear only",
             To_String (Sent) = Reset & Erase & Reset);

      Put (Typed, 0, 0, "hello", Plain, Clip => Area (Typed));
      Sent := Null_Unbounded_String;
      Renderer.Diff (Before, Typed);
      Put_Line
        ("      (five adjacent characters cost"
         & Length (Sent)'Image & " bytes)");
      Check ("five adjacent characters cost under 20 bytes",
             Length (Sent) < 20);
      Check ("adjacent characters skip redundant Move_To and Style",
             To_String (Sent) = ESC & "[1;1H" & Reset & "hello" & Reset);

      --  Non-adjacent cells on same row and next row must emit Move_To
      Set (Gaps, 0, 0, ('A', Plain));
      Set (Gaps, 3, 0, ('B', Plain));
      Set (Gaps, 0, 1, ('C', Plain));
      Sent := Null_Unbounded_String;
      Renderer.Diff (Before, Gaps);
      Check ("non-adjacent cells emit Move_To on gaps and row wraps",
             To_String (Sent) = ESC & "[1;1H" & Reset & "A" & ESC & "[1;4H" & "B" & ESC & "[2;1H" & "C" & Reset);

      --  Style caching: Red -> Red skips style, Red -> Blue emits new style
      Set (Styles, 0, 0, ('A', Red));
      Set (Styles, 1, 0, ('B', Red));
      Set (Styles, 2, 0, ('C', Blue));
      Sent := Null_Unbounded_String;
      Renderer.Diff (Before, Styles);
      Check ("identical adjacent styles are cached, changes emit SGR",
             To_String (Sent) = ESC & "[1;1H" & ESC & "[0;38;2;255;0;0m" & "AB" & ESC & "[0;38;2;0;0;255m" & "C" & Reset);

      --  Full render uses the same Render_Cell state tracking
      Sent := Null_Unbounded_String;
      Renderer.Full (Typed);
      Check ("full frame caches cursor and style across adjacent cells",
             To_String (Sent) = Reset & Erase & ESC & "[1;1H" & Reset & "hello" & Reset);
   end Test_Renderer;

   ---------------------------------------------------------------------
   --  Widgets: frames compared as text
   ---------------------------------------------------------------------

   function Fruit_Count return Natural is (5);

   function Fruit (Index : Positive) return String is
     (case Index is
         when 1 => "apple",
         when 2 => "banana",
         when 3 => "cherry",
         when 4 => "damson",
         when others => "elder");

   package Fruit_Lists is new Thuja.Widgets.Generic_Lists (Fruit_Count, Fruit);

   procedure Test_Widgets is
      package Blocks renames Thuja.Widgets.Blocks;
      package Gauges renames Thuja.Widgets.Gauges;
      package Labels renames Thuja.Widgets.Labels;

      B     : Buffer (16, 5);
      Small : Buffer (16, 5);
      List  : Fruit_Lists.State;
      Used  : Boolean;
   begin
      Blocks.Draw (B, Area (B), "Box");
      Labels.Draw (B, Blocks.Inner (Area (B)), "left");
      Labels.Draw (B, Make (1, 2, 14, 1), "mid", Align => Labels.Center);
      Gauges.Draw (B, Make (1, 3, 14, 1), 50);

      Check ("block, row 0",          Row (B, 0) = "+- Box --------+");
      Check ("label, left",           Row (B, 1) = "|left          |");
      Check ("label, centered",       Row (B, 2) = "|     mid      |");
      Check ("gauge at 50%",          Row (B, 3) = "|#######.......|");
      Check ("block, last row",       Row (B, 4) = "+--------------+");

      --  A widget given no room draws nothing and does not raise.
      Blocks.Draw (Small, Make (0, 0, 1, 1), "Box");
      Labels.Draw (Small, Make (3, 3, 0, 0), "text");
      Gauges.Draw (Small, Make (40, 40, 5, 1), 100);
      Check ("no room: nothing drawn, nothing raised", Row (Small, 0) = "                ");

      --  The list: three rows visible out of five.
      Clear (Small);
      Fruit_Lists.Draw (Small, Make (0, 0, 8, 3), List);
      Check ("list, top",             Row (Small, 0) (1 .. 8) = " apple  "
                                      and then Row (Small, 2) (1 .. 8) = " cherry ");
      Check ("list, selection is highlighted",
             Get (Small, 0, 0).Style.Attr.Inverse and then not Get (Small, 0, 1).Style.Attr.Inverse);

      for Step in 1 .. 3 loop
         Fruit_Lists.Handle (List, Key_Event (Key_Down, Down => True), Used);
      end loop;

      Check ("list, Down is used",    Used and then List.Selected = 4);

      Fruit_Lists.Handle (List, Key_Event (Key_A, Down => True), Used);
      Check ("list, other keys are not used", not Used);

      Clear (Small);
      Fruit_Lists.Draw (Small, Make (0, 0, 8, 3), List);
      Check ("list scrolls to keep the selection visible",
             Row (Small, 0) (1 .. 8) = " banana " and then Row (Small, 2) (1 .. 8) = " damson ");

      for Step in 1 .. 10 loop
         Fruit_Lists.Handle (List, Key_Event (Key_Down, Down => True), Used);
      end loop;

      Check ("list stops at the last row", List.Selected = 5);
   end Test_Widgets;

---------------------------------------------------------------------
--  Text Input Widget: Tests
---------------------------------------------------------------------

procedure Test_Text_Fields is
   package Text_Field renames Thuja.Widgets.Text_Fields;
   use Text_Field.Input_Strings;
   S    : Text_Field.State;
   Used : Boolean;
   TestText : Bounded_String := To_Bounded_String ("ABCDEFG");
   LetterD : constant Event_List := Decode ("D");
begin
   for E of Decode(To_String (TestText)) loop
      Text_Field.Handle(S, E, Used);
   end loop;

   Check ("Confirm Typed text matches", S.Text = TestText);

   TestText := To_Bounded_String ("ABC");

   Text_Field.Set_Text(S, To_String (TestText));

   Check ("Confirm Set Text worked", S.Text = TestText);

   --  Move left twice
   Text_Field.Handle(S, Key_Event (Key_Left, Down => True), Used);
   Text_Field.Handle(S, Key_Event (Key_Left, Down => True), Used);

   -- Type a letter D
   Text_Field.Handle (S, LetterD (LetterD'First), Used);
   -- Confirm it inserted it at the proper point
   Check ("Confirm Moving and insert worked", S.Text = To_Bounded_String ("ADBC"));

   -- Check making sure right does not crash the program
   for E in 1 .. 100 loop
      --  Move right
      Text_Field.Handle(S, Key_Event (Key_Right, Down => True), Used);
   end loop;

   -- Type another Letter D
   Text_Field.Handle (S, LetterD (LetterD'First), Used);
   -- Confirm it inserted it at the proper point
   Check ("Confirm Moving right and still adds it at the end", S.Text = To_Bounded_String ("ADBCD"));

   --  Move left once
   Text_Field.Handle(S, Key_Event (Key_Left, Down => True), Used);
   --  Check making sure backspace removes everything but the remaining letter
   for E in 1 .. 100 loop
      --  Backspace
      Text_Field.Handle(S, Key_Event (Key_Backspace, Down => True), Used);
   end loop;

   Check ("Confirm backspace is working", S.Text = "D");

   --  Delete word before cursor
   Text_Field.Set_Text (S, "One.  two   three");
   -- Move to position 11
   Text_Field.Handle (S, Key_Event (Key_Home, Down => True), Used);
   for I in 1 .. 14 loop
      Text_Field.Handle (S, Key_Event (Key_Right, Down => True), Used);
   end loop;

   Text_Field.Handle (S,
      Key_Event (Key_W, Down => True,
               Mods => (Ctrl => True, others => False)),
      Used);

   Check ("Delete previous word", S.Text = "One.  two   ree");
end Test_Text_Fields;

begin
   Test_Geometry;
   Test_Buffers;
   Test_Layout;
   Test_Input;
   Test_Renderer;
   Test_Widgets;
   Test_Text_Fields;

   New_Line;
   Put_Line (Failures'Image & " failed," & Pending'Image & " still to do");

   if Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
