with Thuja.Styles;  use Thuja.Styles;
with Thuja.Widgets.Blocks;
package body Thuja.Widgets.Text_Fields is

   --  Some specifications for the String Helpers
   function Space_Before (S : State) return Natural;

   function Space_After (S : State) return Natural;

   procedure Move_Left (S : in out State; shift : Natural);

   procedure Move_Right (S : in out State; shift : Natural);

   procedure Delete_Before (S : in out State);
   ------------
   -- Handle --
   ------------
   procedure Handle (S : in out State; E : Event; Used : out Boolean) is
   begin
      Used := True;

      case E.Kind is
         when Key_Down =>
            case E.Key is
               when Key_Left =>
                  if E.Mods.Ctrl then
                     S.Cursor := Space_Before (S);
                  else
                     Move_Left (S, 1);
                  end if;
               when Key_B =>
                  if E.Mods.Ctrl then
                     Move_Left (S, 1);
                  end if;

               when Key_Right =>
                  if E.Mods.Ctrl then
                     S.Cursor := Space_After (S);
                  else
                     Move_Right (S, 1);
                  end if;
               when Key_F =>
                  if E.Mods.Ctrl then
                     Move_Right (S, 1);
                  end if;

               --  Handle Moving to the start
               --  With either Home or Ctrl - A
               when Key_Home =>
                  S.Cursor := 0;
               when Key_A =>
                  if E.Mods.Ctrl then
                     S.Cursor := 0;
                  end if;

               --  Handle Moving to the End
               --  With either End or Ctrl - E
               when Key_End =>
                  S.Cursor := Length (S.Text);
               when Key_E =>
                  if E.Mods.Ctrl then
                     S.Cursor := Length (S.Text);
                  end if;

               when Key_K =>
                  if E.Mods.Ctrl then
                     Delete (S.Text, From => S.Cursor, Through => Length (S.Text));
                  end if;

               when Key_U =>
                  if E.Mods.Ctrl then
                     Delete (S.Text, From => 1, Through => S.Cursor);
                     S.Cursor := 0;
                  end if;

               when Key_W =>
                  if E.Mods.Ctrl then
                     --  Delete the word before the cursor
                     Delete_Before (S);
                  end if;

               when Key_Backspace =>
                  if S.Cursor > 0 and S.Cursor <= Length (S.Text) then
                     Delete (S.Text, From => S.Cursor, Through => S.Cursor);
                     S.Cursor := S.Cursor - 1;
                  end if;

               when others =>
                  Used := False;

            end case;

         when Text_Input =>
               --  @TODO temporary limit max length to -1 because of putting in the pipe
               --  to act the cursor. This can be removed when moving to the actual terminal cursor
               if Length (S.Text) < Max_Length - 1 then
                  Insert (S.Text, S.Cursor + 1, E.Text (1 .. E.Length));
                  S.Cursor := S.Cursor + 1;
               end if;

         when others =>
            Used := False;

      end case;
   end Handle;

   ----------
   -- Draw --
   ----------

   procedure Draw
     (Frame     : in out Buffer;
      Area      : Rect;
      S         : in out State;
      Title     : String)
   is
      Look  : constant Style := Thuja.Styles.Plain;
      Render_Text : constant Bounded_String := S.Text;
      Row   : constant Rect :=
        Make (Area.Origin.X, Area.Origin.Y, Area.Extent.Width, 3);
   begin
      if Is_Empty (Area) or
         Area.Origin.Y < 3 -- only allow 3 so we can block it
      then
         return;
      end if;

      Fill (Frame, Row, (' ', Look));

      --  Draw the input's border and title
      Blocks.Draw (Frame, Row, Title);

      --  Inject cursor at specific point
      Set_Cursor (B => Frame,
         X => Pixels (S.Cursor + 1),
         Y => 1,
         Container => Row);

      Put (Frame, Row.Origin.X + 1, Row.Origin.Y + 1,
            To_String (Render_Text), Look, Clip => Row);
   end Draw;

   --------------
   -- Set_Text --
   --------------

   procedure Set_Text (S : in out State;
                       Text : String) is
   begin
      S.Text := To_Bounded_String (Text);
      S.Cursor := Text'Length;
   end Set_Text;

   --------------------
   -- String Helpers --
   --------------------

   --  Get space before
   function Space_Before (S : State) return Natural is
      Text : constant String := To_String (S.Text);
      Cursor : Natural := S.Cursor;
   begin
      if Cursor = 0 then
         return Cursor;
      end if;
      --  Start at the current space, go left until it's a non space
      --  and then find the first space (or string start) that appears
      while Cursor > 0 and then Text (Cursor) = ' ' loop
         Cursor := Cursor - 1;
      end loop;

      while Cursor > 0 and then Text (Cursor) /= ' ' loop
         Cursor := Cursor - 1;
      end loop;

      return Cursor;
   end Space_Before;

   --  Get Space after
   function Space_After (S : State) return Natural is
      Text : constant String := To_String (S.Text);
      Cursor : Natural := S.Cursor;
   begin
      if Cursor = Text'Length then
         return Cursor;
      end if;
      --  Start at the current space, go right until it's a non space
      --  and then find the first space (or string end) that appears
      while Cursor < Text'Length and then Text (Cursor + 1) = ' ' loop
         Cursor := Cursor + 1;
      end loop;

      while Cursor < Text'Length and then Text (Cursor + 1) /= ' ' loop
         Cursor := Cursor + 1;
      end loop;

      return Cursor;
   end Space_After;

   procedure Delete_Before (S : in out State) is
      BeforeIndex : Natural := S.Cursor;
      AfterIndex : constant Natural := S.Cursor;
      Text : constant String := To_String (S.Text);
   begin
      --  Don't do anything if we're already at the start.
      if S.Cursor <= 1 then
         return;
      end if;

      while BeforeIndex > 0 and then Text (BeforeIndex) = ' ' loop
         BeforeIndex := BeforeIndex - 1;
      end loop;

      while BeforeIndex > 0 and then Text (BeforeIndex) /= ' ' loop
         BeforeIndex := BeforeIndex - 1;
      end loop;

      if BeforeIndex /= 1 then
         BeforeIndex := BeforeIndex + 1;
      end if;

      S.Cursor := BeforeIndex - 1;
      Delete (S.Text, From => BeforeIndex, Through => AfterIndex);
   end Delete_Before;

   --  Move Left #
   procedure Move_Left (S : in out State; shift : Natural) is
   begin
      S.Cursor := Natural'Max (0, S.Cursor - shift);
   end Move_Left;

   --  Move Right #
   procedure Move_Right (S : in out State; shift : Natural) is
   begin
      S.Cursor := Natural'Min (Length (S.Text), S.Cursor + shift);
   end Move_Right;
end Thuja.Widgets.Text_Fields;
