IMPLEMENTATION MODULE ResTrace;

    (* Debugging procedures for resource levelling. 

        MODIFICATION HISTORY:
        
        Feb , 89 - JES - created from pieces of the old Tlrplan.    
        30-Mar-90  RSC   Made Timeu to Timei/TimeForm conversions.
        16-Sep-90  AJL - Add ConcatTaskID.
                       - Use tracer module.
                       - Start with PrintOn on.
      Oct-18-90 AJL/CL - Modify PrintResidueAvailability to use the head cell 
                         as a boundary for searching thru the availability 
                         list.
        27-Apr-91  AJL - Add PrintVaryingAssignment;
    *)

        



FROM Allocs        IMPORT
    (* CONST *)         TskNmLen, WBSLine,
    (* TYPE *)          ATask, ADateBlock, AnAssignmentSummary, 
                        ATaskPtr, ATaskName, AFixType,
                        AStartStatus, ATaskFlag, ATaskFlagSet,
                        ATaskStatusSet, ATaskStatus, ADurationMethod,
                        StartStatusName,
    (* PROC *)          GetCodingField;

FROM Dialog        IMPORT
                        FatalError; 


FROM FlexStor      IMPORT
    (* TYPE *)          AnExtHandle, AnExtStoragePreference,
    (* PROC *)          ObjectsAreSame,
                        LockObject, LockObjectArray, ReleaseObject,
                        ReleaseUnchangedObject;


FROM FlexDisp      IMPORT HandleToString;

FROM LongConvert     IMPORT
    (* PROC *)          LongToString;

FROM LStrings      IMPORT 
                        Compare, SetString, ConcatLS, ConcatS, SubStr,
                        CtoS, Procustes, TrimRear, LengthOf;

FROM RealFormat    IMPORT 
                        FormatAsAmount, DefaultAmountFormat; 

FROM ResCal        IMPORT  
                        AnAvailabilityCellPointer, CellContainingDate,
                        AnAvailabilityCell;

FROM Timei         IMPORT
    (* TYPE *)          ADate, ADuration;

FROM Timeu         IMPORT
    (* PROC *)          DownScale;
                 
FROM TimeFormat    IMPORT 
                        TimeUtoS;     

FROM Tracer        IMPORT 
                        PrintString;

FROM SYSTEM        IMPORT 
                        SIZE;

FROM VaryAssgnment IMPORT
    (* TYPE *)          AVaryingAssgnList,
    (* PROC *)          GetVaryingAssgnListEntry;




CONST
    MaxPrintWidth = 255;


PROCEDURE PrintAString( VAR S : ARRAY OF CHAR );
BEGIN
    IF (PrintOn) THEN
        PrintString(S);
    END;
END PrintAString;




    (* Add to the end of LString S the name and task id of 
       the task. *)

PROCEDURE ConcatTaskID( VAR S : ARRAY OF CHAR; Task : ATaskPtr );
VAR 
    S2 : ARRAY [0..31] OF CHAR;
BEGIN
    ConcatLS(S,Task^.taskname);
    ConcatS(S," #");
    CtoS(CARDINAL(Task^.TaskID),S2);
    ConcatLS(S,S2);

    GetCodingField (Task^, WBSLine, S2);
    TrimRear(S2);
    IF (LengthOf(S2) > 0) THEN
        ConcatS(S," ");
        ConcatLS(S,S2);
    END;
END ConcatTaskID;






PROCEDURE PrintList(    List : AnExtHandle );
VAR
    TaskHandle, NextHandle : AnExtHandle;
    Task : ATaskPtr;
    NoteString   : ARRAY [0..150] OF CHAR;
    s    : ARRAY [0..150] OF CHAR;  
    s2   : ARRAY [0..41] OF CHAR; 
BEGIN
    SetString(NoteString,"                          Early Start          Early End          Free Late End      Late End");
    PrintAString(NoteString);
    IF (LockObject(List,Task)=0) THEN FatalError(); END;
    TaskHandle := Task^.Nextlink;
    ReleaseUnchangedObject(List);
    WHILE (NOT ObjectsAreSame(TaskHandle,List)) DO
        IF (LockObject(TaskHandle,Task)=0) THEN FatalError(); END;
        SetString(NoteString,"    ");
        ConcatTaskID(NoteString,Task);
        Procustes(NoteString,24);
        ConcatS(NoteString,"  ");
        TimeUtoS(Task^.Plan.Dates.EarlyStart,s);
        ConcatLS(NoteString,s);
        ConcatS(NoteString," -- ");
        TimeUtoS(Task^.Plan.Dates.EarlyEnd,s);
        ConcatLS(NoteString,s);
        ConcatS(NoteString,", ");
        TimeUtoS(Task^.Plan.Dates.LateFreeEnd,s);
        ConcatLS(NoteString,s);
        ConcatS(NoteString,", ");
        TimeUtoS(Task^.Plan.Dates.LateTotalEnd,s);
        ConcatLS(NoteString,s);
        PrintAString(NoteString);

        NextHandle := Task^.Nextlink;
        ReleaseUnchangedObject(TaskHandle);       (*<KILL Task := NIL; KILL>*)
        TaskHandle := NextHandle;
    END;
