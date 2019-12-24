IMPLEMENTATION MODULE NetLayouts;

    (*  MODIFICATION HISTORY
        23-Jan-88 LAA   Added NormalLayoutActive, and the DisplayNetworkLight 
                        procedure.
        10-Feb-88 LAA   Got DiscardNetLayout to discard the notes.  Call
                        HeapAvailable before creating a new Net Layout.
       10-Jan-89 RSC    Changed Storage to Space.
        2-Feb-89 RSC    Removed column list.
        3-Feb-89 RSC    Moved registering for notices into InitializeNetLayouts.
        08-Jun-89 EGK   Removed NeedsRecompute, NeedsRedraw,
                        ClearNeedsRecompute, and ClearNeedsRedraw, which
                        were not being used.  Removed TakeNotice procedure
                        and its registering and unregistering.  (Acting
                        on notices is handled in NetDraw.MOD.)
        21-Sep-89 LAA   Removed all reference to Animation.
        25-Sep-89 EGK   Moved CreateNetLayout, DiscardNetLayout, and
                        SortNetLayouts to NetLUtility module.
        30-Mar-90 RSC   Removed Timeu.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
    *)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode;

FROM Lights                 IMPORT
    (* TYPE *)                  ALight,
    (* PROC *)                  DisplayLight;

FROM LStrings               IMPORT
    (* PROC *)                  SetLengthOf, Compare;

FROM MsgFile                IMPORT GetMessage, ConcatMessage, DisplayMessage;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS;

FROM TaskColNumbers         IMPORT
    (* CONST *)                 TaskNameColumn,
                                EarlyStartColumn,
                                EarlyEndColumn;

FROM Text                   IMPORT
    (* TYPE *)                  AText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTree, CreateTreeNode, ValidateTreeNode;


CONST
    ModuleNumber            = 21000;

VAR
    DefaultNormalNetLayout,
    DefaultBigNetLayout     : ANetworkLayout;
    StuffCreated            : BOOLEAN;



PROCEDURE GetNormalNetLayout(): ANetworkLayout;

VAR
    NetLayout               : ANetworkLayout;

BEGIN                       (* GetNormalNetLayout *)

    IF (CurrentNetLayout <> NIL) THEN
        NetLayout := CurrentNetLayout^.Methods^.GetDataObject(CurrentNetLayout);
    ELSE
        NetLayout := DefaultNormalNetLayout;
    END;

    RETURN NetLayout;

END GetNormalNetLayout;




PROCEDURE GetBigNetLayout(): ANetworkLayout;

VAR
    NetLayout               : ANetworkLayout;

BEGIN                       (* GetBigNetLayout *)

    IF (EnlargedNetLayout <> NIL) THEN
        NetLayout := EnlargedNetLayout^.Methods^.GetDataObject(EnlargedNetLayout);
    ELSE
        NetLayout := DefaultBigNetLayout;
    END;

    RETURN NetLayout;

END GetBigNetLayout;




PROCEDURE InitializeNetLayouts();

VAR
    NetLayout               : ANetworkLayout;

BEGIN                       (* InitializeNetLayouts *)

    IF (NOT StuffCreated) THEN

            (* Monitor schedule changes. *)

        IF (NOT CreateTree(NetLayoutTree)) THEN
            FatalError();
        END;

        NEW(DefaultNormalNetLayout);
        WITH DefaultNormalNetLayout^ DO
            SetLengthOf(Name, 0);
            Notes := AText(NIL);
            BoxOutline := TRUE;
            Fields[1].ColumnID := TaskNameColumn;
            Fields[1].ColumnWidth := 8;
            
            Fields[2].ColumnID := 0;
            Fields[3].ColumnID := 0;
            Fields[4].ColumnID := 0;
            Fields[5].ColumnID := 0;
            Fields[6].ColumnID := 0;
            Fields[2].ColumnWidth :=0;  
            Fields[3].ColumnWidth :=0;
            Fields[4].ColumnWidth :=0;
            Fields[5].ColumnWidth :=0;
            Fields[6].ColumnWidth :=0;
            Height := 1;
            Width := 8;
        END;
        
        NEW(DefaultBigNetLayout);
        WITH DefaultBigNetLayout^ DO
            SetLengthOf(Name, 0);
            Notes := AText(NIL);
            BoxOutline := TRUE;
            Fields[1].ColumnID := TaskNameColumn;
            Fields[1].ColumnWidth := 18;
            Fields[2].ColumnID := EarlyStartColumn;
            Fields[2].ColumnWidth :=9;
            Fields[5].ColumnID := EarlyEndColumn;
            Fields[5].ColumnWidth :=9;
            
            Fields[3].ColumnID := 0;
            Fields[4].ColumnID := 0;
            Fields[6].ColumnID := 0;
            Fields[3].ColumnWidth :=0;
            Fields[4].ColumnWidth :=0;
            Fields[6].ColumnWidth :=0;
            Height := 3;
            Width := 18;
        END;
         
        CurrentNetLayout := NIL;
        EnlargedNetLayout := NIL;
        
        StuffCreated := TRUE;
    END;

END InitializeNetLayouts;







PROCEDURE TerminateNetLayouts();

BEGIN                       (* TerminateNetLayouts *)

END TerminateNetLayouts;





PROCEDURE DisplayNetworkLight();                                  (* 23-Jan-88 LAA *)

VAR
    s                       : ARRAY [0..81] OF CHAR;

BEGIN                       (* DisplayNetworkLight *)

    GetMessage(ModuleNumber + ORD(NormalLayoutActive) + 10, s);
    DisplayLight(NetworkLight, s, videolights);

END DisplayNetworkLight;





BEGIN                       (* NetLayouts *)

    StuffCreated := FALSE;
    NetworkLight := ALight(NIL);                                  (* 23-Jan-88 LAA *)
    NormalLayoutActive := TRUE;                                   

END NetLayouts.

