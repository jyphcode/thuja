--  The acceptance test, and the smallest complete thuja application.
--
--     showcase              run it in your terminal
--     showcase --snapshot   print one 80 x 24 frame as text and exit
--                           (no terminal needed: what CI runs)
--
--  Read this file first. It is the whole pattern on one page:
--
--     State   what the application knows                 (a record)
--     Draw    State -> a frame of cells                  (no I/O)
--     Update  State + one event -> State                 (no I/O)
--     the loop: Draw, Present, Poll, Update
--
--  Draw and Update never touch the terminal, which is why --snapshot
--  and the tests can run them anywhere.

with Ada.Command_Line;
with Ada.Text_IO;

with Bedrock.Colors;
with Bedrock.Input;  use Bedrock.Input;
with Bedrock.Screen; use Bedrock.Screen;

with Thuja;          use Thuja;
with Thuja.Buffers;  use Thuja.Buffers;
with Thuja.Layout;   use Thuja.Layout;
with Thuja.Styles;   use Thuja.Styles;
with Thuja.Terminal;
with Thuja.UTF8;
with Thuja.Widgets.Blocks;
with Thuja.Widgets.Gauges;
with Thuja.Widgets.Generic_Lists;
with Thuja.Widgets.Labels;

with Demo.Keyboard;
with Demo.Placeholder;

