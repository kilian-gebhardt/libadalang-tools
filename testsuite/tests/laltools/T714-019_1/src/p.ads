package P is
   type My_Enum is (First, Second, Third);
   function Foo return Integer;
   function Exprf return Boolean is (Foo = 42);
   procedure Look_My_Param (X : Integer := Foo) is null;
end P;
