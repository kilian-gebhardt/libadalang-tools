------------------------------------------------------------------------------
--                                                                          --
--                             Libadalang Tools                             --
--                                                                          --
--                      Copyright (C) 2022-2023, AdaCore                    --
--                                                                          --
-- Libadalang Tools  is free software; you can redistribute it and/or modi- --
-- fy  it  under  terms of the  GNU General Public License  as published by --
-- the Free Software Foundation;  either version 3, or (at your option) any --
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
--
--  JSON output tool

with Lint.Tools.Record_Components_Tool;
with Lint.Tools.Array_Aggregates_Tool;
with Lint.Tools.Suppress_Dead_Params_Tool;
with Lint.Tools.Scope_Declarations_Tool;
with Lint.Tools.Relocate_Decls_Tool;
with VSS.Text_Streams;

package Output is

   procedure JSON_Serialize
     (Edits_Info : Lint.Tools.Array_Aggregates_Tool.Aggregate_Edits;
      Stream     : in out VSS.Text_Streams.Output_Text_Stream'Class);

   procedure JSON_Serialize
     (Edits_Info : Lint.Tools.Record_Components_Tool.Delete_Infos;
      Stream     : in out VSS.Text_Streams.Output_Text_Stream'Class);

   procedure JSON_Serialize
     (Edits_Info : Lint.Tools.Suppress_Dead_Params_Tool.Edit_Infos;
      Stream     : in out VSS.Text_Streams.Output_Text_Stream'Class);

   procedure JSON_Serialize
     (Edits_Info : Lint.Tools.Scope_Declarations_Tool.Modify_Info;
      Stream     : in out VSS.Text_Streams.Output_Text_Stream'Class);

   procedure JSON_Serialize
     (Edits_Info : Lint.Tools.Relocate_Decls_Tool.Modify_Info;
      Stream     : in out VSS.Text_Streams.Output_Text_Stream'Class);

end Output;
