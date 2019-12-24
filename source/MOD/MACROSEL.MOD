IMPLEMENTATION MODULE MacroSelect;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software

---------------------------------------------------------------------------*)


(* Largely a copy of FilterSelect *)
    (*
    05-Nov-88 LVK   Changed SelectMacroName to use MacroNode.
    13-Nov-89 RSC - Import from Space rather than Storage.
    14-Dec-89 MWP   Added checking for existence of rodents.
    27-Dec-89  LAA  Removed the Ok button, since double-clicking now does
                    the same thing.
     5-Jan-90 MWP   Put the Ok button back in.
    23-Jan-91 RSC   Remove holder reference (unused).
    *)


FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskFilter;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute, DrawBox;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState, DisplayTheChart;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, FatalError, Burp, Error;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  GetNextEvent;

(*<NORMAL*)
FROM MacroOutlines         IMPORT
    (* TYPE *)                  AMacroOutline,
    (* PROC *)                  CreateMacroOutline;
(*NORMAL>*)

FROM MacNodes              IMPORT MacroTree, AMacroRecordPointer;

FROM MacrosRc              IMPORT
    (* VAR *)                   GetMacroName,
    (* PROC *)                  CreateMacro, DeleteMacro, SortMacros,
                                MacroDefaults, FindMacroByName;

FROM MacTalk                IMPORT
                                MacDeath;

FROM   Mouse        IMPORT
    (* PROC *)          MousePresent;                               (* 14-Dec-89 MWP *)

FROM Kbio                   IMPORT
                                SetCursorType, ACursorType, maxrow,
    (* TYPE *)                  ascreeny, ascreenx, avidmode, PutString;

FROM Keys                   IMPORT
    (* CONST *)                 DoIt, CancelKey, ExitKey, InsertKey, DeleteKey,
                                EditKey, BackSpace, CopyKey;

FROM LStrings               IMPORT
    (* PROC *)                  SubStr, Fill, Compare, TrimRear, LJust, Copy,
                                ConcatLS, TrimFront, Upshift, Remove, Search,
                                Procustes, SetLengthOf, SetString;
(*
FROM Menus                  IMPORT
    (* PROC *)                  NoYes;
*)

FROM MsgFile                IMPORT
                                GetMessage;

FROM Rugs                   IMPORT
                                ARug, GetRug, PutRug;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  TSIZE;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTree;

CONST
    MAXCARDINAL             = 0FFFFH;
    ModuleNumber            = 17101;




(*<NORMAL*)


(*----------------------------------------------------------------------------
    LJustAndTrimRear --

    Copy the source to the destination, the LJust and TrimRear the dest.
----------------------------------------------------------------------------*)
(*
PROCEDURE LJustAndTrimRear(VAR Source       : ARRAY OF CHAR;       (* in     *)
                           VAR Dest         : ARRAY OF CHAR);      (*    out *)

BEGIN                       (* LJustAndTrimRear *)

    Copy (Source, Dest);
    LJust(Dest);
    TrimRear(Dest);

END LJustAndTrimRear;
*)





(*NORMAL>*)










(*----------------------------------------------------------------------------
    SelectMacroName --

    Display a picklist of macro names, with the cursor initially on the one
    passed into Selected, and allow the user to select a name.  Selected will
    be changed only if something is selected, and TRUE will be returned.  The
    edit key will allowed only if AllowEdit is TRUE.
----------------------------------------------------------------------------*)

PROCEDURE SelectMacroName(     ULX          : ascreenx;            (* in     *)
                               ULY          : ascreeny;            (* in     *)
                               LRX          : ascreenx;            (* in     *)
                               LRY          : ascreeny;            (* in     *)
                               Title        : ARRAY OF CHAR;
                           VAR SelectedName : ARRAY OF CHAR)       (* in/out *)
                                                            : BOOLEAN;

(*<NORMAL*)

VAR
    MacroOutline            : AMacroOutline;
    MacroRecordPointer      : AMacroRecordPointer;
    MacroNode               : ATreeNode;
    s                       : ARRAY [0..80] OF CHAR;
    title2                  : ARRAY [0..20] OF CHAR;
    Node                    : ATreeNode;
    FirstMacro              : ATreeNode;
    Event                   : AnEvent;
    DescRug                 : ARug;
    LocalBoxType            : ABoxType;
    macroname,
    blank                   : ARRAY [0..41] OF CHAR;
    Selected                : BOOLEAN;

