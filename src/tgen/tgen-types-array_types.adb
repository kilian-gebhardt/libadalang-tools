------------------------------------------------------------------------------
--                                                                          --
--                                  TGen                                    --
--                                                                          --
--                       Copyright (C) 2022, AdaCore                        --
--                                                                          --
-- TGen  is  free software; you can redistribute it and/or modify it  under --
-- under  terms of  the  GNU General  Public License  as  published by  the --
-- Free  Software  Foundation;  either version 3, or  (at your option)  any --
-- later version. This software  is distributed in the hope that it will be --
-- useful but  WITHOUT  ANY  WARRANTY; without even the implied warranty of --
-- MERCHANTABILITY  or  FITNESS  FOR A PARTICULAR PURPOSE.                  --
--                                                                          --
-- As a special  exception  under  Section 7  of  GPL  version 3,  you are  --
-- granted additional  permissions described in the  GCC  Runtime  Library  --
-- Exception, version 3.1, as published by the Free Software Foundation.    --
--                                                                          --
-- You should have received a copy of the GNU General Public License and a  --
-- copy of the GCC Runtime Library Exception along with this program;  see  --
-- the files COPYING3 and COPYING.RUNTIME respectively.  If not, see        --
-- <http://www.gnu.org/licenses/>.                                          --
------------------------------------------------------------------------------

with Ada.Tags; use Ada.Tags;

with TGen.Numerics;             use TGen.Numerics;
with TGen.Random;               use TGen.Random;
with TGen.Strings;              use TGen.Strings;
with TGen.Types.Discrete_Types; use TGen.Types.Discrete_Types;

