--  One line of input text in an area
with Bedrock.Input; use Bedrock.Input;
with Thuja.Buffers; use Thuja.Buffers;
with Ada.Strings.Bounded;

package Thuja.Widgets.Text_Fields is
   --  Do a Max length of 256 by default
   Max_Length : constant Natural := 256;

   package Input_Strings is new
      Ada.Strings.Bounded.Generic_Bounded_Length (Max => Max_Length);

   use Input_Strings;

   type State is record
      Text    : Bounded_String := Null_Bounded_String;
      Cursor  : Natural := 0; -- start at 0
   end record;
   --  Keep track of the internal state of the text Input
   --  Also keep track of where the cursor is in the input

   procedure Handle (S : in out State;
                     E : Event; Used :
                     out Boolean);
   --  Left, Right, Home and End move the selection.
   --  Alphanumeric and space will be entered into the input
   --  Any other event are used as false

   procedure Draw
     (Frame     : in out Buffer;
      Area      : Rect;
      S         : in out State;
      Title     : String)
     with Pre => In_Range (Area);
   --  Three rows row for the entire input box
   --  Along with a title

   procedure Set_Text (S : in out State;
                       Text : String)
      with Pre => Text'Length >= 0 and then Text'Length < 256;

end Thuja.Widgets.Text_Fields;