procedure Showcase is

   package Blocks renames Thuja.Widgets.Blocks;
   package Gauges renames Thuja.Widgets.Gauges;
   package Labels renames Thuja.Widgets.Labels;

   ---------------------------------------------------------------------
   --  The demos of the first thuja, the ones to rebuild on this core.
   --  One table entry per page; the sidebar lists them in this order.
   ---------------------------------------------------------------------

   type Page is (HTop, Text_Editor, Flexbox, Sort_Visual, Sine_Wave, Keyboard);

   type Demo_Access is not null access all Demo.Instance'Class;

   HTop_Demo        : aliased Demo.Placeholder.State := Demo.Placeholder.Make ("HTop");
   Text_Editor_Demo : aliased Demo.Placeholder.State := Demo.Placeholder.Make ("Text Editor");
   Flexbox_Demo     : aliased Demo.Placeholder.State := Demo.Placeholder.Make ("Flexbox");
   Sort_Visual_Demo : aliased Demo.Placeholder.State := Demo.Placeholder.Make ("Sort Visual");
   Sine_Wave_Demo   : aliased Demo.Placeholder.State := Demo.Placeholder.Make ("Sine Wave");
   Keyboard_Demo    : aliased Demo.Keyboard.State;

   Demos : constant array (Page) of Demo_Access :=
     [HTop        => HTop_Demo'Access,
      Text_Editor => Text_Editor_Demo'Access,
      Flexbox     => Flexbox_Demo'Access,
      Sort_Visual => Sort_Visual_Demo'Access,
      Sine_Wave   => Sine_Wave_Demo'Access,
      Keyboard    => Keyboard_Demo'Access];

   function Demo_Count return Natural is (Demos'Length);

   function Demo_Name (Index : Positive) return String is
     (Demos (Page'Val (Index - 1)).Name);

   package Demo_Lists is new Thuja.Widgets.Generic_Lists
     (Count => Demo_Count, Text => Demo_Name);

   ---------------------------------------------------------------------
   --  State
   ---------------------------------------------------------------------

   type Focus is (Sidebar, Main);

   type App_State is record
      Demos      : Demo_Lists.State;
      Focused    : Focus   := Sidebar;
      Frames     : Natural := 0;
      Bytes      : Natural := 0;    --  sent to the terminal by the last frame
      Quit       : Boolean := False;
   end record;

   Accent : constant Style := Bold (Colored (Bedrock.Colors.Sky_Blue));
   Faint  : constant Style := Dim (Plain);

   function Image (N : Natural) return String;
   function Current (State : App_State) return Demo_Access;

   procedure Draw (Frame : in out Buffer; State : in out App_State);
   procedure Update (State : in out App_State; E : Event);
   procedure Print (Frame : Buffer);

   -----------
   -- Image --
   -----------

   function Image (N : Natural) return String is
      Text : constant String := N'Image;
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   -------------
   -- Current --
   -------------

   function Current (State : App_State) return Demo_Access is
     (Demos (Page'Val (State.Demos.Selected - 1)));

   ----------
   -- Draw --
   ----------

   procedure Draw (Frame : in out Buffer; State : in out App_State) is

      --  All placement comes from Split: three bands, the middle one
      --  takes what is left; the middle band is cut in two columns.
      Bands : constant Rect_Array :=
        Split (Area (Frame), Column, [Fixed (3), Flex, Fixed (3)]);
      Header : Rect renames Bands (1);
      Footer : Rect renames Bands (3);

      Panes : constant Rect_Array := Split (Bands (2), Row, [Fixed (24), Flex]);

      Status : constant Rect_Array :=
        Split (Blocks.Inner (Footer), Row, [Flex, Fixed (34)], Gap => 2);

   begin
      Blocks.Draw (Frame, Header, "thuja");
      Labels.Draw (Frame, Blocks.Inner (Header), "A terminal user interface library in Ada");
      Labels.Draw
        (Frame, Blocks.Inner (Header),
         Image (Natural (Frame.Width)) & " x " & Image (Natural (Frame.Height)),
         Faint, Labels.Right);

      Blocks.Draw
        (Frame, Panes (1), "Demos to rebuild",
         Demo.Border (State.Focused = Sidebar));
      Demo_Lists.Draw (Frame, Blocks.Inner (Panes (1)), State.Demos);

      Current (State).Draw (Frame, Panes (2), Focused => State.Focused = Main);

      Blocks.Draw (Frame, Footer, "q quits");
      Gauges.Draw (Frame, Status (1), State.Frames mod 101, Accent);
      Labels.Draw
        (Frame, Status (2),
         "frame " & Image (State.Frames) & ", last sent " & Image (State.Bytes) & " bytes",
         Faint, Labels.Right);
   end Draw;

   ------------
   -- Update --
   ------------

   procedure Update (State : in out App_State; E : Event) is
      Used : Boolean;
   begin
      if E.Kind = None then
         return;
      end if;

      if E.Kind = Quit
        or else (E.Kind = Text_Input and then E.Text (1) = 'q'
                 and then State.Focused = Sidebar)
        or else (E.Kind = Key_Down and then E.Key = Key_Escape
                 and then State.Focused = Sidebar)
        or else (E.Kind = Key_Down and then E.Key = Key_C and then E.Mods.Ctrl)
      then
         State.Quit := True;
         return;
      end if;

      if E.Kind = Key_Down and then E.Key = Key_Tab then
         State.Focused := (if State.Focused = Sidebar then Main else Sidebar);
         return;
      end if;

      case State.Focused is
         when Sidebar => Demo_Lists.Handle (State.Demos, E, Used);
         when Main    => Current (State).Update (E, Used);
      end case;
   end Update;

   -----------
   -- Print --
   -----------

   procedure Print (Frame : Buffer) is
   begin
      for Y in 0 .. Frame.Height - 1 loop
         for C of Row_Image (Frame, Y) loop
            Ada.Text_IO.Put (Thuja.UTF8.Encode (C));
         end loop;

         Ada.Text_IO.New_Line;
      end loop;
   end Print;

   State : App_State;

begin
   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--snapshot"
   then
      declare
         Frame : Buffer (80, 24);
      begin
         Update (State, Key_Event (Key_Down, Down => True));
         Update (State, Key_Event (Key_End, Down => True));
         Update (State, Key_Event (Key_Tab, Down => True));
         Update (State, Key_Event (Key_End, Down => True));
         Draw (Frame, State);
         Print (Frame);
      end;

      return;
   end if;

   declare
      Term : Thuja.Terminal.Session;
      E    : Event;
   begin
      Term.Open;

      while not State.Quit loop
         declare
            Now   : constant Size := Term.Size;
            Frame : Buffer (Now.Width, Now.Height);
         begin
            Draw (Frame, State);
            Term.Present (Frame);
         end;

         State.Frames := State.Frames + 1;
         State.Bytes := Term.Bytes_Presented;

         Term.Poll (Timeout => 0.1, E => E);
         Update (State, E);
      end loop;

      Term.Close;
   end;

exception
   when Thuja.Terminal.Not_A_Terminal =>
      Ada.Text_IO.Put_Line ("showcase needs an interactive terminal.");
      Ada.Text_IO.Put_Line ("Without one, try: showcase --snapshot");
      Ada.Command_Line.Set_Exit_Status (1);
end Showcase;