package body TGen.Types.Array_Types is

   use TGen.Types.SP;

   function Image (Self : Unconstrained_Array_Typ) return String is
      Res : Unbounded_String :=
        To_Unbounded_String (Typ (Self).Image & " : array (");
   begin
      for J in Self.Index_Types'Range loop
         if Self.Index_Types (J) /= SP.Null_Ref then
            Res := Res & Typ (Self.Index_Types (J).Get.Element.all).Image;
         else
            Res := Res & "null type ..";
         end if;
         if J /= Self.Index_Types'Last then
            Res := Res & " range <>, ";
         else
            Res := Res & " range <>) ";
         end if;
      end loop;
      Res := Res & "of " & Self.Component_Type.Get.Image;
      return To_String (Res);
   end Image;

   function Image (Self : Constrained_Array_Typ) return String is
      Res : Unbounded_String :=
        To_Unbounded_String (Typ (Self).Image & " : array (");
   begin
      for J in Self.Index_Types'Range loop
         if Self.Index_Types (J) /= SP.Null_Ref then
            Res := Res & Typ (Self.Index_Types (J).Get.Element.all).Image;
            if Self.Index_Constraints (J).Present
              and then Self.Index_Constraints (J)
                       .Discrete_Range.Low_Bound.Kind = Static
              and then Self.Index_Constraints (J)
                       .Discrete_Range.High_Bound.Kind = Static
            then
               Res :=
                 Res & " range "
                 & As_Discrete_Typ (Self.Index_Types (J)).Lit_Image
                     (Self.Index_Constraints (J).Discrete_Range.Low_Bound
                      .Int_Val)
                 & " .. "
                 & As_Discrete_Typ (Self.Index_Types (J)).Lit_Image
                     (Self.Index_Constraints (J).Discrete_Range.High_Bound
                      .Int_Val);
            end if;
         else
            Res := Res & "null type ..";
         end if;

         if J /= Self.Index_Types'Last then
            Res := Res & ", ";
         else
            Res := Res & ") ";
         end if;
      end loop;
      Res := Res & "of " & (if Self.Component_Type /= SP.Null_Ref
                            then Self.Component_Type.Get.Image
                            else "null type ..");
      return To_String (Res);
   end Image;

   type Data_Type is null record;

   type Size_Interval is record
      Min_Size, Max_Size : Natural;
   end record;

   type Size_Interval_Array is array (Natural range <>) of Size_Interval;
   type Nat_Array is array (Natural range <>) of Natural;

   generic
      type Element_Type is private;
      with function Generate_Value (Data : Data_Type) return Element_Type;
   package Array_Generation_Package is
      type Array_Type is array (Positive range <>) of Element_Type;

      type Array_Strategy_Type (Dimensions : Natural) is tagged record
         Size_Intervals : Size_Interval_Array (1 .. Dimensions);
         Average_Sizes  : Nat_Array (1 .. Dimensions);
      end record;

      function Array_Strategy
        (Size_Intervals : Size_Interval_Array) return Array_Strategy_Type;

      function Draw
        (Self : Array_Strategy_Type;
         Data : Data_Type;
         Dimension_Sizes : out Nat_Array) return Array_Type;

   end Array_Generation_Package;

   package body Array_Generation_Package is

      --------------------
      -- Array_Strategy --
      --------------------

      function Array_Strategy
        (Size_Intervals : Size_Interval_Array) return Array_Strategy_Type
      is
         Result : Array_Strategy_Type (Size_Intervals'Length);
         Average_Sizes : Nat_Array (Size_Intervals'Range);
      begin
         Result.Size_Intervals := Size_Intervals;
         for I in Size_Intervals'Range loop
            declare
               Min_Size : constant Natural := Size_Intervals (I).Min_Size;
               Max_Size : constant Natural := Size_Intervals (I).Max_Size;
            begin
               Average_Sizes (I) :=
                 Natural'Min (Natural'Max (Min_Size * 2, Min_Size + 5),
                              Natural (0.5 * Float (Min_Size + Max_Size)));
            end;
         end loop;
         Result.Average_Sizes := Average_Sizes;
         return Result;
      end Array_Strategy;

      function Draw
        (Self : Array_Strategy_Type;
         Data : Data_Type;
         Dimension_Sizes : out Nat_Array) return Array_Type is
         Arr_Length : Natural := 0;
      begin

         --  Determine length of each dimension

         for I in 1 .. Self.Dimensions loop
            declare
               Elements    : Many_Type :=
                 Many
                   (Self.Size_Intervals (I).Min_Size,
                    Self.Size_Intervals (I).Max_Size,
                    Self.Average_Sizes (I));
            begin
               while Elements.More loop
                  null;
               end loop;
               Dimension_Sizes (I) := Elements.Count;
            end;
         end loop;

         --  Now that we have the length of each dimension, fill the array
         --  with elements. TODO: We should probably not generate a random
         --  value for each, but pick a background value and generate a handful
         --  of random values, as done in Hypothesis.

         if Dimension_Sizes'Length > 0 then
            Arr_Length := 1;
            for Dim_Size of Dimension_Sizes loop
               Arr_Length := Arr_Length * Dim_Size;
            end loop;
         end if;

         declare
            Arr : Array_Type (1 .. Arr_Length);
         begin
            for I in 1 .. Arr_Length loop
               Arr (I) := Generate_Value (Data);
            end loop;
            return Arr;
         end;
      end Draw;

   end Array_Generation_Package;

   generic
      type Element_Type is private;
      type Index_Type_1 is (<>);
      type Array_Type is array (Positive range <>) of Element_Type;
      type Reshaped_Array_Type is array (Index_Type_1 range <>)
        of Element_Type;

   function Reshape_1
     (Arr : Array_Type) return Reshaped_Array_Type;

   ---------------
   -- Reshape_1 --
   ---------------

   function Reshape_1
     (Arr : Array_Type) return Reshaped_Array_Type
   is
      Res : Reshaped_Array_Type
        (Index_Type_1'First .. Index_Type_1'Val (Arr'Last));
      I : Index_Type_1 := Index_Type_1'First;
   begin
      for Orig in Arr'Range loop
         Res (I) := Arr (Orig);
         I := Index_Type_1'Succ (I);
      end loop;
      return Res;
   end Reshape_1;

   generic
      type Element_Type is private;
      type Index_Type_1 is (<>);
      type Index_Type_2 is (<>);
      type Array_Type is array (Positive) of Element_Type;
      type Reshaped_Array_Type is array
        (Index_Type_1 range <>, Index_Type_2 range <>)
        of Element_Type;

   function Reshape_2
     (Arr  : Array_Type;
      Dim1 : Positive) return Reshaped_Array_Type;

   pragma Unreferenced (Reshape_2);

   ---------------
   -- Reshape_2 --
   ---------------

   function Reshape_2
     (Arr  : Array_Type;
      Dim1 : Positive) return Reshaped_Array_Type
   is
      Res : Reshaped_Array_Type
        (Index_Type_1'First .. Index_Type_1'Val (Arr'Last / Dim1),
         Index_Type_2'First .. Index_Type_2'Val (Arr'Last mod Dim1));
      I : Index_Type_1 := Index_Type_1'First;
      J : Index_Type_2 := Index_Type_2'First;
   begin
      for Orig in Arr'Range loop
         Res (I, J) := Arr (Orig);
         J := Index_Type_2'Succ (J);
         if Orig mod Dim1 = 0 then
            I := Index_Type_1'Succ (I);
            J := Index_Type_2'First;
         end if;
      end loop;
      return Res;
   end Reshape_2;

   function Length
     (I_Constraint : TGen.Types.Constraints.Index_Constraint;
      I_Type       : SP.Ref;
      Disc_Context : Disc_Value_Map) return Big_Integer;
   --  Returns the length of the array from its Index_Constraint

   function Generate_Static_Common
     (Self         : Array_Typ'Class;
      Disc_Context : Disc_Value_Map;
      Constrained  : Boolean;
      Constraints  : Index_Constraint_Arr;
      Generate_Element_Strat : in out Static_Strategy_Type'Class)
      return Static_Value'Class;

   package Big_Integer_Conversion is new Big_Int.Signed_Conversions (Natural);

   function "+" (BI : Big_Integer) return Natural renames
     Big_Integer_Conversion.From_Big_Integer;

   ------------
   -- Length --
   ------------

   function Length
     (I_Constraint : TGen.Types.Constraints.Index_Constraint;
      I_Type       : SP.Ref;
      Disc_Context : Disc_Value_Map) return Big_Integer

   is
      function Constraint_Value
        (Constraint : Discrete_Constraint_Value) return Big_Integer is
        (case Constraint.Kind is
            when Static =>
               Constraint.Int_Val,
            when Discriminant =>
               Disc_Context.Element (Constraint.Disc_Name),
            when others =>
               raise Program_Error with
                 "Dynamic constraint unsupported for static generation");

      use type Big_Integer;
      LB, HB : Big_Integer;
   begin
      if I_Constraint.Present then
         HB := Constraint_Value (I_Constraint.Discrete_Range.High_Bound);
         LB := Constraint_Value (I_Constraint.Discrete_Range.Low_Bound);
      else
         LB := As_Discrete_Typ (I_Type).Low_Bound;
         HB := As_Discrete_Typ (I_Type).High_Bound;
      end if;
      return HB - LB + 1;
   end Length;

   ----------------------------
   -- Generate_Static_Common --
   ----------------------------

   function Generate_Static_Common
     (Self         : Array_Typ'Class;
      Disc_Context : Disc_Value_Map;
      Constrained  : Boolean;
      Constraints  : Index_Constraint_Arr;
      Generate_Element_Strat : in out Static_Strategy_Type'Class)
      return Static_Value'Class
   is
      function Generate_Component_Wrapper
        (Data : Data_Type with Unreferenced) return Unbounded_String is
          (+Generate_Element_Strat.Generate_Static_Value
             (Disc_Context).To_String);

      Res : Unbounded_String;

      --  Let's use the somewhat generic Array_Strategy capabilities here,
      --  and pick a Min_Size of 0 and a Max_Size of (10 ** Nb_Dim). We will
      --  generate flattened arrays, that we will then reshape to fit the
      --  wanted dimensions.

      Data : Data_Type;

      package Array_Generation_Static is new Array_Generation_Package
        (Element_Type   => Unbounded_String,
         Generate_Value => Generate_Component_Wrapper);

      use Array_Generation_Static;

      type Expected_Array_Type is array (Natural range <>) of Unbounded_String;

      function Reshape is new Reshape_1
        (Element_Type => Unbounded_String,
         Index_Type_1 => Natural,
         Array_Type   => Array_Type,
         Reshaped_Array_Type => Expected_Array_Type);

      pragma Unreferenced (Reshape);

      Sizes : constant Size_Interval_Array :=
        [for I in 1 .. Self.Num_Dims =>
            (if not Constrained then
                 (Min_Size => Unconstrained_Array_Size_Min,
                  Max_Size => Unconstrained_Array_Size_Max)
            else
               (Min_Size => +Length
                 (Constraints (I), Self.Index_Types (I), Disc_Context),
                Max_Size => +Length
                  (Constraints (I), Self.Index_Types (I), Disc_Context)))];

      Strat : constant Array_Strategy_Type := Array_Strategy (Sizes);

      Dimension_Sizes : Nat_Array (1 .. Self.Num_Dims);

      Random_Arr : constant Array_Type := Strat.Draw (Data, Dimension_Sizes);

      procedure Pp_Arr
        (Arr   : Array_Type;
         Index : in out Positive;
         Sizes : Nat_Array);

      ------------
      -- Pp_Arr --
      ------------

      procedure Pp_Arr
        (Arr   : Array_Type;
         Index : in out Positive;
         Sizes : Nat_Array)
      is
      begin
         if Sizes'Length = 0 then
            raise Program_Error with "Array dimension can't be 0";
         end if;

         Append (Res, "[");
         for I in 1 .. Sizes (Sizes'First) loop
            if Sizes'Length = 1 then
               Append (Res, +Arr (Index));
               Index := @ + 1;
            else
               Pp_Arr (Arr, Index, Sizes (Sizes'First + 1 .. Sizes'Last));
            end if;
            Append (Res, ", ");
         end loop;
         Res := Remove_Trailing_Comma_And_Spaces (Res);
         Append (Res, "]");
      end Pp_Arr;

      procedure Pp_Arr_Wrapper (Arr : Array_Type; Sizes : Nat_Array);

      procedure Pp_Arr_Wrapper (Arr : Array_Type; Sizes : Nat_Array) is
         Ignore : Positive := 1;
      begin
         Pp_Arr (Arr, Ignore, Sizes);
      end Pp_Arr_Wrapper;

   begin
      if Self.Num_Dims > 2 then
         raise Program_Error with "Dimension not supported";
      end if;

      Pp_Arr_Wrapper (Random_Arr, Dimension_Sizes);

      return Base_Static_Value'(Value => Res);
   end Generate_Static_Common;

   type Array_Static_Strategy_Type is new Static_Strategy_Type with
      record
         T : SP.Ref;
         Generate_Element_Strategy : Static_Strategy_Acc;
         F : access function
           (Self         : Array_Typ'Class;
            Disc_Context : Disc_Value_Map;
            Constrained  : Boolean;
            Constraints  : Index_Constraint_Arr;
            Generate_Element_Strat : in out Static_Strategy_Type'Class)
         return Static_Value'Class;
      end record;

   overriding function Generate_Static_Value
     (S            : in out Array_Static_Strategy_Type;
      Disc_Context : Disc_Value_Map) return Static_Value'Class;

   function Generate_Static_Value
     (S            : in out Array_Static_Strategy_Type;
      Disc_Context : Disc_Value_Map) return Static_Value'Class
   is
      T_Classwide : constant Typ'Class := S.T.Get;
   begin
      --  TODO: refactor that code

      if T_Classwide'Tag = Constrained_Array_Typ'Tag then
         declare
            T : constant Constrained_Array_Typ :=
              Constrained_Array_Typ (T_Classwide);
         begin
            return S.F
              (T,
               Disc_Context,
               True,
               T.Index_Constraints,
               S.Generate_Element_Strategy.all);
         end;
      elsif T_Classwide'Tag = Unconstrained_Array_Typ'Tag then
         declare
            T : constant Unconstrained_Array_Typ :=
              Unconstrained_Array_Typ (T_Classwide);
            No_Constraints : Index_Constraint_Arr (2 .. 1);
         begin
            return S.F
              (T,
               Disc_Context,
               False,
               No_Constraints,
               S.Generate_Element_Strategy.all);
         end;
      else
         return raise Program_Error with
           "Expecting an array type but got a "
           & Expanded_Name (T_Classwide'Tag);
      end if;

   end Generate_Static_Value;

   ---------------------
   -- Generate_Static --
   ---------------------

   function Generate_Static
     (Self    : Array_Typ;
      Context : in out Generation_Context) return Static_Strategy_Type'Class
   is
      Strat : Array_Static_Strategy_Type;
      Element_Strategy : constant Static_Strategy_Type'Class :=
        Self.Component_Type.Get.Generate_Static (Context);
   begin
      Context.Strategies.Include (Element_Strategy);
      Strat.Generate_Element_Strategy :=
        new Basic_Static_Strategy_Type'
          (Basic_Static_Strategy_Type
             (Strategy_Sets.Element
                (Context.Strategies.Find (Element_Strategy))));
      SP.From_Element (Strat.T, Self'Unrestricted_Access);
      Strat.F := Generate_Static_Common'Access;
      return Strat;
   end Generate_Static;

end TGen.Types.Array_Types;
