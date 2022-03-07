with Ada.Text_IO;
package body Foo is
   type Baz is record
      A, C, Z : Integer;
   end record;
   
   function Baz_Constructor (B : Boolean) return Baz is
   begin
      return (if B then (1, 2, 2) else (2, 1, 1));
   end Baz_Constructor;
   
   procedure Bar is
      A : constant Baz := (1, 2, 3);
      B : constant Baz := (A => 1, C => 3, Z => 2);
   begin
      Ada.Text_IO.Put_Line (A.A'Image);
      Ada.Text_IO.Put_Line (B.Z'Image);
   end Bar;
   
begin
   Ada.Text_IO.Put_Line ("Package elaboration");
end Foo;
