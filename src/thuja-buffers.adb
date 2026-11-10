package body Thuja.Buffers with SPARK_Mode is

   -----------
   -- Clear --
   -----------

   procedure Clear (B : in out Buffer) is
   begin
      for Y in B.Cells'Range (1) loop
         for X in B.Cells'Range (2) loop
            B.Cells (Y, X) := Blank;
         end loop;
      end loop;

      --  Clear cursor data
      B.Cursor_Request := (others => <>);
   end Clear;

   ---------
   -- Set --
   ---------

   procedure Set (B : in out Buffer; X, Y : Pixels; C : Cell) is
   begin
      if Has (B, X, Y) then
         B.Cells (Y + 1, X + 1) := C;
      end if;
   end Set;

   ----------
   -- Fill --
   ----------

   procedure Fill (B : in out Buffer; Area : Rect; C : Cell) is
      Visible : constant Rect := Intersection (Area, Buffers.Area (B));
   begin
      if Is_Empty (Visible) then
         return;
      end if;

      for Y in Visible.Origin.Y .. Pixels (Bottom (Visible) - 1) loop
         for X in Visible.Origin.X .. Pixels (Right (Visible) - 1) loop
            B.Cells (Y + 1, X + 1) := C;
         end loop;
      end loop;
   end Fill;

   ----------
   -- Copy --
   ----------

   procedure Copy (Source : Buffer; Target : in out Buffer) is
   begin
      for Y in 1 .. Pixels'Min (Source.Height, Target.Height) loop
         for X in 1 .. Pixels'Min (Source.Width, Target.Width) loop
            Target.Cells (Y, X) := Source.Cells (Y, X);
         end loop;
      end loop;

      --  Copy cursor data
      Target.Cursor_Request := Source.Cursor_Request;
   end Copy;

   ---------
   -- Put --
   ---------

   procedure Put
     (B    : in out Buffer;
      X, Y : Pixels;
      Text : String;
      S    : Style;
      Clip : Rect)
   is
      Wide : Wide_Wide_String (Text'Range);
   begin
      for I in Text'Range loop
         Wide (I) := Wide_Wide_Character'Val (Character'Pos (Text (I)));
      end loop;

      Put_Wide (B, X, Y, Wide, S, Clip);
   end Put;

   --------------
   -- Put_Wide --
   --------------

   procedure Put_Wide
     (B    : in out Buffer;
      X, Y : Pixels;
      Text : Wide_Wide_String;
      S    : Style;
      Clip : Rect)
   is
      Visible : constant Rect := Intersection (Clip, Area (B));
      Column  : Integer := Integer (X);
   begin
      if Is_Empty (Visible)
        or else Y < Visible.Origin.Y
        or else Integer (Y) >= Bottom (Visible)
      then
         return;
      end if;

      for C of Text loop
         exit when Column >= Right (Visible);

         if Column >= Integer (Visible.Origin.X) then
            B.Cells (Y + 1, Pixels (Column) + 1) := (Glyph => C, Style => S);
         end if;

         Column := Column + 1;
      end loop;
   end Put_Wide;

   ---------------
   -- Row_Image --
   ---------------

   function Row_Image (B : Buffer; Y : Pixels) return Wide_Wide_String is
      Result : Wide_Wide_String (1 .. Natural (B.Width)) := [others => ' '];
   begin
      for X in 0 .. B.Width - 1 loop
         Result (Natural (X) + 1) := B.Cells (Y + 1, X + 1).Glyph;
      end loop;

      return Result;
   end Row_Image;

   ---------------
   --   Cursor  --
   ---------------

   function Cursor (B : Buffer) return Cursor_Info is
   begin
      return B.Cursor_Request;
   end Cursor;

   procedure Set_Cursor
      (B         : in out Buffer;
      X, Y       : Pixels; --  x,y within the container
      Container  : Rect) is   --  container for the cursor
   begin
      B.Cursor_Request.X := Container.Origin.X + X;
      B.Cursor_Request.Y := Container.Origin.Y + Y;
      B.Cursor_Request.Style := B.Cursor_Style_State;
      B.Cursor_Request.Visible := True;
   end Set_Cursor;

   procedure Set_Cursor_Style (B : in out Buffer; Style : Cursor_Style) is
   begin
      B.Cursor_Style_State := Style;
   end Set_Cursor_Style;

end Thuja.Buffers;
