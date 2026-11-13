with Ada.Strings.Fixed;
with GNAT.Expect;
with GNAT.OS_Lib;

with Thuja.Layout; use Thuja.Layout;
with Thuja.Widgets.Blocks;
with Thuja.Widgets.Gauges;
with Thuja.Widgets.Labels;

package body Demo.HTop is

   package Blocks renames Thuja.Widgets.Blocks;
   package Gauges renames Thuja.Widgets.Gauges;
   package Labels renames Thuja.Widgets.Labels;

   Green  : constant Style := Colored (Bedrock.Colors.Green);
   Yellow : constant Style := Colored (Bedrock.Colors.Yellow);
   Red    : constant Style := Colored (Bedrock.Colors.Red);
   Header : constant Style := Inverse (Bold (Plain));
   Faint  : constant Style := Dim (Plain);

   --  showcase.adb polls every 0.1s (10 FPS).
   --  Refresh_Interval = 10 refreshes live OS processes once per second
   --  (set to 5 for 500ms / twice per second).
   Refresh_Interval : constant := 10;

   Max_Procs : constant := 40;
   Row_Width : constant := 64;

   subtype Row_String is String (1 .. Row_Width);

   Rows      : array (1 .. Max_Procs) of Row_String :=
     [others => [others => ' ']];
   Row_Count : Natural := 0;

   Header_Text : constant Row_String :=
     "   PID USER         %CPU   %MEM       TIME COMMAND              ";

   Is_Windows : constant Boolean := (GNAT.OS_Lib.Directory_Separator = '\');

   function Image (N : Natural) return String;
   function Level_Color (Value : Gauges.Percent) return Style;
   function Parse_Whole (S : String) return Natural;
   function Pad_Left (S : String; Width : Positive) return String;
   function Pad_Right (S : String; Width : Positive) return String;
   procedure Format_PS_Line
     (Raw     : String;
      Row_Out : out Row_String;
      CPU_Val : out Natural;
      Mem_Val : out Natural);
   function Format_Tasklist_Line (Raw : String) return Row_String;
   procedure Refresh_Processes (D : in out State);
   procedure Draw_Meter
     (Frame : in out Buffer;
      Area  : Rect;
      Label : String;
      Value : Gauges.Percent);

   -----------
   -- Image --
   -----------

   function Image (N : Natural) return String is
      Text : constant String := N'Image;
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   -----------------
   -- Level_Color --
   -----------------

   function Level_Color (Value : Gauges.Percent) return Style is
   begin
      if Value < 50 then
         return Green;
      elsif Value < 80 then
         return Yellow;
      else
         return Red;
      end if;
   end Level_Color;

   -----------------
   -- Parse_Whole --
   -----------------

   function Parse_Whole (S : String) return Natural is
      Acc : Natural := 0;
   begin
      for C of S loop
         exit when C = '.';
         if C in '0' .. '9' then
            Acc := Acc * 10 + (Character'Pos (C) - Character'Pos ('0'));
         end if;
      end loop;
      return Acc;
   end Parse_Whole;

   --------------
   -- Pad_Left --
   --------------

   function Pad_Left (S : String; Width : Positive) return String is
      Result : String (1 .. Width) := [others => ' '];
   begin
      if S'Length >= Width then
         Result := S (S'First .. S'First + Width - 1);
      elsif S'Length > 0 then
         Result (Width - S'Length + 1 .. Width) := S;
      end if;

      return Result;
   end Pad_Left;

   ---------------
   -- Pad_Right --
   ---------------

   function Pad_Right (S : String; Width : Positive) return String is
      Result : String (1 .. Width) := [others => ' '];
   begin
      if S'Length >= Width then
         Result := S (S'First .. S'First + Width - 1);
      elsif S'Length > 0 then
         Result (1 .. S'Length) := S;
      end if;

      return Result;
   end Pad_Right;

   --------------------
   -- Format_PS_Line --
   --------------------

   procedure Format_PS_Line
     (Raw     : String;
      Row_Out : out Row_String;
      CPU_Val : out Natural;
      Mem_Val : out Natural)
   is
      Clean : String (Raw'Range);
      Pos   : Positive := Clean'First;

      procedure Next_Token (First : out Positive; Last : out Natural) is
      begin
         while Pos <= Clean'Last and then Clean (Pos) <= ' ' loop
            Pos := Pos + 1;
         end loop;
         First := Pos;
         while Pos <= Clean'Last and then Clean (Pos) > ' ' loop
            Pos := Pos + 1;
         end loop;
         Last := Pos - 1;
      end Next_Token;

      F1, F2, F3, F4, F5 : Positive := Clean'First;
      L1, L2, L3, L4, L5 : Natural  := 0;
   begin
      for I in Raw'Range loop
         Clean (I) :=
           (if Raw (I) >= ' ' and then Raw (I) <= '~' then Raw (I) else ' ');
      end loop;

      Next_Token (F1, L1); --  PID
      Next_Token (F2, L2); --  USER
      Next_Token (F3, L3); --  %CPU
      Next_Token (F4, L4); --  %MEM
      Next_Token (F5, L5); --  TIME

      while Pos <= Clean'Last and then Clean (Pos) <= ' ' loop
         Pos := Pos + 1;
      end loop;

      declare
         PID_S  : constant String := (if L1 >= F1 then Clean (F1 .. L1) else "");
         User_S : constant String := (if L2 >= F2 then Clean (F2 .. L2) else "");
         CPU_S  : constant String := (if L3 >= F3 then Clean (F3 .. L3) else "");
         Mem_S  : constant String := (if L4 >= F4 then Clean (F4 .. L4) else "");
         Time_S : constant String := (if L5 >= F5 then Clean (F5 .. L5) else "");
         Rest   : constant String :=
           (if Pos <= Clean'Last then Clean (Pos .. Clean'Last) else "");
         Slash  : constant Natural :=
           Ada.Strings.Fixed.Index (Rest, "/", Ada.Strings.Backward);
         Cmd_S  : constant String :=
           (if Slash > 0 and then Slash < Rest'Last
            then Rest (Slash + 1 .. Rest'Last)
            else Rest);
      begin
         CPU_Val := Parse_Whole (CPU_S);
         Mem_Val := Parse_Whole (Mem_S);

         Row_Out := Pad_Left (PID_S, 6) & " "
           & Pad_Right (User_S, 10) & " "
           & Pad_Left (CPU_S, 6) & " "
           & Pad_Left (Mem_S, 6) & " "
           & Pad_Left (Time_S, 10) & " "
           & Pad_Right (Cmd_S, 21);
      end;
   end Format_PS_Line;

   --------------------------
   -- Format_Tasklist_Line --
   --------------------------

   function Format_Tasklist_Line (Raw : String) return Row_String is
      Clean : String (Raw'Range);
      Pos   : Positive := Clean'First;

      procedure Next_CSV_Field (First : out Positive; Last : out Natural) is
      begin
         while Pos <= Clean'Last and then Clean (Pos) /= '"' loop
            Pos := Pos + 1;
         end loop;
         if Pos <= Clean'Last then
            Pos := Pos + 1;
         end if;
         First := Pos;
         while Pos <= Clean'Last and then Clean (Pos) /= '"' loop
            Pos := Pos + 1;
         end loop;
         Last := Pos - 1;
         if Pos <= Clean'Last then
            Pos := Pos + 1;
         end if;
      end Next_CSV_Field;

      F1, F2, F3, F4, F5 : Positive := Clean'First;
      L1, L2, L3, L4, L5 : Natural  := 0;
   begin
      for I in Raw'Range loop
         Clean (I) :=
           (if Raw (I) >= ' ' and then Raw (I) <= '~' then Raw (I) else ' ');
      end loop;

      Next_CSV_Field (F1, L1);
      Next_CSV_Field (F2, L2);
      Next_CSV_Field (F3, L3);
      Next_CSV_Field (F4, L4);
      Next_CSV_Field (F5, L5);

      declare
         Cmd_S  : constant String := (if L1 >= F1 then Clean (F1 .. L1) else "");
         PID_S  : constant String := (if L2 >= F2 then Clean (F2 .. L2) else "");
         User_S : constant String := (if L3 >= F3 then Clean (F3 .. L3) else "");
         Mem_S  : constant String := (if L5 >= F5 then Clean (F5 .. L5) else "");
      begin
         return Pad_Left (PID_S, 6) & " "
           & Pad_Right (User_S, 10) & " "
           & Pad_Left ("0.0", 6) & " "
           & Pad_Left (Mem_S, 6) & " "
           & Pad_Left ("00:00.00", 10) & " "
           & Pad_Right (Cmd_S, 21);
      end;
   end Format_Tasklist_Line;

   -----------------------
   -- Refresh_Processes --
   -----------------------

   procedure Refresh_Processes (D : in out State) is
      use GNAT.OS_Lib;
      Sort_Flag : constant String := (if D.Sort_By_Mem then "-m" else "-r");
      Args : Argument_List :=
        (if Is_Windows
         then [new String'("/FO"), new String'("CSV"), new String'("/NH")]
         else [new String'("-eo"),
               new String'("pid,user,pcpu,pmem,time,comm"),
               new String'(Sort_Flag)]);
      Cmd      : constant String := (if Is_Windows then "tasklist" else "ps");
      Status   : aliased Integer := 0;
      CPU_Sum  : Natural := 0;
      Mem_Sum  : Natural := 0;
   begin
      declare
         Output : constant String :=
           GNAT.Expect.Get_Command_Output
             (Command    => Cmd,
              Arguments  => Args,
              Input      => "",
              Status     => Status'Access,
              Err_To_Out => True);
         First  : Positive := Output'First;
         Line   : Natural  := 0;
      begin
         for A of Args loop
            Free (A);
         end loop;

         Row_Count := 0;

         for I in Output'Range loop
            if Output (I) = ASCII.LF then
               Line := Line + 1;

               if (Is_Windows or else Line > 1)
                 and then I > First
                 and then Row_Count < Max_Procs
               then
                  declare
                     Raw_Line : constant String := Output (First .. I - 1);
                     C_Val    : Natural := 0;
                     M_Val    : Natural := 0;
                  begin
                     if Raw_Line'Length > 3 then
                        Row_Count := Row_Count + 1;
                        if Is_Windows then
                           Rows (Row_Count) := Format_Tasklist_Line (Raw_Line);
                        else
                           Format_PS_Line
                             (Raw_Line, Rows (Row_Count), C_Val, M_Val);
                           CPU_Sum := CPU_Sum + C_Val;
                           Mem_Sum := Mem_Sum + M_Val;
                        end if;
                     end if;
                  end;
               end if;

               First := I + 1;
            end if;
         end loop;
      end;

      if not Is_Windows and then Row_Count > 0 then
         --  Normalize total CPU across 4 logical bars and clamp to 100
         D.CPU_Total := Natural'Min (100, CPU_Sum / 4);
         D.Mem_Total := Natural'Min (100, Mem_Sum);
      end if;

      if Row_Count = 0 then
         declare
            C_Val, M_Val : Natural;
         begin
            Row_Count := 1;
            Format_PS_Line
              ("1 system 0.0 0.1 00:00.01 showcase", Rows (1), C_Val, M_Val);
         end;
      end if;

   exception
      when others =>
         for A of Args loop
            Free (A);
         end loop;
         if Row_Count = 0 then
            Row_Count := 1;
            Rows (1) :=
              Pad_Left ("1", 6) & " "
              & Pad_Right ("system", 10) & " "
              & Pad_Left ("0.0", 6) & " "
              & Pad_Left ("0.1", 6) & " "
              & Pad_Left ("00:00.01", 10) & " "
              & Pad_Right ("showcase", 21);
         end if;
   end Refresh_Processes;

   -------------------
   -- Process_Count --
   -------------------

   function Process_Count return Natural is
     (if Row_Count = 0 then 1 else Row_Count);

   -----------------
   -- Process_Row --
   -----------------

   function Process_Row (Index : Positive) return String is
   begin
      if Index <= Row_Count then
         return Rows (Index);
      end if;

      return Rows (1);
   end Process_Row;

   ----------------
   -- Draw_Meter --
   ----------------

   procedure Draw_Meter
     (Frame : in out Buffer;
      Area  : Rect;
      Label : String;
      Value : Gauges.Percent)
   is
      Cols : constant Rect_Array :=
        Split (Area, Row, [Fixed (4), Flex, Fixed (4)], Gap => 1);
   begin
      Labels.Draw (Frame, Cols (1), Label, Bold (Plain));
      Gauges.Draw (Frame, Cols (2), Value, Level_Color (Value));
      Labels.Draw (Frame, Cols (3), Image (Value) & "%", Faint, Labels.Right);
   end Draw_Meter;

   ----------
   -- Draw --
   ----------

   overriding procedure Draw
     (D       : in out State;
      Frame   : in out Buffer;
      Area    : Rect;
      Focused : Boolean)
   is
      Inner   : constant Rect := Blocks.Inner (Area);
      Bands   : constant Rect_Array :=
        Split (Inner, Column, [Fixed (4), Fixed (1), Flex, Fixed (1)], Gap => 1);
      Meters  : constant Rect_Array :=
        Split (Bands (1), Row, [Flex (1), Flex (1)], Gap => 2);
      Left_M  : constant Rect_Array :=
        Split (Meters (1), Column,
               [Fixed (1), Fixed (1), Fixed (1), Fixed (1)]);
      Right_M : constant Rect_Array :=
        Split (Meters (2), Column,
               [Fixed (1), Fixed (1), Fixed (1), Fixed (1)]);

      Base : constant Natural := D.CPU_Total;
      C1   : constant Gauges.Percent := Natural'Min (100, Base + 6);
      C2   : constant Gauges.Percent := Natural'Min (100, Base / 2 + 4);
      C3   : constant Gauges.Percent := Natural'Min (100, (Base * 3) / 4 + 2);
      C4   : constant Gauges.Percent := Natural'Min (100, Base / 3 + 1);
      Sort_Label : constant String :=
        (if D.Sort_By_Mem then "MEM%" else "CPU%");
   begin
      --  Auto-refresh in real time every Refresh_Interval frames (~1s)
      if D.Ticks mod Refresh_Interval = 0 then
         Refresh_Processes (D);
      end if;
      D.Ticks := D.Ticks + 1;

      Blocks.Draw
        (Frame, Area,
         "HTop (Live - sorted by " & Sort_Label & ")",
         Border (Focused));

      Draw_Meter (Frame, Left_M (1), "CPU1", C1);
      Draw_Meter (Frame, Left_M (2), "CPU2", C2);
      Draw_Meter (Frame, Left_M (3), "CPU3", C3);
      Draw_Meter (Frame, Left_M (4), "CPU4", C4);

      Draw_Meter (Frame, Right_M (1), "Mem ", D.Mem_Total mod 101);
      Draw_Meter (Frame, Right_M (2), "Swap", 12);
      Labels.Draw
        (Frame, Right_M (3),
         "Tasks: " & Image (Row_Count) & " live");
      Labels.Draw
        (Frame, Right_M (4),
         "Row: " & Image (D.Procs.Selected) & "/" & Image (Row_Count), Faint);

      Labels.Draw (Frame, Bands (2), Header_Text, Header);

      Process_Lists.Draw (Frame, Bands (3), D.Procs);

      Labels.Draw
        (Frame, Bands (4),
         "Up/Down: select   c: sort CPU   m: sort Mem",
         Faint);
   end Draw;

   ------------
   -- Update --
   ------------

   overriding procedure Update
     (D    : in out State;
      E    : Event;
      Used : out Boolean)
   is
   begin
      Process_Lists.Handle (D.Procs, E, Used);

      if Used then
         return;
      end if;

      if E.Kind = Text_Input then
         case E.Text (1) is
            when 'c' | 'C' =>
               D.Sort_By_Mem := False;
               Refresh_Processes (D);
               Used := True;
            when 'm' | 'M' =>
               D.Sort_By_Mem := True;
               Refresh_Processes (D);
               Used := True;
            when others =>
               Used := False;
         end case;
      else
         Used := False;
      end if;
   end Update;

end Demo.HTop;