(*NORMAL>*)

    (* Fills the description box *)

    PROCEDURE ShowInfo (VAR Node : ATreeNode);
    BEGIN
      IF Node <> NIL THEN
        MacroRecordPointer := Node^.Methods^.LockFlexStorDataObject (Node);
        PutString (MacroRecordPointer^.hotkeystr, 3, maxrow - 4, videonormal);
        PutString ( MacroRecordPointer^.description, 3, maxrow - 3, videonormal);
        Node^.Methods^.UnlockUnchangedDataObject (Node);
      END;
    END ShowInfo;



    (* Clears the description box *)

    PROCEDURE ClearInfo;
    VAR
         str : ARRAY [0..73] OF CHAR;
    BEGIN
         Fill (str, " ", 73);
         PutString (str, 3, maxrow - 4, videonormal);
         PutString (str, 3, maxrow - 3, videonormal);
    END ClearInfo;


BEGIN                       (* SelectMacroName *)

    (* this block puts the macro description box at bottom of screen *)
    
    IF NOT GetRug (1, maxrow - 5, 78, maxrow - 1, DescRug) THEN
      FatalError;
    END;

    GetMessage (26467, title2);
    DrawBox (1, maxrow - 5, 78, maxrow - 1,
              ABoxType{ShadowBox, DoubleBox},
              title2, videonormal);

    (*SortMacros();*)
    Event.EventCode := 0;
    GetMessage (26468, Title);
    
    SetString (blank, " ");
    Procustes (blank, 40);

    IF ( MousePresent () ) THEN                                  (* 14-Dec-89 MWP *)
      LocalBoxType := ABoxType{ShadowBox,DoubleBox,HasOk,HasCancel,HasVScroll };  (* 5-Jan-89 MWP *)
    ELSE
      LocalBoxType := ABoxType{ShadowBox,DoubleBox};
    END;


    IF (CreateMacroOutline (MacroOutline, NIL, ULX, ULY, LRX, LRY,
            LocalBoxType,
            videonormal, Title, 0, TRUE)) THEN

        SetCursorType(NoCursor);

        MacroOutline^.Methods^.SetObject (MacroOutline, MacroTree);
        FirstMacro := MacroTree^.Methods^.GetFirst (MacroTree);
        MacroOutline^.Methods^.SetFirst (MacroOutline, FirstMacro);
        (*IF (Selected = NIL) THEN*)
            MacroOutline^.Methods^.SetCursorNode (MacroOutline, FirstMacro);
        (*ELSE
            MacroOutline^.Methods^.SetCursorNode (MacroOutline, Selected);
        END;*)
        MacroOutline^.Methods^.SetCursor (MacroOutline, TRUE);
        MacroOutline^.Methods^.ResetMatching (MacroOutline);
        ShowInfo (FirstMacro);

        LOOP
            MacroOutline^.Methods^.Display (MacroOutline);
            GetNextEvent (Event);
            MacroOutline^.Methods^.ActOnEvent (MacroOutline, Event, Event);
            MacroNode := MacroOutline^.Methods^.GetCursorNode (MacroOutline);

            IF MacroNode <> NIL THEN
              ShowInfo (MacroNode);
            ELSE
              ClearInfo;
            END;
            
            CASE Event.EventCode OF
                0 :;
            |   CancelKey, ExitKey, DoIt :
                    (*Selected :=
                     MacroOutline^.Methods^.GetCursorNode(MacroOutline);*)
                        (* from previous version *)
                        Node :=
                          MacroOutline^.Methods^.GetCursorNode (MacroOutline);
                        IF (Node <> NIL) THEN
                           MacroRecordPointer :=
                              Node^.Methods^.LockFlexStorDataObject (Node);
                           Copy (MacroRecordPointer^.name, SelectedName);
                           Node^.Methods^.UnlockUnchangedDataObject (Node);
                        ELSE
                           Fill (SelectedName, " ", 0);
                        END;
                    EXIT;
            ELSE
                Burp();
            END;
        END;
        MacroOutline^.Methods^.Discard (MacroOutline);
    ELSE
        GetMessage (26469, s);
        Error (s);
        (*DisplayMessage (ModuleNumber);*)  (* "Not enough memory to display list" *)
        Burp ();
    END;

    PutRug (1, 20, 78, 23, DescRug);

    RETURN ((Event.EventCode = DoIt) OR (Event.EventCode = ExitKey));

    (*NORMAL>*)

    (*<GELDED
    RETURN FALSE;
    GELDED>*)

END SelectMacroName;






BEGIN                       (* MacroSelect *)
END MacroSelect.
