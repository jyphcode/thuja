package body Thuja.Input with SPARK_Mode is

   ESC : constant Character := Character'Val (16#1B#);

   function Key_Press (K : Key; Mods : Modifiers := No_Modifiers) return Event is
     (Key_Event (K, Down => True, Mods => Mods));

   function Text (Byte : Character) return Event is
     ((Kind   => Text_Input,
       Time   => 0,
       Window => Bedrock.Screen.No_Window,
       Text   => [1 => Byte, others => ' '],
       Length => 1));

   function Letter (Offset : Natural) return Key is
     (Key'Val (Key'Pos (Key_A) + Offset))
     with Pre => Offset <= 25;

   function Digit (Offset : Natural) return Key is
     (Key'Val (Key'Pos (Key_0) + Offset))
     with Pre => Offset <= 9;

   procedure Feed_Ground (D : in out Decoder; Byte : Character; E : out Event)
     with Pre => not E'Constrained;

   procedure Feed_Escape (D : in out Decoder; Byte : Character; E : out Event)
     with Pre => not E'Constrained;

   procedure Feed_CSI (D : in out Decoder; Byte : Character; E : out Event)
     with Pre => not E'Constrained;

   procedure Feed_SS3 (D : in out Decoder; Byte : Character; E : out Event)
     with Pre => not E'Constrained;

   procedure Feed_UTF8 (D : in out Decoder; Byte : Character; E : out Event)
     with Pre => not E'Constrained;

   --  Validate the second byte of a UTF-8 sequence
   function Second_Ok (Lead, Byte : Natural) return Boolean is
   (case Lead is
         when 16#E0# => Byte in 16#A0# .. 16#BF#,
         when 16#ED# => Byte in 16#80# .. 16#9F#,
         when 16#F0# => Byte in 16#90# .. 16#BF#,
         when 16#F4# => Byte in 16#80# .. 16#8F#,
         when others => Byte in 16#80# .. 16#BF#);

   -----------------
   -- Feed_Ground --
   -----------------

   procedure Feed_Ground (D : in out Decoder; Byte : Character; E : out Event) is
      Code : constant Natural := Character'Pos (Byte);
   begin
      case Code is
         when 16#1B# =>
            D.Where := Escape;
            E := No_Event;

         when 16#0D# | 16#0A# =>
            E := Key_Press (Key_Return);

         when 16#09# =>
            E := Key_Press (Key_Tab);

         when 16#08# | 16#7F# =>
            E := Key_Press (Key_Backspace);

         when 16#00# =>
            E := Key_Press (Key_Space, (Ctrl => True, others => False));

         when 16#01# .. 16#07# | 16#0B# | 16#0C# | 16#0E# .. 16#1A# =>
            --  Ctrl + letter arrives as the letter's position in the
            --  alphabet: Ctrl + A is 1, Ctrl + Z is 26.
            E := Key_Press (Letter (Code - 1), (Ctrl => True, others => False));

         when 16#20# .. 16#7E# =>
            E := Text (Byte);

         when 2#11000010# .. 2#11011111# =>
            D.Where := UTF8;
            D.Bytes (1) := Byte;
            D.Have  := 1;
            D.Need  := 2;
            E := No_Event;

         when 2#11100000# .. 2#11101111# =>
            D.Where := UTF8;
            D.Bytes (1) := Byte;
            D.Have  := 1;
            D.Need  := 3;
            E := No_Event;

         when 2#11110000# .. 2#11110100# =>
            D.Where := UTF8;
            D.Bytes (1) := Byte;
            D.Have  := 1;
            D.Need  := 4;
            E := No_Event;

         when others =>
            E := No_Event;
      end case;
   end Feed_Ground;

   -----------------
   -- Feed_Escape --
   -----------------

   procedure Feed_Escape (D : in out Decoder; Byte : Character; E : out Event) is
      Alt : constant Modifiers := (Alt => True, others => False);
   begin
      D.Where := Ground;

      case Byte is
         when '[' =>
            D.Where := CSI;
            D.Length := 0;
            E := No_Event;

         when ESC =>
            --  Two in a row: the first one was the Escape key.
            D.Where := Escape;
            E := Key_Press (Key_Escape);

         when 'a' .. 'z' =>
            E := Key_Press (Letter (Character'Pos (Byte) - Character'Pos ('a')), Alt);

         when 'A' .. 'N' | 'P' .. 'Z' =>
            E := Key_Press
              (Letter (Character'Pos (Byte) - Character'Pos ('A')),
               (Alt => True, Shift => True, others => False));

         when '0' .. '9' =>
            E := Key_Press (Digit (Character'Pos (Byte) - Character'Pos ('0')), Alt);

         when 'O' =>
            D.Where := SS3;
            E := No_Event;

         when others =>
            E := No_Event;
      end case;
   end Feed_Escape;

   --------------
   -- Feed_CSI --
   --------------

   procedure Feed_CSI (D : in out Decoder; Byte : Character; E : out Event) is
   begin
      E := No_Event;

      case Byte is
         when '@' .. '~' =>
            --  The final byte: the sequence is complete, known or not.
            D.Where := Ground;

            --  PLACEHOLDER: sequences with parameters are dropped.
            if D.Length = 0 then
               case Byte is
                  when 'A' => E := Key_Press (Key_Up);
                  when 'B' => E := Key_Press (Key_Down);
                  when 'C' => E := Key_Press (Key_Right);
                  when 'D' => E := Key_Press (Key_Left);
                  when 'H' => E := Key_Press (Key_Home);
                  when 'F' => E := Key_Press (Key_End);
                  when others => null;
               end case;
            end if;

            D.Length := 0;

         when ' ' .. '?' =>
            --  A parameter or intermediate byte.
            if D.Length < Max_Sequence then
               D.Length := D.Length + 1;
            else
               D.Where := Ground;
               D.Length := 0;
            end if;

         when others =>
            --  Not part of any sequence: abandon it.
            D.Where := Ground;
            D.Length := 0;
      end case;
   end Feed_CSI;

   --------------
   -- Feed_SS3 --
   --------------

   procedure Feed_SS3 (D : in out Decoder; Byte : Character; E : out Event) is
   begin
      --  SS3 is a single shift, so we only process as SS3 for one byte
      D.Where := Ground;

      case Byte is
         when 'P' .. 'S' =>
            E := Key_Press
               (Key'Val (Key'Pos (Key_F1) + Character'Pos (Byte) - Character'Pos ('P')));
         when others => E := No_Event;
      end case;
   end Feed_SS3;

   ---------------
   -- Feed_UTF8 --
   ---------------

   procedure Feed_UTF8 (D : in out Decoder; Byte : Character; E : out Event) is
      Code : constant Natural := Character'Pos (Byte);
   begin
      if Code not in 2#10000000# .. 2#10111111#
         or else D.Have >= D.Need
         or else (D.Have = 1 and then not Second_Ok (Character'Pos (D.Bytes (1)), Code))
      then
         --  Not a continuation byte: drop the unfinished character and
         --  read Byte as the start of something new.
         D := (Where => Ground, Bytes => "    ", others => 0);
         Feed_Ground (D, Byte, E);
         return;
      end if;

      D.Have := D.Have + 1;
      D.Bytes (D.Have) := Byte;

      if D.Have = D.Need then
         E := (Kind   => Text_Input,
               Time   => 0,
               Window => Bedrock.Screen.No_Window,
               Text   => D.Bytes,
               Length => D.Need);
         D := (Where => Ground, Bytes => "    ", others => 0);
      else
         E := No_Event;
      end if;
   end Feed_UTF8;

   ----------
   -- Feed --
   ----------

   procedure Feed (D : in out Decoder; Byte : Character; E : out Event) is
   begin
      case D.Where is
         when Ground => Feed_Ground (D, Byte, E);
         when Escape => Feed_Escape (D, Byte, E);
         when CSI    => Feed_CSI (D, Byte, E);
         when SS3    => Feed_SS3 (D, Byte, E);
         when UTF8   => Feed_UTF8 (D, Byte, E);
      end case;
   end Feed;

   -----------
   -- Flush --
   -----------

   procedure Flush (D : in out Decoder; E : out Event) is
      Alt_Shift : constant Modifiers := (Alt => True, Shift => True, others => False);
   begin
      if D.Where = Escape then
         E := Key_Press (Key_Escape);
      elsif D.Where = SS3 then
         E := Key_Press (Key_O, Alt_Shift);
      else
         E := No_Event;
      end if;

      D := (Where => Ground, Bytes => "    ", others => 0);
   end Flush;

end Thuja.Input;
