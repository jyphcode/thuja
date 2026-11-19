--  UTF-8 encoding of one character. Terminals speak UTF-8; cells hold
--  Wide_Wide_Character.

package Thuja.UTF8 with SPARK_Mode, Pure is

   function Encode (C : Wide_Wide_Character) return String
     with Post => Encode'Result'First = 1 and then Encode'Result'Length in 1 .. 4;
   --  The bytes of C. Code points that UTF-8 cannot carry become '?'.

   function Sequence_Length (Lead : Character) return Positive
     with Post => Sequence_Length'Result in 1 .. 4;
   --  How many bytes the character starting with Lead takes.

   function Decode (S : String) return Wide_Wide_Character
     with Post => Wide_Wide_Character'Pos (Decode'Result) <= 16#10_FFFF#
                  and then Wide_Wide_Character'Pos (Decode'Result) not in 16#D800# .. 16#DFFF#;
   --  The character that S encodes. Anything that is not exactly one
   --  valid UTF-8 character becomes U+FFFD.

end Thuja.UTF8;
