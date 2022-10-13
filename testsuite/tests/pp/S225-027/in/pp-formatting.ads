------------------------------------------------------------------------------
--                                                                          --
--                            GNATPP COMPONENTS                             --
--                                                                          --
--                                    Pp                                    --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--                    Copyright (C) 2001-2017, AdaCore                      --
--                                                                          --
-- GNATPP  is free software; you can redistribute it and/or modify it under --
-- terms  of  the  GNU  General  Public  License  as  published by the Free --
-- Software Foundation;  either version 3, or ( at your option)  any  later --
-- version.  GNATCHECK  is  distributed in the hope that it will be useful, --
-- but  WITHOUT  ANY  WARRANTY;   without  even  the  implied  warranty  of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General --
-- Public License for more details.  You should have received a copy of the --
-- GNU General Public License distributed with GNAT; see file  COPYING3. If --
-- not,  go  to  http://www.gnu.org/licenses  for  a  complete  copy of the --
-- license.                                                                 --
--                                                                          --
-- GNATPP is maintained by AdaCore (http://www.adacore.com)                 --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Containers.Bounded_Vectors;
with Ada.Containers.Indefinite_Vectors;

with Libadalang.Analysis;

with Utils.Vectors;
with Utils.Char_Vectors; use Utils.Char_Vectors;
use Utils.Char_Vectors.WChar_Vectors;
with Utils.Symbols;
with Utils.Predefined_Symbols; use Utils.Predefined_Symbols;
with Utils.Command_Lines;
with Pp.Buffers;               use Pp.Buffers;
with Pp.Scanner;

package Pp.Formatting is

   package Syms renames Utils.Symbols;

   Token_Mismatch : exception;
   --  Raised by Tree_To_Ada if it detects a bug in itself that causes the
   --  output tokens to not match the input properly.

   -------------------
   -- Line Breaking --
   -------------------

   type Nesting_Level is new Positive;
   subtype Nesting_Level_Increment is
     Nesting_Level'Base range 0 .. Nesting_Level'Last;

   type Line_Break is record
      Tok      : Scanner.Tokn_Cursor;
      --  Cursor in New_Tokns or Saved_New_Tokns of the Line_Break_Token. These
      --  become invalid as soon as New_Tokns is modified.
      Tokn_Val : Scanner.Token;
      --  This is used to assert that Tok points to the token it originally
      --  did, in order to guard against looking at Tok after it has been
      --  invalidated because the token stream was modified. This can be
      --  removed for better efficiency.

      Hard                      : Boolean;
      --  True for a hard line break, False for a soft one
      Affects_Comments          : Boolean;
      --  True if the indentation of this Line_Break should affect the
      --  indentation of surrounding comments. For example, True for '$' but
      --  False for '$1' (see type Ada_Template).
      Enabled                   : Boolean;
      --  True if this line break will appear in the final output
      Source_Line_Breaks_Kludge : Boolean; -- ????????????????
      Level                     : Nesting_Level := 1_000;
      --  Nesting level of [...] (continuation-line indentation, mainly for
      --  soft line breaks).
      Indentation               : Natural       := 1_000;
      --  Indentation level of this line break
      Length                    : Natural       := Natural'Last;
      --  Number of characters in line, not counting NL. Calculated by
      --  Split_Lines. Valid only for enabled line breaks.

      Internal_To_Comment : Boolean;
      --  True if this is a line break within a block comment
      --  "paragraph". These line breaks appear in Out_Buf, but not in
      --  New_Tokns. We should be able to get rid of this. All other line
      --  breaks, including those jsut before and after such a comment, have
      --  Internal_To_Comment = False.

      --  For debugging:

      --  ????      Kind     : Ada_Tree_Kind;
      --  This is left over from the ASIS-based version. Not clear
      --  whether we should reinstate this debug info.
      UID : Modular := 123_456_789;
   --  Can we use an index into a single table instead of UID???
   end record; -- Line_Break

   type Line_Break_Index is new Positive;
   type Line_Break_Array is array (Line_Break_Index range <>) of Line_Break;
   package Line_Break_Vectors is new Utils.Vectors (Line_Break_Index,
      Line_Break, Line_Break_Array);
   subtype Line_Break_Vector is Line_Break_Vectors.Vector;

   use Line_Break_Vectors;
   --  use all type Line_Break_Vector;

   type Line_Break_Index_Index is new Positive;
   type Line_Break_Index_Array is
     array (Line_Break_Index_Index range <>) of Line_Break_Index;
   package Line_Break_Index_Vectors is new Utils.Vectors
     (Line_Break_Index_Index, Line_Break_Index, Line_Break_Index_Array);
   subtype Line_Break_Index_Vector is Line_Break_Index_Vectors.Vector;
   use Line_Break_Index_Vectors;

   function LB_Tok (LB : Line_Break) return Scanner.Tokn_Cursor;
   --  Returns LB.Tok, with some assertions

   ------------------------
   -- Tabs and Alignment --
   ------------------------

   --  We use "tabs" to implement alignment. For example, if the input is:
   --     X : Integer := 123;
   --     Long_Ident : Boolean := False;
   --     Y : constant Long_Type_Name := Something;
   --  we're going to align the ":" and ":=" in the output, like this:
   --     X          : Integer                 := 123;
   --     Long_Ident : Boolean                 := False;
   --     Y          : constant Long_Type_Name := Something;
   --
   --  A "tab" appears before each ":" and ":=" in the above. This information
   --  is recorded in Tabs, below. The position of the tab in the buffer is
   --  indicated by Insertion_Point. Finally, Insert_Alignment calculates the
   --  Col and Num_Blanks for each tab, and then inserts blanks accordingly.
   --
   --  A tab always occurs at the start of a token.

   type Tab_Index_In_Line is range 1 .. 9;
   --  We probably never have more than a few tabs in a given construct, so 9
   --  should be plenty, and it allows us to use a single digit in the
   --  templates, as in "^2".

   type Tab_Rec is record
      Parent, Tree       : Libadalang.Analysis.Ada_Node;
      --  Tree is the tree whose template generated this tab, and Parent is its
      --  parent. Tree is used to ensure that the relevant tabs within a single
      --  line all come from the same tree; other tabs in the line are ignored.
      --  Parent is used across lines to ensure that all lines within a
      --  paragraph to be aligned together all come from the same parent tree.
      Token              : Syms.Symbol       := Name_Empty;
      --  This is some text associated with the Tab. Usually, it is the text of
      --  the token that follows the Tab in the template.
      Insertion_Point    : Scanner.Tokn_Cursor;
      --  Position in Saved_New_Tokns of the tab token
      Index_In_Line      : Tab_Index_In_Line := Tab_Index_In_Line'Last;
      Col                : Positive          := Positive'Last;
      --  Column number of the tab
      Num_Blanks         : Natural           := 0;
      --  Number of blanks this tab should expand into
      Is_Fake            : Boolean;
      --  True if this is a "fake tab", which means that it doesn't actually
      --  insert any blanks (Num_Blanks = 0). See Append_Tab for more
      --  explanation.
      Is_Insertion_Point : Boolean;
      --  False for "^", true for "&". Normally, "^" means insert blanks at the
      --  point of the "^" to align things. However, if there is a preceding
      --  (and matching) "&", then the blanks are inserted at the "insertion
      --  point" indicated by "&". This feature provides for
      --  right-justification.
      --  See Tree_To_Ada.Insert_Alignment.Calculate_Num_Blanks.Process_Line in
      --  pp-formatting.adb for more information.
      Deleted            : Boolean           := False;
   --  True if this tab has been logically deleted. This happens when a real
   --  tab replaces a fake tab.
   end record;

   type Tab_Index is new Positive;
   type Tab_Array is array (Tab_Index range <>) of Tab_Rec;
   package Tab_Vectors is new Utils.Vectors (Tab_Index, Tab_Rec, Tab_Array);
   subtype Tab_Vector is Tab_Vectors.Vector;

   use Tab_Vectors;
   --  use all type Tab_Vector;

   package Tab_In_Line_Vectors is new Ada.Containers.Bounded_Vectors
     (Tab_Index_In_Line, Tab_Index);
   use Tab_In_Line_Vectors;
   subtype Tab_In_Line_Vector is
     Tab_In_Line_Vectors.Vector
       (Capacity => Ada.Containers.Count_Type (Tab_Index_In_Line'Last));

   type Tab_In_Line_Vector_Index is new Positive;
   package Tab_In_Line_Vector_Vectors is new Ada.Containers.Indefinite_Vectors
     (Tab_In_Line_Vector_Index, Tab_In_Line_Vector);
   --  We use Indefinite_Vectors rather than Vectors because otherwise we get
   --  "discriminant check failed" at a-cobove.ads:371. I'm not sure whether
   --  that's a compiler bug.
   use Tab_In_Line_Vector_Vectors;

   type Lines_Data_Rec is record

      Out_Buf : Buffer;
      --  Buffer containing the text that we will eventually output as the
      --  final result. We first fill this with initially formatted text by
      --  walking the tree, and then we modify it repeatedly in multiple
      --  passes.????????????????

      Cur_Indentation : Natural := 0;

      Next_Line_Break_Unique_Id : Modular := 1;
      --  Used to set Line_Break.UID for debugging.

      --  Each line break is represented by a Line_Break appended onto the
      --  Line_Breaks vector. Hard line breaks are initially enabled. Soft
      --  line breaks are initially disabled, and will be enabled if
      --  necessary to make lines short enough.

      All_LB : Line_Break_Vector;
      --  All the line breaks, in no particular order. The _LBI variables below
      --  are indices into this, always sorted in order by source location.

      All_LBI : Line_Break_Index_Vector;
      --  All line breaks in the whole input file. Built in two passes.

      Temp_LBI : Line_Break_Index_Vector;
      --  Used by Insert_Comments_And_Blank_Lines to add new line breaks to
      --  All_LBI; they are appended to Temp_LBI, which is then merged with
      --  All_LBI when done. This is for efficiency and to keep the tables in
      --  source-location order.

      Enabled_LBI : Line_Break_Index_Vector;
      --  All enabled line breaks
      Syntax_LBI  : Line_Break_Index_Vector;
      --  All (enabled) nonblank hard line breaks. These are called
      --  "Syntax_..."  because they are determined by the syntax (e.g. we
      --  always put a line break after a statement).

      Tabs : Tab_Vector;
      --  All of the tabs in the whole input file, in increasing order

      Src_Tokns, -- from original source file (Src_Buf)
      Out_Tokns : -- from Out_Buf
      aliased Scanner.Tokn_Vec;

      New_Tokns, Saved_New_Tokns : aliased Scanner.Tokn_Vec;
      --  New_Tokns is the new tokens generated by certain phases. To build a
      --  new value of New_Tokns plus some other tokens, we move New_Tokns to
      --  Saved_New_Tokns, loop through Saved_New_Tokns, appending those and
      --  newer ones onto New_Tokns. This ensures that index values pointing
      --  into New_Tokns will be correct after the pass.
      --
      --  Later little-used phases still use Out_Tokns; these could reasonably
      --  be switched to use New_Tokns instead. In any case, both Out_Tokns and
      --  Saved_New_Tokns are temps, used only within a phase, and should be
      --  empty between phases.

      --  Debugging:

      Check_Whitespace : Boolean := True;
   --  Used during the Subtree_To_Ada phase. True except within comments and
   --  literals. Check for two blanks in a row.
   end record; -- Lines_Data_Rec
   type Lines_Data_Ptr is access all Lines_Data_Rec;

   ----------------

   procedure Do_Comments_Only
     (Lines_Data_P : Lines_Data_Ptr; Src_Buf : in out Buffer;
      Cmd          : Utils.Command_Lines.Command_Line);
   --  Implement the --comments-only switch. This skips most of the usual
   --  pretty-printing passes, and just formats comments.

   procedure Post_Tree_Phases
     (Lines_Data_P :     Lines_Data_Ptr;
      Messages : out Scanner.Source_Message_Vector; Src_Buf : in out Buffer;
      Cmd          :     Utils.Command_Lines.Command_Line; Partial : Boolean);
   --  The first pretty-printing pass walks the tree and produces text,
   --  along with various tables. This performs the remaining passes, which
   --  do not make use of the tree.

   procedure Assert_No_Trailing_Blanks (Buf : Buffer);
   --  Assert that there are no lines with trailing blanks in Buf, and that
   --  all space characters are ' ' (e.g. no tabs), and that the last line
   --  is terminated by NL.

   ----------------

   --  Debugging:

   procedure Put_All_Tokens (Message : String; Lines_Data : Lines_Data_Rec);
   --  Dump out all the token sequences

   function Line_Text
     (Lines_Data : Lines_Data_Rec; F, L : Line_Break_Index_Index) return W_Str;
   --  F and L are the first and last index forming a line; returns the text of
   --  the line, not including any new-lines.

   function Tab_Image (Tabs : Tab_Vector; X : Tab_Index) return String;

   procedure Put_Line_Breaks (Lines_Data : Lines_Data_Rec);

   procedure Put_Line_Break (Break : Line_Break);

   procedure Put_LBIs (LBI_Vec : Line_Break_Index_Vector);
   procedure Put_LBs (LB_Vec : Line_Break_Vector);

   procedure Format_Debug_Output
     (Lines_Data : Lines_Data_Rec; Message : String);

   Simulate_Token_Mismatch : Boolean renames Debug_Flag_8;
   Disable_Final_Check     : Boolean renames Debug_Flag_7;
   function Enable_Token_Mismatch return Boolean is
     ((Assert_Enabled or Debug_Flag_5) and not Simulate_Token_Mismatch and
      not Debug_Flag_6);

   procedure Assert_No_LB (Lines_Data : Lines_Data_Rec);
   --  Assert that all the lines-break data is empty

   procedure Put_Char_Vector (Container : Char_Vector);
   procedure Put_WChar_Vector (Container : WChar_Vector);

   ----------------------------------------------------------------
   --
   --  Formatting uses the following major passes. Convert_Tree_To_Ada is in
   --  Pp.Actions. Split_Lines through Final_Check are done by Post_Tree_Phases
   --  above. (***) marks passes that directly modify the output (New_Tokns).
   --
   --  Convert_Tree_To_Ada (***)
   --     Walks the Ada_Tree, using Ada_Templates to convert the tree into
   --     text form in Out_Buf. Out_Buf is further modified by subsequent
   --     passes. Builds the Line_Break table for use by Split_Lines and
   --     Insert_Indentation. Builds the Tabs table for use by
   --     Insert_Alignment.
   --
   --     Subsequent passes work on the text in Out_Buf, and not the
   --     Ada_Tree. Therefore, if they need any syntactic/structural
   --     information, it must be encoded in other data structures, such
   --     as the Line_Breaks and Tabs tables.
   --
   --  Split_Lines (first time)
   --     Determine which soft line breaks should be enabled.
   --
   --  Enable_Line_Breaks_For_EOL_Comments
   --     For all end-of-line comments that occur at a soft line break, enable
   --     the line break.
   --
   --  Insert_Comments_And_Blank_Lines (***)
   --     Step through the source tokens and output tokens. Copy comment and
   --     blank line tokens into the output as they are encountered.
   --
   --  Split_Lines (again)
   --     We do this again because inserted end-of-line comments can cause
   --     lines to be too long. We don't want to split the line just before the
   --     comment; we want to split at some auspicious soft line break(s).
   --
   --  Insert_Indentation (***)
   --     Insert newline characters and leading blanks for each soft line break
   --     that was enabled by Split_Lines. Hard, too????????????????
   --
   --  Insert_Alignment (***)
   --     Walk the Tabs table to calculate how many blanks (if any) should be
   --     inserted for each Tab. Then insert those blanks in Out_Buf.
   --
   --  Keyword_Casing (***)
   --     Convert reserved words to the appropriate case as specified by
   --     command-line options.
   --
   --  Insert_Form_Feeds (***)
   --     Implement the --ff-after-pragma-page switch, by inserting FF
   --     characters after "pragma Page;".
   --
   --  Copy_Pp_Off_Regions (***)
   --     Regions where pretty printing should be turned off have been
   --     formatted as usual. This phase undoes all that formatting by copying
   --     text from Src_Buf to Out_Buf.
   --
   --  Final_Check
   --     Go through the source tokens and Out_Buf tokens (the latter now
   --     containing comments and blank lines), and make sure they (mostly)
   --     match. If there is any mismatch besides a small set of allowed ones,
   --     raise an exception. This pass makes no changes, so it serves no
   --     useful purpose unless there is a bug in some previous pass; the
   --     purpose is to prevent gnatpp from damaging the user's source code.
   --     The algorithm in this pass is quite similar to the one in
   --     Insert_Comments_And_Blank_Lines.
   --
   --  Write_Out_Buf
   --     Write Out_Buf to the appropriate file (or Current_Output).
   --
   --  Each pass expects to be entered with Out_Buf's 'point' at the beginning,
   --  and returns with Out_Buf's 'point' STILL at the beginning. Thus, passes
   --  that step through Out_Buf need to call Reset(Out_Buf) before returning.
   --
   ----------------------------------------------------------------

end Pp.Formatting;
