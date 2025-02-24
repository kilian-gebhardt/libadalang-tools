------------------------------------------------------------------------------
--                                                                          --
--                                  TGen                                    --
--                                                                          --
--                        Copyright (C) 2023, AdaCore                       --
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

with Ada.Text_IO; use Ada.Text_IO;

package TGen.Marshalling.JSON_Marshallers is

   procedure Generate_Marshalling_Functions_For_Typ
     (F_Spec, F_Body     : File_Type;
      Typ                : TGen.Types.Typ'Class;
      Templates_Root_Dir : String);
   --  Generate JSON marshalling and unmarshalling functions for Typ. Note that
   --  this function will not operate recursively. It will thus have to be
   --  called for each of the component type of a record for instance.
   --
   --  We generate the following functions:
   --
   --  function TAGAda_Marshalling_Typ_Output
   --    (TAGAda_Marshalling_V : Typ) return TGen.JSON.JSON_Value;
   --
   --  function TAGAda_Marshalling_Typ_Input
   --    (TAGAda_Marshalling_JSON : TGen.JSON.JSON_Value)
   --    return Typ;
   --
   --  Templates_Root_Dir should be the path to the root directory in which all
   --  TGen templates are stored.
   --
   --  TODO: right now, this also needs the binary marshallers to have been
   --  generated before, as we need the header type (for unconstrained type)
   --  that they generate. This should be splitted from the generation of
   --  binary marshallers.
   --
   --  TODO???: we produce a JSON with metadata to actually be able to unparse
   --  an Ada literal value from it. This should be configured through a
   --  parameter passed to the marshallers as it makes the JSON bigger.

   procedure Generate_TC_Serializers_For_Subp
     (F_Spec, F_Body     : File_Type;
      FN_Typ             : TGen.Types.Typ'Class;
      Templates_Root_Dir : String) with
      Pre => FN_Typ.Kind = Function_Kind;
   --  Generate a test-case serializer for FN_Typ:
   --
   --  This generates a procedure, with the same parameters as the subprogram
   --  represented by FN_Typ in addition to an "Origin" parameter and a
   --  "JSON_Unit" parameter. The latter may contain tests for this subprogram,
   --  or other subprograms of the same unit, and the generated procedure will
   --  add a new testcase in "JSON_Unit" from the values passed to the first
   --  parameters.
   --
   --  The generated procedure also has a Origin parameter which can be used
   --  to specify which tool produced the test case.

end TGen.Marshalling.JSON_Marshallers;