END PrintList;




PROCEDURE PrintAvailabilityCell( VAR Cell : AnAvailabilityCell );
VAR
    Line : ARRAY [0..MaxPrintWidth] OF CHAR;
    S    : ARRAY [0..MaxPrintWidth] OF CHAR;
BEGIN
    WITH Cell DO
        SetString(Line,"    ");
        TimeUtoS(StartDate,S);
        ConcatLS(Line,S);
        ConcatS(Line," - ");
        TimeUtoS(EndDate,S);
        ConcatLS(Line,S);
        ConcatS(Line,"    ");

        ConcatS(Line," (");
        CtoS(StartDate,S);
        Procustes(S,5);
        ConcatLS(Line,S);
        ConcatS(Line,"-");
        CtoS(EndDate,S);
        Procustes(S,5);
        ConcatLS(Line,S);
        ConcatS(Line,")  ");

        LongToString(AmountAvailable,S);
        ConcatLS(Line,S);

        IF ThisIsAVacation THEN
            ConcatS(Line,"  Vacation");
        ELSE
            ConcatS(Line,"          ");
        END;

    END;
    PrintAString(Line);
END PrintAvailabilityCell;





PROCEDURE PrintResidueAvailability( ResidueAvailProfile : AnExtHandle ); 
VAR
    CellHandle, 
    NextHandle  : AnExtHandle;
    Line        : ARRAY [0..MaxPrintWidth] OF CHAR;
    S           : ARRAY [0..31] OF CHAR; 
    Cell        : AnAvailabilityCellPointer;
    BackToHead,
    First       : BOOLEAN;
BEGIN
    IF (ResidueAvailProfile = AnExtHandle(NIL)) THEN
        SetString(Line,"No residue availability.");
        PrintAString(Line);
        RETURN;
    END;

    SetString(Line,"Residue Availability: ");
    PrintAString(Line);

    CellHandle := ResidueAvailProfile;

    BackToHead := FALSE;
    First := TRUE;
    REPEAT
        IF (LockObject(CellHandle,Cell) <> SIZE(Cell^)) THEN
            FatalError();
        END;
        
        IF (Cell^.IsHeadCell) THEN
            IF (NOT First) THEN
                BackToHead := TRUE;
		    ELSE
                First := FALSE;
            END;
        ELSE
            (*  To track down exact handles, enable these lines . . .
            HandleToString(CellHandle,S);
            SetString(Line,"    ");
            ConcatLS(Line,S);
            PrintAString(Line);
            *)
            PrintAvailabilityCell(Cell^);
        END;    
    
        NextHandle := Cell^.NextCell;
        ReleaseUnchangedObject(CellHandle);  
        Cell := NIL;
        CellHandle := NextHandle;
    UNTIL BackToHead;

END PrintResidueAvailability;





PROCEDURE PrintVaryingAssignment( VaryingAssignment : AVaryingAssgnList );
VAR
    i : CARDINAL;
    Start, End : CARDINAL;
    Rate : REAL;
    NoteString : ARRAY [0..81] OF CHAR;
    s : ARRAY [0..21] OF CHAR;
BEGIN
    IF (VaryingAssignment = AVaryingAssgnList(NIL)) THEN
        SetString(NoteString,"      AVaryingAssgnList(NIL)");    
        PrintAString(NoteString);
    ELSE
        SetString(NoteString,"      VaryingAssgnList");    
        PrintAString(NoteString);
        i := 1;
        WHILE (GetVaryingAssgnListEntry(VaryingAssignment,i,
                                        Start, End, Rate ) ) DO
            SetString(NoteString, "      ");
            CtoS(i,s); ConcatLS(NoteString,s); 
            ConcatS(NoteString,":  "); CtoS(Start, s);
            ConcatLS(NoteString, s);
            ConcatS(NoteString, " .. ");
            CtoS(End, s);
            ConcatLS(NoteString, s);
            ConcatS(NoteString, ", Rate = ");
            FormatAsAmount(Rate, DefaultAmountFormat, s, 13, 0, 5, FALSE);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);
            INC(i);
        END;
    END;
END PrintVaryingAssignment;




BEGIN
    PrintOn := TRUE;
END ResTrace.



