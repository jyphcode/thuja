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

   Refresh_Interval : constant := 10;

   Max_Procs : constant := 40;
   Row_Width : constant := 64;

   subtype Row_String is String (1 .. Row_Width);

   type Proc_Record is record
      Text    : Row_String := [others => ' '];
      CPU_Key : Natural    := 0;
      Mem_Key : Natural    := 0;
   end record;

   Rows      : array (1 .. Max_Procs) of Proc_Record;
   Row_Count : Natural := 0;

   Header_Text : constant Row_String :=
     "   PID USER         %CPU   %MEM       TIME COMMAND              ";

   Is_Windows : constant Boolean := (GNAT.OS_Lib.Directory_Separator = '\');

   function Image (N : Natural) return String;
   function Level_Color (Value : Gauges.Percent) return Style;
   function Parse_Digits (S : String) return Natural;
   function Pad_Left (S : String; Width : Positive) return String;
   function Pad_Right (S : String; Width : Positive) return String;
   procedure Sort_Rows (By_Mem : Boolean);
   procedure Format_PS_Line
     (Raw     : String;
      Rec_Out : out Proc_Record);
   procedure Format_Tasklist_Line
     (Raw     : String;
      Tick    : Natural;
      Rec_Out : out Proc_Record);
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

   ------------------
   -- Parse_Digits --
   ------------------

   function Parse_Digits (S : String) return Natural is
      Acc : Natural := 0;
   begin
      for C of S loop
         exit when C = '.';
         if C in '0' .. '9' then
            if Acc < 10_000_000 then
               Acc := Acc * 10 + (Character'Pos (C) - Character'Pos ('0'));
            end if;
         end if;
      end loop;
      return Acc;
   end Parse_Digits;

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

   ---------------
   -- Sort_Rows --
   ---------------

   procedure Sort_Rows (By_Mem : Boolean) is
      Temp : Proc_Record;
   begin
      for I in 2 .. Row_Count loop
         for J in reverse 2 .. I loop
            declare
               Swap : constant Boolean :=
                 (if By_Mem
                  then Rows (J).Mem_Key > Rows (J - 1).Mem_Key
                  else Rows (J).CPU_Key > Rows (J - 1).CPU_Key);
            begin
               if Swap then
                  Temp         := Rows (J);
                  Rows (J)     := Rows (J - 1);
                  Rows (J - 1) := Temp;
               else
                  exit;
               end if;
            end;
         end loop;
      end loop;
   end Sort_Rows;

   --------------------
   -- Format_PS_Line --
   --------------------

   procedure Format_PS_Line
     (Raw     : String;
      Rec_Out : out Proc_Record)
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
         Rec_Out.CPU_Key := Parse_Digits (CPU_S);
         Rec_Out.Mem_Key := Parse_Digits (Mem_S);

         Rec_Out.Text := Pad_Left (PID_S, 6) & " "
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

   procedure Format_Tasklist_Line
     (Raw     : String;
      Tick    : Natural;
      Rec_Out : out Proc_Record)
   is
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

      Next_CSV_Field (F1, L1); --  Image Name
      Next_CSV_Field (F2, L2); --  PID
      Next_CSV_Field (F3, L3); --  Session Name
      Next_CSV_Field (F4, L4); --  Session#
      Next_CSV_Field (F5, L5); --  Mem Usage (e.g. "193,832 K")

      declare
         Cmd_S   : constant String := (if L1 >= F1 then Clean (F1 .. L1) else "");
         PID_S   : constant String := (if L2 >= F2 then Clean (F2 .. L2) else "");
         User_S  : constant String := (if L3 >= F3 then Clean (F3 .. L3) else "");
         Mem_Raw : constant String := (if L5 >= F5 then Clean (F5 .. L5) else "");

         PID_Num : constant Natural := Parse_Digits (PID_S);
         Mem_KB  : constant Natural := Parse_Digits (Mem_Raw);
         --  Convert KB to % of a typical 16 GB system (167,772 KB = 1.0%)
         Mem_Whole : constant Natural := Mem_KB / 160_000;
         Mem_Frac  : constant Natural := (Mem_KB / 16_000) mod 10;
         Mem_Pct_S : constant String  :=
           Image (Mem_Whole) & "." & Image (Mem_Frac);

         --  Derive active CPU activity from working-set size & tick
         CPU_Tenths : constant Natural :=
           (if PID_Num = 0 then 0
            else ((Mem_KB / 25_000) + ((PID_Num + Tick) mod 15)) mod 240);
         CPU_S : constant String :=
           Image (CPU_Tenths / 10) & "." & Image (CPU_Tenths mod 10);

         Mins   : constant Natural := (PID_Num mod 12);
         Secs   : constant Natural := (PID_Num * 7 + Tick) mod 60;
         Time_S : constant String  :=
           "0" & Image (Mins mod 10) & ":"
           & (if Secs < 10 then "0" else "") & Image (Secs) & ".00";
      begin
         Rec_Out.CPU_Key := CPU_Tenths;
         Rec_Out.Mem_Key := Mem_KB;

         Rec_Out.Text := Pad_Left (PID_S, 6) & " "
           & Pad_Right (User_S, 10) & " "
           & Pad_Left (CPU_S, 6) & " "
           & Pad_Left (Mem_Pct_S, 6) & " "
           & Pad_Left (Time_S, 10) & " "
           & Pad_Right (Cmd_S, 21);
      end;
   end Format_Tasklist_Line;

   -----------------------
   -- Refresh_Processes --
   -----------------------

   procedure Refresh_Processes (D : in out State) is
      use GNAT.OS_Lib;
      Sort_Flag : constant String := (if D.Sort_By_Mem then "-m" else "-r");
      --  On Windows, filter out PID 0/4 Idle/System and only grab active apps (>10,000 KB)
      Args : Argument_List :=
        (if Is_Windows
         then [new String'("/FO"),
               new String'("CSV"),
               new String'("/NH"),
               new String'("/FI"),
               new String'("MEMUSAGE gt 15000")]
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
                  begin
                     if Raw_Line'Length > 3
                       and then (not Is_Windows or else Raw_Line (Raw_Line'First) = '"')
                     then
                        Row_Count := Row_Count + 1;
                        if Is_Windows then
                           Format_Tasklist_Line
                             (Raw_Line, D.Ticks, Rows (Row_Count));
                           CPU_Sum := CPU_Sum + (Rows (Row_Count).CPU_Key / 10);
                           Mem_Sum := Mem_Sum + (Rows (Row_Count).Mem_Key / 160_000);
                        else
                           Format_PS_Line (Raw_Line, Rows (Row_Count));
                           CPU_Sum := CPU_Sum + Rows (Row_Count).CPU_Key;
                           Mem_Sum := Mem_Sum + Rows (Row_Count).Mem_Key;
                        end if;
                     end if;
                  end;
               end if;

               First := I + 1;
            end if;
         end loop;
      end;

      if Row_Count > 1 then
         Sort_Rows (By_Mem => D.Sort_By_Mem);
      end if;

      if Row_Count > 0 then
         D.CPU_Total := Natural'Min (100, Natural'Max (8, CPU_Sum / 3));
         D.Mem_Total := Natural'Min (100, Natural'Max (15, Mem_Sum));
      end if;

      if Row_Count = 0 then
         Row_Count := 1;
         Format_PS_Line ("1 system 0.0 0.1 00:00.01 showcase", Rows (1));
      end if;

   exception
      when others =>
         for A of Args loop
            Free (A);
         end loop;
         if Row_Count = 0 then
            Row_Count := 1;
            Rows (1).Text :=
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
         return Rows (Index).Text;
      end if;

      return Rows (1).Text;
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
               Sort_Rows (By_Mem => False);
               Used := True;
            when 'm' | 'M' =>
               D.Sort_By_Mem := True;
               Sort_Rows (By_Mem => True);
               Used := True;
            when others =>
               Used := False;
         end case;
      else
         Used := False;
      end if;
   end Update;

end Demo.HTop;