with Libadalang.Analysis; use Libadalang.Analysis;
with LAL_UL.Command_Lines; use LAL_UL.Command_Lines;
with LAL_UL.Tools; use LAL_UL.Tools;

private with Ada.Containers.Hashed_Sets;
private with Langkit_Support.Vectors;
private with Langkit_Support.Slocs;
private with Libadalang.AST;
private with Libadalang.AST.Types;
private with METRICS.Command_Lines;
private with METRICS.Line_Counting;
private with LAL_UL.Generic_Symbols;
private with LAL_UL.Symbols;

package METRICS.Actions is

   type Metrics_Tool is new Tool_State with private;

   overriding procedure Init (Tool : in out Metrics_Tool; Cmd : Command_Line);
   overriding procedure Per_File_Action
     (Tool : in out Metrics_Tool;
      Cmd : Command_Line;
      File_Name : String;
      Unit : Analysis_Unit);
   overriding procedure Final (Tool : in out Metrics_Tool; Cmd : Command_Line);
   overriding procedure Tool_Help (Tool : Metrics_Tool);

private

   use Langkit_Support;
   use Libadalang.AST;
   use Libadalang.AST.Types;
   use METRICS.Command_Lines;
   use METRICS.Line_Counting;

   use LAL_UL.Symbols;
   subtype Symbol is LAL_UL.Symbols.Symbol;

   package CU_Symbols is new LAL_UL.Generic_Symbols;
   use CU_Symbols;
   subtype CU_Symbol is CU_Symbols.Symbol;
   subtype CU_Symbol_Index is CU_Symbols.Symbol_Index;
   --  The name of a compilation unit

   package CU_Symbol_Sets is new Ada.Containers.Hashed_Sets
     (CU_Symbol, Hash_Symbol, Equivalent_Elements => Case_Insensitive_Equal);
   use CU_Symbol_Sets;

   type Metrics_Values is array (Metrics_Enum) of Metric_Nat;

   type Metrix;
   type Metrix_Ref is access all Metrix;

   package Metrix_Vectors is new Langkit_Support.Vectors (Metrix_Ref);
   use Metrix_Vectors;

   Null_Kind : constant Ada_Node_Type_Kind := 0;

   type Fine_Kind is
   --  This is an enumeration of all the node kinds that we collect metrics
   --  for. It is "finer" than Ada_Node_Type_Kind in the sense that procedures
   --  and functions get their own kinds (instead of being lumped together as
   --  subprograms). The names of these are chosen so that the 'Image can be
   --  used to compute the string to be printed (e.g., Generic_Package_Knd
   --  prints as "generic package").
     (No_Such_Knd,
      Generic_Package_Knd,
      Package_Body_Knd,
      Package_Knd,
      Protected_Body_Knd,
      Protected_Object_Knd,
      Protected_Type_Knd,
      Entry_Body_Knd,
      Procedure_Body_Knd,
      Function_Body_Knd,
      Task_Body_Knd,
      Task_Object_Knd,
      Task_Type_Knd,
      Function_Instantiation_Knd,
      Package_Instantiation_Knd,
      Procedure_Instantiation_Knd,
      Generic_Package_Renaming_Knd,
      Generic_Procedure_Renaming_Knd,
      Generic_Function_Renaming_Knd,
      Generic_Procedure_Knd,
      Generic_Function_Knd,
      Package_Renaming_Knd,
      Procedure_Knd,
      Function_Knd,
      Expression_Function_Knd);

   --  Overall processing:
   --
   --  Init is called first. It creates a Metrix for global information (about
   --  all files).
   --
   --  Per_File_Action is called for each file. It creates a Metrix for the
   --  file, and for each relevant unit within the file. Metrics are computed,
   --  but not printed. We compute all metrics, whether or not they were
   --  requested on the command line. The commmand line options control which
   --  metrics are printed.
   --
   --  Final is called. At this point, we have a tree of Metrix. The root is
   --  the all-files/global one. Children of that are per-file Metrix. Children
   --  of those are library unit and subunit Metrix. Children of those are for
   --  more-nested units. Final walks this tree and prints out all the metrics.
   --
   --  Thus, all metrics are computed before any are printed. This is necessary
   --  for coupling metrics, so it seems simplest to do it always.
   --
   --  The libadalang trees are destroyed after processing each file.
   --  Therefore, the Node component of Metrix cannot be used during printing.
   --  Any information from Node that is needed during printing must be copied
   --  into other components of Metrix. Hence the seemingly-redundant
   --  components like Kind and Sloc, below.

   type Metrix (Kind : Ada_Node_Type_Kind) is record
      Node : Ada_Node := null;
      --  Node to which the metrics are associated, except for Metrix_Stack[0],
      --  which has Node = null. Node is used only while gathering metrics; it
      --  is not used while printing metrics.

      --  The Kind discriminant is equal to Node.Kind, or Null_Kind for
      --  Metrix_Stack[0].

      Knd : Fine_Kind;
      --  Finer-grained version of Kind

      Sloc : Slocs.Source_Location_Range;
      --  Equal to the Sloc of Node

      Is_Private_Lib_Unit : Boolean;
      --  True if this is a private library unit

      Visible : Boolean := False;
      --  True if the node is public as defined by gnatmetric -- not nested in
      --  any body or private part. Used for Contract_Complexity, which should
      --  be displayed only for public subprograms. (The other contract metrics
      --  are also displayed only for public subprograms, but they use a
      --  different mechanism.)

      Vals : Metrics_Values :=
        (Complexity_Statement |
         Complexity_Cyclomatic |
         Complexity_Essential |
         Contract_Complexity => 1,
         others => 0);

      Has_Complexity_Metrics : Boolean := False;
      --  True if complexity metrix should be computed for Node (assuming it's
      --  requested on the command line).

      Text_Name : Symbol;
      --  Name of the unit, as printed in text output
      XML_Name : Symbol;
      --  Name of the unit, as printed in XML output
      LI_Sub : Symbol;
      --  For the outermost unit, this is a string indicating whether the unit
      --  is a subunit or a library unit. For other units, this is the empty
      --  string.
      --  Above symbols are undefined for Metrix_Stack[0].

      Submetrix : Metrix_Vectors.Vector;
      --  Metrix records for units nested within this one

      case Kind is
         when Compilation_Unit_Kind =>
            Is_Spec : Boolean;

            CU_Name : CU_Symbol;
            --  Name of this compilation unit

            Depends_On : CU_Symbol_Sets.Set;
            --  Names of compilation units this one directly depends
            --  upon. We're working with names here, because we don't
            --  have semantic information. We use a set so that
            --  redundancies don't count (e.g. "with X; with X;"
            --  should count as depending on X (once)).

            Source_File_Name : String_Ref := null;

            Num_With_Complexity : Metric_Nat := 0;
            --  Number of descendants for which complexity metrics apply

         when Package_Body_Kind =>
            Statements_Sloc : Slocs.Source_Location_Range;
            --  For a package body with statements, this is their location.
            --  Undefined if there are no statements.

         when others =>
            null;
      end case;
   end record;

   type Metrics_Tool is new Tool_State with record
      Metrics_To_Compute : Metrics_Set;
      --  Metrics requested on via command line args

      Metrix_Stack : Metrix_Vectors.Vector;
      --  Metrix_Stack[0] is the global Metrix (totals for all files).
      --
      --  Metrix_Stack[1] is the Metrix for the Compilation_Unit node.
      --  This is for per-file metrics. Note that lalmetric does not
      --  yet support multiple compilation units per file.
      --
      --  Metrix_Stack[2] is the Metrix for the library item within that; this
      --  is a Package_Decl, Package_Body, or whatever node.
      --
      --  The rest are Metrix for the nested nodes that are "eligible" for
      --  computing metrics. These nodes are [generic] package specs, single
      --  task/protected declarations, task/protected type declarations, and
      --  proper bodies other than entry bodies.
      --
      --  This stack contains the relevant nodes currently being processed by
      --  the recursive walk. It is used while computing the metrics; printing
      --  the metrics walks the tree formed by Submetrix.
   end record;

   --  Init is called once, before processing any files. It pushes
   --  Metrix_Stack[0].
   --
   --  Then for each file, we walk the tree, pushing and popping the
   --  Metrix_Stack as we go. When we push a Metrix, we append it to
   --  the Submetrix of its parent, so when we're done walking the
   --  tree, the Metrix form a tree as well.
   --
   --  At each node, we increment relevant Vals, depending on the kind
   --  of node. For example, if we see a node that is a statement, we
   --  increment all the Vals(Statements) of all the Metrix in Metrix
   --  stack. Thus Vals(Statements) for a unit will include the number
   --  of statement in nested units, and Metrix_Stack[0].Vals(Statements)
   --  will contain to total number of statements in all files.
   --
   --  Final is called once, after processing all files. It prints out
   --  the totals for all files that have been computed in
   --  Metrix_Stack[0].
   --
   --  We always compute all metrics. The metrics requested on the
   --  command line are taken into account when we print the data.

end METRICS.Actions;
