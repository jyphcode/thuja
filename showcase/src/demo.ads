with Bedrock.Input;  use Bedrock.Input;
with Bedrock.Screen; use Bedrock.Screen;
with Thuja.Buffers;  use Thuja.Buffers;
with Thuja.Styles;   use Thuja.Styles;

with Bedrock.Colors;

package Demo is
   type Instance is interface;

   function Name (D : Instance) return String is abstract;
   procedure Draw
     (D : in out Instance; Frame : in out Buffer; Area : Rect; Focused : Boolean) is abstract;
   procedure Update (D : in out Instance; E : Event; Used : out Boolean) is abstract;

   function Border (Focused : Boolean) return Style is
     (if Focused then Bold (Colored (Bedrock.Colors.Sky_Blue)) else Plain);
end Demo;
