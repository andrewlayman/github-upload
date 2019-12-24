IMPLEMENTATION MODULE UndoViews;

    (* Modification History:

       23-Jan-89 RSC    Changed Storage to Space    .

    *)

(*V9=DEBUGGING Code*)


FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr,
    (* PROC *)                  CheckTaskValid;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState, AChartStateSet;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr,
    (* PROC *)                  CheckEdgeValid;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM LStrings               IMPORT
    (* PROC *)                  SetLengthOf, SetString, ConcatS, ConcatLS,
                                CtoS, Fill, Overlay;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM RsrcMod                IMPORT
    (* TYPE *)                  AResourcePointer;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM Undo                   IMPORT
    (* TYPE *)                  AnUndoableObject, AnUndoAction;


CONST
    ModuleNumber            = 17400;



TYPE

    ATransactionFlag    = (TUndone, TError);

    ATransactionFlagSet = SET OF ATransactionFlag;


    ATransactionRecordPointer = POINTER TO ATransactionRecord;

    ATransactionRecord  =   RECORD
        ID                  : CARDINAL;
        Type                : AnUndoableObject;
        Action              : AnUndoAction;
        TransactionFlags    : ATransactionFlagSet;
        DataObject          : ADDRESS;              (* Tree node or edge pointer *)

        CASE tag : AnUndoableObject OF
            Task, Resource :
                NodeID      : INTEGER;
                ParentID    : INTEGER;
                PrevID      : INTEGER;
        |   Edge :
                AnteID      : INTEGER;
                DescID      : INTEGER;
        ELSE
        END;

                            END;



    AStateRecordPointer = POINTER TO AStateRecord;

    AStateRecord =          RECORD
        ActiveChartType     : AnUndoableObject;
        BeforeChartState    : AChartStateSet;
        AfterChartState     : AChartStateSet;
        FirstNode           : INTEGER;
        CursorNode          : INTEGER;
        BugA                : INTEGER;
        BugB                : INTEGER;
        Open                : BOOLEAN;
                            END;






PROCEDURE FormatTaskID  (    TaskNode   : ATreeNode;
                         VAR s          : ARRAY OF CHAR );
VAR
    Task            : ATaskPtr;
BEGIN
    CheckTaskValid (TaskNode);
    Task := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
    CtoS (CARDINAL(Task^.TaskID), s);
    TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);
END FormatTaskID;



PROCEDURE FormatResourceID  (    Node       : ATreeNode;
                             VAR s          : ARRAY OF CHAR );
VAR
    ResourcePtr            : AResourcePointer;
BEGIN
    ResourcePtr := Node^.Methods^.GetDataObject (Node);
    CtoS (CARDINAL(ResourcePtr^.ID), s);
END FormatResourceID;



PROCEDURE FormatChartState (    ChartState  : AChartStateSet;
                            VAR s           : ARRAY OF CHAR  );
VAR
    i       : CARDINAL;
BEGIN
    SetLengthOf (s, 5);
    FOR i := 1 TO 5 DO
        s[i] := CHR (ORD("0")+ORD(VAL(AChartState,i-1) IN ChartState));
    END;
END FormatChartState;


PROCEDURE GetUndoInfo  (    Node        : ATreeNode;
                         VAR s          : ARRAY OF CHAR );
VAR
    Transaction             : ATransactionRecordPointer;
    s2                      : ARRAY [0..20] OF CHAR;
    EdgePtr                 : AnEdgePtr;
    DataObject              : ADDRESS;
    State                   : AStateRecordPointer;

BEGIN               (* UndoViewGetTitle *)

        IF (Node^.Methods^.IndentationLevel (Node) = 0) THEN
            State := Node^.Methods^.GetDataObject (Node);
            WITH State^ DO
                IF (Open) THEN
                    SetString (s, "Open ");
                ELSE
                    SetString (s, "Closed ");
                END;
                CASE ActiveChartType OF
                    Task :
                        ConcatS (s, "Gantt");
                |   Edge :
                        ConcatS (s, "Dependency");
                |   Resource :
                        ConcatS (s, "Resource");
                ELSE
                    FatalError();
                END;
            END;
(*
            Fill (s, "-", 50);
            WITH State^ DO
                s2[1] := CHR (ORD("0")+ORD(Open));
                s2[0] := 1C;
                Overlay (s, s2, 2, 1);
                CASE ActiveChartType OF
                    Task :
                        s2[1] := "G";
                |   Edge :
                        s2[1] := "D";
                |   Resource :
                        s2[1] := "R";
                ELSE
                    FatalError();
                END;
                Overlay (s, s2, 3, 1);
                FormatChartState (BeforeChartState, s2);
                Overlay (s, s2, 4, 5);
                FormatChartState (AfterChartState, s2);
                Overlay (s, s2, 10, 5);
                CtoS (CARDINAL(FirstNode), s2);
                Overlay (s, s2, 16, 5);
                CtoS (CARDINAL(CursorNode), s2);
                Overlay (s, s2, 22, 5);
                CtoS (CARDINAL(BugA), s2);
                Overlay (s, s2, 28, 5);
                CtoS (CARDINAL(BugB), s2);
                Overlay (s, s2, 34, 5);
            END;
*)
        ELSE
            Transaction := Node^.Methods^.GetDataObject (Node);
            SetLengthOf (s, 0);
            CASE Transaction^.Action OF
                Add :
                    ConcatS (s, "Add");
            |   Delete :
                    ConcatS (s, "Del");
            |   Change :
                    ConcatS (s, "Change");
            |   Move :
                    ConcatS (s, "Move");
            |   None :
                    ConcatS (s, "None");
            |   Promote :
                    ConcatS (s, "Promote");
            |   Demote :
                    ConcatS (s, "Demote");
            |   Open :
                    ConcatS (s, "Open");
            |   Close :
                    ConcatS (s, "Close");
            ELSE
                FatalError();
            END;
            ConcatS (s, " ");
            CASE Transaction^.Type OF
                Task :
                    ConcatS (s, "Task ");
                    IF (TUndone IN Transaction^.TransactionFlags) THEN
                        ConcatS (s, "<undone>");
                    ELSE
                        CASE Transaction^.Action OF
                            Add, Change, Move :
                                CtoS (CARDINAL(Transaction^.NodeID), s2);
                        |   Delete :
                                FormatTaskID (Transaction^.DataObject, s2);
                        ELSE
                            SetLengthOf (s2, 0);
                        END;
                        ConcatLS (s, s2);
                    END;
            |   Edge :
                    ConcatS (s, "Edge ");
                    IF (TUndone IN Transaction^.TransactionFlags) THEN
                        ConcatS (s, "<undone>");
                    ELSE
                        CtoS (CARDINAL(Transaction^.AnteID), s2);
                        ConcatLS (s, s2);
                        ConcatS (s, " ");
                        CtoS (CARDINAL(Transaction^.DescID), s2);
                        ConcatLS (s, s2);
                    END;
            |   Resource :
                    ConcatS (s, "Resource ");
                    IF (TUndone IN Transaction^.TransactionFlags) THEN
                        ConcatS (s, "<undone>");
                    ELSE
                        CASE Transaction^.Action OF
                            Add, Change, Move :
                                CtoS (CARDINAL(Transaction^.NodeID), s2);
                        |   Delete :
                                FormatResourceID (Transaction^.DataObject, s2);
                        ELSE
                            SetLengthOf (s2, 0);
                        END;
                        ConcatLS (s, s2);
                    END;
            ELSE
                FatalError();
            END;
        END;
END GetUndoInfo;



END UndoViews.
