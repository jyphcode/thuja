--  THE DECODER. Bytes from the terminal in, typed events out.
--
--  A terminal does not send "the user pressed the up arrow". It sends
--  bytes: 1B 5B 41. A letter is one byte, an accented letter is two or
--  more, a function key is up to eight, and the Escape key alone is
--  1B, the same byte that starts every sequence. This package turns
--  that stream into Bedrock.Input events and is the only place that
--  knows about escape sequences.
--
--  It is pure: no terminal, no clock, no I/O. Feed it one byte, get at
--  most one event. That is what makes it testable from a string
--  literal, and provable.
--
--  How events map (a terminal cannot tell key-down from key-up, and
--  does not report Shift on its own):
--
--    printable character     Text_Input, Text (1 .. Length) in UTF-8
--    Enter, Tab, arrows...   Key_Down with that Key
--    Ctrl + letter           Key_Down, the letter's Key, Mods.Ctrl
--    Alt + letter or digit   Key_Down, its Key, Mods.Alt
--
--  PROOF TARGET. This package is the proved kernel of the project.
--    P1  No run-time error for any sequence of bytes.
--    P2  Bounded memory: no input can make the decoder hold more than
--        Max_Sequence bytes of state.
--    P3  After Flush the decoder is in its initial state.
--  P1 to P3 hold for the seed decoder. They must keep holding as the
--  decoder grows; that is the year's proof work.
--
--  PLACEHOLDER. The seed decodes ASCII text, Enter, Tab, Backspace,
--  Escape, Ctrl + letter, Alt + letter or digit, the four arrows, Home
--  and End. Everything else is recognised as a sequence and dropped
--  whole (never leaked as stray text), or ignored. Missing, roughly in
--  order of need:
--    * UTF-8 text (bytes 16#80# and above),
--    * CSI with parameters: Delete, Insert, Page Up/Down, F5 to F12,
--      and modifiers on arrows ("1;5C" is Ctrl + Right),
--    * mouse reports (SGR mode 1006) and bracketed paste.
--  tests/ has a TODO line for each.

with Bedrock.Input; use Bedrock.Input;

package Thuja.Input with SPARK_Mode is

   Max_Sequence : constant := 32;
   --  The longest escape sequence the decoder follows. A longer one is
   --  abandoned.

   type Decoder is private;
   --  A new decoder is in its initial state.

   function Pending (D : Decoder) return Boolean;
   --  True when the bytes received so far are the beginning of
   --  something: more bytes, or Flush, will decide what.

   procedure Feed (D : in out Decoder; Byte : Character; E : out Event)
     with Pre => not E'Constrained;
   --  One more byte from the terminal. E.Kind is None when the byte did
   --  not complete an event.

   procedure Flush (D : in out Decoder; E : out Event)
     with Pre  => not E'Constrained,
          Post => not Pending (D);
   --  "No more bytes for now." Call it when the terminal has been
   --  silent for a moment while Pending is True. A lone 1B becomes
   --  Key_Escape; an unfinished sequence is dropped.

private

   type State is (Ground, Escape, CSI, SS3);
   --  Ground : between events.
   --  Escape : 1B received.
   --  CSI    : 1B 5B received; collecting until the final byte.
   --  SS3    : 1B 4F received; one byte follows.

   type Decoder is record
      Where  : State := Ground;
      Length : Natural range 0 .. Max_Sequence := 0;
      --  Parameter bytes seen in the current CSI sequence.
   end record;

   function Pending (D : Decoder) return Boolean is (D.Where /= Ground);

end Thuja.Input;
