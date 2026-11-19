package body Thuja.UTF8 with SPARK_Mode is

   ------------
   -- Encode --
   ------------

   function Encode (C : Wide_Wide_Character) return String is
      Code : constant Natural := Wide_Wide_Character'Pos (C);

      function Tail (Divisor : Positive) return Character is
        (Character'Val (16#80# + (Code / Divisor) mod 64));
      --  A continuation byte: 10xxxxxx, six bits of Code.
   begin
      if Code < 16#80# then
         return [1 => Character'Val (Code)];
      elsif Code < 16#800# then
         return [Character'Val (16#C0# + Code / 64), Tail (1)];
      elsif Code in 16#D800# .. 16#DFFF# or else Code > 16#10_FFFF# then
         return "?";
      elsif Code < 16#1_0000# then
         return [Character'Val (16#E0# + Code / 4096), Tail (64), Tail (1)];
      else
         return [Character'Val (16#F0# + Code / 262_144), Tail (4096), Tail (64), Tail (1)];
      end if;
   end Encode;

   ---------------------
   -- Sequence_Length --
   ---------------------

   function Sequence_Length (Lead : Character) return Positive is
   begin
      case Character'Pos (Lead) is
         when 16#C2# .. 16#DF# => return 2;
         when 16#E0# .. 16#EF# => return 3;
         when 16#F0# .. 16#F4# => return 4;
         when others           => return 1;
      end case;
   end Sequence_Length;

   ------------
   -- Decode --
   ------------

   function Decode (S : String) return Wide_Wide_Character is
      Bad  : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#FFFD#);
      Lead : Natural;
      Need : Positive;
      Code : Natural;
   begin
      if S'Length = 0 then
         return Bad;
      end if;

      Lead := Character'Pos (S (S'First));

      case Lead is
         when 16#00# .. 16#7F# => Need := 1; Code := Lead;
         when 16#C2# .. 16#DF# => Need := 2; Code := Lead mod 32;
         when 16#E0# .. 16#EF# => Need := 3; Code := Lead mod 16;
         when 16#F0# .. 16#F4# => Need := 4; Code := Lead mod 8;
         when others           => return Bad;
      end case;

      if S'Length /= Need then
         return Bad;
      end if;

      for K in 1 .. Need - 1 loop
         pragma Loop_Invariant (Code < 2 ** (5 + 6 * (K - 1)));
         declare
            B : constant Natural := Character'Pos (S (S'First + K));
         begin
            if B not in 16#80# .. 16#BF# then
               return Bad;
            end if;
            Code := Code * 64 + B mod 64;
         end;
      end loop;

      if Code > 16#10_FFFF# or else Code in 16#D800# .. 16#DFFF# then
         return Bad;
      end if;

      return Wide_Wide_Character'Val (Code);
   end Decode;

end Thuja.UTF8;
