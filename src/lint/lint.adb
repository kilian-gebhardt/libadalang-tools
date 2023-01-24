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

with Ada.Strings.Fixed;

package body Lint is

   ------------------
   -- Log_Progress --
   ------------------

   procedure Log_Progress
     (Current  : Natural;
      Total    : String;
      Message  : String)
   is
      Total_Length       : constant Natural := Total'Length;
      Current_Image      : constant String :=
        Ada.Strings.Fixed.Tail
          (Ada.Strings.Fixed.Trim (Current'Image, Ada.Strings.Both),
           Total_Length,
           '0');
   begin
      Logger.Trace ("[" & Current_Image & "/" & Total & "] " & Message);
   end Log_Progress;

begin
   GNATCOLL.Traces.Parse_Config_File;
end Lint;
