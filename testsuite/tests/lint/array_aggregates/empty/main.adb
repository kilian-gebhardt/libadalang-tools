procedure Main is
   type My_Int is range 0 .. 1000;
   Arr_Null : array (1 .. 0) of My_Int := (1 .. 0 => 3);
begin
   null;
end Main;

