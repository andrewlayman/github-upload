(*V1=NORMAL Version*)
(*V8=GELDED Version for debugging*)

MODULE TLFltFrm;

(*  =========================================================================
    Last Edit : June 10, 1991 2:58PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

    5/6/87 EGK      Many changes (mostly deletions) to re-implement the
                    filter list using object-oriented scheme.  Moved
                    CreateFilter and DeleteFilter to FilterOutlines module,
                    removed ForAllFilters and the internal SelectFilterNames
                    module, and re-coded SelectFilterName and SortFilters to
                    use the new filter list object.

    5/7/87 EGK      Minor changes to fix problems with phrase file numbers.

    01-Jun-87 LAA   Recoded MustFind to use the new methods of TreeObjects
                    instead of FindTask, which is no longer in Allocs.
    7/6/87  EGK     Replaced DoFilterNamesForm with ChooseFilter, which uses
                    a menu.
    7/9/87  EGK     The user-selected highlight filter is now Highlight1,
                    since we now have a total of four highlight filters.
    22-Sep-87 LAA   Incorporated form changes proposed by DSB, and in process
                    added field number constants and consolidated code.
    15-Oct-87 RSC   Added Shadows to boxes.  Added parameter to EditText.
    19-Oct-87 EGK   Call ResetMatching when filter list is put up.
    28-Oct-87 RSC   Notify forms when text has been edited.
    05-Nov-87 LAA   Fixed bug under which Shift-F8 acted like F2 on the notes
                    field.
    06-Nov-87 RSC   ljust wbs, obs, and notes.
    19-Jan-88 LAA   Made this an installable overlay.
    10-Feb-88 LAA   Corrected bug which would leave a Text lying around when
                    the filter form was brought up.
    28-Apr-88 EGK   Set match type to "ItBegins" on WBS, OBS, and AUX
                    filtering.
     5-May-88 RSC   If exit from name field with blank name, beep.
     2-Aug-88 AJL   Allow a ".." at the start of a string match field to 
                    mean "contains" the following string.
    30-Sep-88 AJL   "Something.." means begins, "..Something.." means
                    contains, and "..Something" means ends. 
    21-Dec-88 LAA   Changed imports for Lazlo reorganization.
     2-Jan-89 RSC   Removed references to Compare() (not used).
     6-Jan-89 RSC   Moved "AnOverlayProc" reference.
    10-Jan-89 RSC   Changed Storage to Space    .
    11-May-89 AJL   Added the "Needs Update" field.
    30-May-89 AJL   Moved filter records to FlexStor.
    08-Jun-89 LAA   Moved the Needs Update field around, and added 4 new 
                    fields for comparison against any two task columns (this
                    last not yet completely implemented).
    15-Jun-89 AJL   Removed F7Filtering.
    19-Jun-89 AJL   Removed FiltersOn boolean.
    07-Jul-89 LAA   Added fields to the record for comparing any task
                    column against text entered by the user.

    12-Jul-89 LAA   Extract the relational operators from the CompareTo field.
    16-Jul-89 LAA   Put in use of the Inverted field.
    18-Jul-89 LAA   Put into the checkproc a test to see if the compare to
                    fields are reasonable before allowing the use to leave
                    the fields.
    27-Jul-89 KKC   Pop up calculator if F2 key is pressed in a numeric
                    field.
    09-Aug-89 KKC   Add copyright message.
    14-Aug-89 LAA   Fixed bugs with the new filter fields.
    21-Aug-89 EGK   Import procs from FilterUtility instead of FilterRc.
    23-Aug-89 LAA   When a data type entered in the CompareTo field does not
                    match the column selected for comparison, put up an error
                    box rather than calling Message.  The message was being
                    overwritten by field-level prompts.
    31-Aug-89 LAA   Added a parameter to ParseAmountToReal.
    12-Sep-89 WKH   Make Notes editor box bigger
    25-Oct-89 RSC   Make column lists bigger (and change size with COMPRESSED)
    21-Feb-90 KKC   Remove import of Timeu.
    26-Sep-90 PFG   In case user edited a task column name, check to see
                    if the same name is in any other field.  If it is,
                    redisplay those fields correctly.
    28-Mar-91 TGS   If user types in resource name, look up the actual
                    resource name and fill that in on the form when they 
                    leave the field, so the case is the same.
                    More importantly, if they visit the task column list,
                    refresh any that were already filled out on the form.
                    Also do this on FormEntry in case they changed the names
                    elsewhere.
    10-Jun-91 PFG   Call generic GetTaskColumnName() in TASKCOLU.MOD
                    This was done to fix a problem where pressing ESC from a 
                    pick list after changing a task column name, the 
                    data columns whose contents had been changed didn't
                    get refreshed properly.
    =========================================================================
*)



FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* VAR *)                   GetColumnInfo;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, Error, FatalError, Burp;

FROM Edits                  IMPORT
    (* PROC *)                  EditText;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecord, AFilterRecordPointer,
                                AFltrType, AFltrSet, ASlackCheck,
                                AFilterMatch,
    (* VAR *)                   FilterTree, RevealFilter, HighlightFilter,
                                EmptyFilterSet;

FROM FilterUtility          IMPORT
    (* PROC *)                  FindFilterByName, CleanFilterSet,
                                SetFilterBit, TestFilterBit;

FROM Filters                IMPORT
    (* PROC *)                  ShowFilterLight;


FROM FilterSelect           IMPORT
    (* TYPE *)                  AnOverlayContext;

FROM FlexStor        IMPORT
   (* TYPES *)           AnExtHandle, 
   (* PROCS *)           HandleIsValid, GetExtData, SetExtData; 

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

FROM Forms                  IMPORT
    (* TYPE *)                  AForm, ACheckReason, AFieldValue, 
                                ACursorAttribute,
    (* PROC *)                  ShowValue, DoForm, FindFieldXY,
                                SetFormChange, HighlightField;

FROM Kbio                   IMPORT
    (* VAR *)                   maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 DoIt, CancelKey, ExitKey, InsertKey, DeleteKey,
                                EditKey, BackSpace, CopyKey;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWEnd, MaxColumn, GanttWStart;

FROM LStrings               IMPORT
    (* PROC *)                  SubStr, Fill, TrimRear, LJust, Copy, StoC,
                                ConcatLS, TrimFront, Upshift, Remove, Search,
                                Procustes, SetLengthOf, LengthOf, ConcatS,
                                SetString, Insert;

FROM MagicNum               IMPORT
    (* CONST *)                 IsRealValue, IsCurrency, IsEffort, IsDuration, 
                                IsSlack, IsDurationUnits, IsEffortUnits, 
                                IsIntValue, IsCardValue, IsStartDate, 
                                IsEndDate, IsMilestoneEnd, IsBigStart, 
                                IsBigEnd;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM ParseReal              IMPORT
    (* PROC *)                  ParseAmountToReal;

FROM ParseTime              IMPORT
    (* PROC *)                  StoTimeU;

FROM RealFormat             IMPORT
    (* VAR *)                   DefaultAmountFormat;

FROM RsrcEdit               IMPORT
    (* PROC *)                  SelectResource;

FROM RsrcMod                IMPORT
    (* TYPE *)                  FindResourceByName, AResourcePointer;

FROM Schedule               IMPORT
    (* VAR *)                   ScheduleSaved;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, ADR,
    (* PROC *)                  TSIZE, SIZE;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;

FROM TaskColumns            IMPORT
    (* PROC *)                  CreateTaskColumnsTree, DisposeTaskColumnsTree,
                                PickTaskColumn, SearchForTaskColumn,
                                GetTaskColumnName;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  TextExists, CreateText, AssignLine,
                                CopyLine, Compress, AssignText, DiscardText;

FROM TimeFormat             IMPORT
    (* PROC *)                  TimeUtoS;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;


CONST
    HeldFilterClass         = 22;
    MAXCARDINAL             = 0FFFFH;
    ModuleNumber            = 17100;
    ArbPattern              = "..";    (* Means an contains match in a string name. *) 
    EqualPattern            = "=";
    NotEqualPattern         = "<>";
    GreaterPattern          = ">";
    GreaterEqualPattern     = ">=";
    LessPattern             = "<";
    LessEqualPattern        = "<=";
    InvertedPattern         = "~";

VAR
    PrivateOverlayContext   : POINTER TO AnOverlayContext;
    OverlayID               : AnOverlayID;
    FilterOnForm            : ATreeNode;


(*<NORMAL*)


(*----------------------------------------------------------------------------
    LJustAndTrimRear --

    Copy the source to the destination, the LJust and TrimRear the dest.
----------------------------------------------------------------------------*)

PROCEDURE LJustAndTrimRear(VAR Source       : ARRAY OF CHAR;       (* in     *)
                           VAR Dest         : ARRAY OF CHAR);      (*    out *)

BEGIN                       (* LJustAndTrimRear *)

    Copy (Source, Dest);
    LJust(Dest);
    TrimRear(Dest);

END LJustAndTrimRear;




PROCEDURE ExtractMatchType(VAR UserPattern : ARRAY OF CHAR;
                               TextOnly    : BOOLEAN;
                           VAR MatchType   : AFilterMatch;
                           VAR Inverted    : BOOLEAN;
                           VAR WhatToMatch : ARRAY OF CHAR);

VAR
    S3                  : ARRAY [0..3] OF CHAR;
    n,LS3               : CARDINAL;
    LocalMatch          : AFilterMatch;
    i                   : CARDINAL;

BEGIN                   (* ExtractMatchType *)

    LJustAndTrimRear(UserPattern, WhatToMatch);
    TrimFront(WhatToMatch);

    SetString(S3, InvertedPattern);                           (* 16-Jul-89 LAA *)
    Inverted := FALSE;
    IF (Search(WhatToMatch, S3, 1) = 1) THEN
        Remove(WhatToMatch, 1, LengthOf(S3));
        TrimFront(WhatToMatch);
        Inverted := TRUE;
    END;

    SetString(S3,ArbPattern);
        (* Ellipses (Arb pattern) at end? *)
    IF (LengthOf(WhatToMatch) < LengthOf(S3)) THEN   (* Something *)
        MatchType := ItMatches;
    ELSE
        LS3 := LengthOf(S3);
        n := LengthOf(WhatToMatch)+1-LS3;
        IF (Search(WhatToMatch,S3,n) = n) THEN       (* Something.. *)
            Remove(WhatToMatch,n,LS3);
            IF (Search(WhatToMatch,S3,1)=1) THEN     (* ..Something.. *)
                MatchType := ItContains;
                Remove(WhatToMatch,1,LS3);
            ELSE
                MatchType := ItBegins;
            END;
        ELSIF (Search(WhatToMatch,S3,1)=1) THEN      (* ..Something *)
            Remove(WhatToMatch,1,LS3);
            MatchType := ItEnds;
        ELSE                                         (* Something *)
            MatchType := ItMatches;                   
        END;
    END;

    IF (NOT TextOnly) THEN
        FOR i := 1 TO 6 DO
            CASE i OF 
                1:
                    SetString(S3, GreaterEqualPattern);
                    LocalMatch := ItIsGreaterEqual;
            |   2:
                    SetString(S3, LessEqualPattern);
                    LocalMatch := ItIsLessEqual;
            |   3:
                    SetString(S3, NotEqualPattern);
                    LocalMatch := ItIsNotEqual;
            |   4:
                    SetString(S3, EqualPattern);
                    LocalMatch := ItIsEqual;
            |   5:
                    SetString(S3, GreaterPattern);
                    LocalMatch := ItIsGreater;
            |   6:
                    SetString(S3, LessPattern);
                    LocalMatch := ItIsLess;
            END;
            IF (Search(WhatToMatch,S3,1)=1) THEN
                Remove(WhatToMatch,1,LengthOf(S3));
                MatchType := LocalMatch;
                RETURN;
            END;
        END;
    END;

END ExtractMatchType;




(*NORMAL>*)




CONST
    NAME                    = 0;
    NOTE                    = 1;
    FLTR                    = 2;
    ANY                     = 3;
    CRIT                    = 4;
    PERC                    = 5;
    PERV                    = 6;

    AFTR                    = 7;
    BFOR                    = 8;
    MILE                    = 9;
    PART                    = 10;
    RCON                    = 11;
    LUP                     = 12;
    LATE                    = 13;
    STAT                    = 14;

    PATN                    = 15;
    KEYW                    = 16;
    WBS                     = 17;
    OBS                     = 18;
    COL1                    = 19;
    CMP1                    = 20;
    COL2                    = 21;
    CMP2                    = 22;
    RFUL                    = 23;
    RNM                     = 24;      (* First Resource Name field. *)
    LRNM                    = 27;      (* Last Resource Name field. *)

VAR
    FilterNotes         : AText;


PROCEDURE CheckFilters (    Form            : AForm;
                            FieldNo         : AFieldNo;
                        VAR FormValue       : ARRAY OF AFieldValue;
                            CheckReason     : ACheckReason;
                        VAR Code            : CARDINAL ):BOOLEAN;
VAR
    CodeIn      : CARDINAL;
    i           : CARDINAL;
    Node        : ATreeNode;
    Resource    : AResourcePointer;
    T           : ATaskPtr;
    ValueRecord : AColumnDataRecord;
    MatchType   : AFilterMatch;
    Changed,
    ok          : BOOLEAN;
    Inverted    : BOOLEAN;
    s           : ARRAY [0..255] OF CHAR;
    FilterName  : ARRAY [0..80] OF CHAR;


    PROCEDURE SaveNotesToText();
    BEGIN                      (* SaveNotesToText *)

        TrimRear(FormValue[NOTE].CharValue^);
        IF NOT TextExists(FilterNotes) THEN
            IF (FormValue[NOTE].CharValue^[0] = 0C) THEN
                RETURN;
            ELSE
                FilterNotes := CreateText();
            END;
        END;
        IF NOT AssignLine(FormValue[NOTE].CharValue^, 0, FilterNotes) THEN
            GetMessage(ModuleNumber + 28, s);
            Error(s);
        END;

    END SaveNotesToText;




    PROCEDURE AppropriateValue(VAR CompareTo    : ARRAY OF CHAR;
                                   DataType     : CARDINAL     ): BOOLEAN;

    VAR
        i, j                : CARDINAL;
        r                   : REAL;
        ok                  : BOOLEAN;
    
    BEGIN                   (* AppropriateValue *)

        TrimRear(CompareTo);
        CASE DataType OF
            IsRealValue, IsCurrency, IsDuration, IsEffort, IsSlack,
            IsIntValue, IsCardValue :
                i := 1;
                j := StoC(CompareTo, i);
                IF (i > LengthOf(CompareTo)) THEN
                    RETURN TRUE;
                END;

                i := 1;
                ParseAmountToReal(CompareTo, DefaultAmountFormat, r, ok, i);  (* 31-Aug-89 LAA *)
                IF (ok) THEN
                    RETURN TRUE;
                END;
        |   IsStartDate, IsEndDate, IsMilestoneEnd, IsBigStart, IsBigEnd :
                IF (StoTimeU(CompareTo, j)) THEN
                    RETURN TRUE;
                END;
        ELSE
        END;

        RETURN FALSE;

    END AppropriateValue;

BEGIN   (* CheckFilters *)

    (*<NORMAL*)
    CodeIn := Code;
    Code := 0;  (* For safety on return. *)

    IF (CheckReason = CheckFieldEntry) THEN
        RETURN TRUE;
    ELSIF (CheckReason = CheckFieldKey) THEN
            (* We only want to allow the edit key on Resource names. *)
        IF (FieldNo >= RNM) AND (FieldNo <= LRNM) THEN
            Node := FindResourceByName(FormValue[FieldNo].CharValue^);
            HighlightField(Form, FormValue, FieldNo, CursorResting);
            IF (SelectResource(Node)) THEN
                Resource := Node^.Methods^.GetDataObject (Node);
                Copy(Resource^.Name,FormValue[FieldNo].CharValue^);
                ShowValue(Form,FieldNo,FormValue);
            END;
            HighlightField(Form, FormValue, FieldNo, CursorOff);
        ELSIF ((FieldNo = NOTE) AND (CodeIn = EditKey)) THEN      (* 05-Nov-87 LAA *)
            SaveNotesToText();
            Copy(FormValue[NAME].CharValue^,FilterName);
            LJust (FilterName);
            TrimRear (FilterName);
            HighlightField(Form, FormValue, FieldNo, CursorResting);
            EditText(14,9,79,maxrow-2, ABoxType{ShadowBox,DoubleBox}, FilterName, 0, FilterNotes, Changed);
            HighlightField(Form, FormValue, FieldNo, CursorOff);
            IF (Changed) THEN
                SetFormChange( Form );
            END;
            Fill(FormValue[NOTE].CharValue^, " ", 0);
            IF TextExists(FilterNotes) THEN
                CopyLine(FilterNotes, 0, FormValue[NOTE].CharValue^);
            END;
            Procustes(FormValue[NOTE].CharValue^, HIGH(FormValue[NOTE].CharValue^));
            ShowValue(Form, NOTE, FormValue);
        ELSIF (((FieldNo = COL1) OR (FieldNo = COL2)) AND (CodeIn = EditKey)) THEN
            HighlightField(Form, FormValue, FieldNo, CursorResting);
            (* 25-Oct-89 RSC *)
            IF (PickTaskColumn(50, GanttWStart, MaxColumn, GanttWEnd - 2,
                               FormValue[FieldNo].CardValue, 
                               FormValue[FieldNo].CharValue^)) THEN 
            END;

            (* In case column names were edited, update all column
                names on form.  Need to do this even if PickTaskColumn
                returns FALSE, since the user may have changed some 
                column other than the highlighted one.  *)

            FOR i := COL1 TO COL2 BY 2 DO
                IF FormValue[i].CardValue <> 0 THEN
                    GetTaskColumnName(  FormValue[i].CardValue,
                                        FormValue[i].CharValue^);
                ELSE
                    Fill(FormValue[i].CharValue^, " ", 24);
                    FormValue[i + 1].CardValue := 0;
                END;
            END;

            (*  Redisplay the column names and widths  *)

            FOR i := COL1 TO COL2+1 DO
                ShowValue (Form, i, FormValue);
            END;

            HighlightField(Form, FormValue, FieldNo, CursorOff);

        ELSE
            Code := 04000H + CodeIn;
            RETURN TRUE;
        END;
        RETURN TRUE;
    END;

    CASE FieldNo OF
      NAME :
        IF (CheckReason = CheckFormEntry) THEN  (* 28-Mar-91 TGS *)

            FOR i := COL1 TO COL2 BY 2 DO
                IF FormValue[i].CardValue <> 0 THEN
                    GetTaskColumnName(  FormValue[i].CardValue,
                                        FormValue[i].CharValue^);
                ELSE
                    Fill(FormValue[i].CharValue^, " ", 24);
                    FormValue[i + 1].CardValue := 0;
                END;
            END;

        END;
        WITH FormValue[0] DO
            LJust(CharValue^);
            TrimRear(CharValue^);
            IF CharValue^[0] = 0C THEN
                IF (CheckReason = CheckFieldExit)   OR
                    (CheckReason = CheckFieldChange) THEN
                    Burp;   (* RSC 5/4/88 *)
                END;
                RETURN FALSE;
            END;
            Node := FindFilterByName (CharValue^);
            IF (Node <> NIL) AND (Node <> FilterOnForm) THEN
                GetMessage (ModuleNumber+7, s);
                ConcatLS (s, CharValue^);
                ConcatMessage (s, ModuleNumber+8);
                Message (s);
                RETURN FALSE;
            END;
        END;

    | NOTE :    
        SaveNotesToText();
        Compress(FilterNotes);

    | AFTR, BFOR :
        WITH FormValue[FieldNo] DO
            LJust(CharValue^);
            IF (CharValue^[0] = 0C) OR
            (CharValue^[1] = " ") THEN
                RETURN TRUE;
            ELSE
                RETURN StoTimeU(CharValue^,CardValue);
            END;
        END;
           
    | PERV :
        IF (FormValue[FieldNo].CardValue > 100) THEN
            GetMessage (ModuleNumber+11, s);
            Message (s);
            Burp ();
            RETURN FALSE;
        END;
            
    | RNM..LRNM :
        LJustAndTrimRear(FormValue[FieldNo].CharValue^,s);
        IF (s[0] > 0C) THEN
            Node := FindResourceByName (s);
            IF (Node = NIL) THEN
                DisplayMessage(ModuleNumber+4);
                RETURN FALSE;
            ELSIF (CheckReason = CheckFieldExit)   OR   (* 28-Mar-91 TGS *)
                  (CheckReason = CheckFieldChange) THEN
                Resource := Node^.Methods^.GetDataObject (Node);
                Copy(Resource^.Name,FormValue[FieldNo].CharValue^);
                ShowValue(Form,FieldNo,FormValue);
            END;
        END;
    | KEYW,
      RFUL,
      WBS,
      OBS   :
        LJust(FormValue[ FieldNo ].CharValue^);
        ShowValue( Form, FieldNo, FormValue );
    | COL1, COL2 :
        TrimRear(FormValue[FieldNo].CharValue^);
        IF (LengthOf(FormValue[FieldNo].CharValue^) > 0) THEN
            RETURN (SearchForTaskColumn(FormValue[FieldNo].CharValue^,
                                        FormValue[FieldNo].CardValue));
        ELSE
            FormValue[FieldNo].CardValue := 0;            (* 14-Aug-89 LAA *)
        END;

    | CMP1, CMP2 :
        IF (CheckReason = CheckFormExit) THEN
            ExtractMatchType(FormValue[FieldNo].CharValue^, FALSE,
                                MatchType, Inverted, s);
            IF ((MatchType > ItMatches) AND               (* 14-Aug-89 LAA *)
                (FormValue[FieldNo - 1].CardValue > 0)) THEN
                TrimRear(s);
                T := NIL;
                GetColumnInfo(ATreeNode(NIL), T, 
                                FormValue[FieldNo - 1].CardValue,
                                ColumnDataType, 0, ValueRecord);
                IF (NOT ((LengthOf(s) > 0) AND 
                    (AppropriateValue(s, ValueRecord.CardinalValue)))) THEN
                    GetMessage(ModuleNumber + 29, s);  (* "The type of value you've entered is not appropriate for the chosen column." *)
                    Error(s);                             (* 23-Aug-89 LAA *)
                    Code := CARDINAL(BITSET(FieldNo) + {15});
                    RETURN FALSE;
                END;
            END;
        END;
    ELSE
    END;

    (*NORMAL>*)

    RETURN TRUE;
END CheckFilters;







PROCEDURE DoFilterForm ( Filter : ATreeNode)
                                            : ACode;

VAR
    FormValue           : ARRAY [0..27] OF AFieldValue;
    i,j                 : CARDINAL;
    anyerror, ok        : BOOLEAN;
    code                : ACode;
    s                   : ARRAY [0..255] OF CHAR;
    FilteredResource    : AResourcePointer;
    FilterType          : AFltrType;
    FilterHandle        : AnExtHandle;
    FilterRecord        : AFilterRecord;

    (*<NORMAL*)

    PROCEDURE setdate(index:CARDINAL; VAR s: ARRAY OF CHAR);
    BEGIN
        WITH FormValue[index] DO
            TrimFront(CharValue^);
            Copy (CharValue^, s);
            IF (LengthOf(CharValue^) > 0) THEN
                IF (StoTimeU(CharValue^,CardValue)) THEN
                    SetFilterBit (FilterRecord.fltrset,FDate, TRUE);
                END;
            END
        END
    END setdate;


    PROCEDURE InsertMatchType(VAR WhatToMatch  : ARRAY OF CHAR;
                                  MatchType    : AFilterMatch;
                                  Inverted     : BOOLEAN;
                              VAR UserPattern  : ARRAY OF CHAR);

    VAR
        SA, SB : ARRAY [0..63] OF CHAR;
        SC     : ARRAY [0..3] OF CHAR;

    BEGIN                   (* InsertMatchType *)

        SetLengthOf(SA,0); 
        SetLengthOf(SB,0);
        
        CASE MatchType OF 
              ItBegins         : SetString(SB,ArbPattern);
            | ItEnds           : SetString(SA,ArbPattern);
            | ItContains       : SetString(SB,ArbPattern);
                                 SetString(SA,ArbPattern);
            | ItIsEqual        : SetString(SA,EqualPattern);
            | ItIsNotEqual     : SetString(SA, NotEqualPattern);
            | ItIsGreater      : SetString(SA, GreaterPattern);
            | ItIsGreaterEqual : SetString(SA, GreaterEqualPattern);
            | ItIsLess         : SetString(SA, LessPattern);
            | ItIsLessEqual    : SetString(SA, LessEqualPattern);
        ELSE;
        END;

        IF (Inverted) THEN
            SetString(SC, InvertedPattern);
            Insert(SA, SC, 1);
        END;

        LJust(WhatToMatch);
        TrimRear(WhatToMatch);
        IF (LengthOf(WhatToMatch) > 0) THEN
            ConcatLS(SA, WhatToMatch);
            ConcatLS(SA,SB);
        END;
        Copy(SA, UserPattern);

    END InsertMatchType;


        (* GetFilterPattern --
              Load a string into the form field representing the type
              of pattern chosen.  ItBegins, ItEnds and ItContains
              are represented with the use of ellipses, as in
              Begins..  ..Ends  ..Contains..
        *) 

    PROCEDURE GetFilterPattern(    FilterType : AFltrType;
                                   FieldNo    : AFieldNo );
    VAR
        SA, SB : ARRAY [0..63] OF CHAR;
    BEGIN                   (* GetFilterPattern *)

        WITH FilterRecord DO
            NEW(FormValue[FieldNo].CharValue);
            IF (TestFilterBit(fltrset, FilterType)) THEN
                InsertMatchType(Match[FilterType].Pattern, 
                                Match[FilterType].Type, FALSE,
                                FormValue[FieldNo].CharValue^);
            ELSE
                SetLengthOf(FormValue[FieldNo].CharValue^, 0);
            END;
        END;

    END GetFilterPattern;




    PROCEDURE GetResourcePattern(    FilterType : AFltrType;
                                     FieldNo    : AFieldNo );

    BEGIN                   (* GetResourcePattern *)

        WITH FilterRecord DO
            NEW(FormValue[FieldNo].CharValue);
            IF (TestFilterBit(fltrset, FilterType)) THEN
                Copy(ResourceName[FilterType], FormValue[FieldNo].CharValue^);
            ELSE
                SetLengthOf(FormValue[FieldNo].CharValue^, 0);
            END;
        END;

    END GetResourcePattern;



        (* SetFilterPattern --
               Get the filter pattern and rule associated with this field.
               If the ArbPattern is at the start or end of the string, then
               we will process it as ItBegins, ItEnds or ItContains.  Else
               default is ItBegins.
         *) 

    PROCEDURE SetFilterPattern(    FieldNo    : AFieldNo;
                                   FilterType : AFltrType);

    VAR
        Inverted            : BOOLEAN;

    BEGIN                   (* SetFilterPattern *)
        WITH FilterRecord DO
            ExtractMatchType(FormValue[FieldNo].CharValue^, TRUE,
                             Match[FilterType].Type, Inverted,
                             Match[FilterType].Pattern);
            IF (LengthOf(Match[FilterType].Pattern) > 0) THEN
                SetFilterBit(fltrset,FilterType,TRUE);
            END;
        END;

    END SetFilterPattern;


    PROCEDURE SetResourcePattern(    FieldNo    : AFieldNo;
                                     FilterType : AFltrType);

    VAR
        Node                : ATreeNode;

    BEGIN                   (* SetResourcePattern *)

        WITH FilterRecord DO
            LJustAndTrimRear(FormValue[FieldNo].CharValue^,
                             ResourceName[FilterType]);
            TrimFront(ResourceName[FilterType]);
            Node := FindResourceByName(ResourceName[FilterType]);
            IF (Node <> NIL) THEN
                SetFilterBit(fltrset,FilterType,TRUE);
            END;
        END;

    END SetResourcePattern;

    (*NORMAL>*)


BEGIN

    (*<NORMAL*)

        (* Make a local copy of the filter record. *)
    FilterHandle := AnExtHandle(Filter^.Methods^.GetDataObject (Filter));
    IF (GetExtData(FilterHandle,ADR(FilterRecord)) <> SIZE(FilterRecord)) THEN
        FatalError();
    END;
    IF (NOT AssignText (FilterRecord.Notes, FilterNotes)) THEN
        RETURN CancelKey;
    END;

    CleanFilterSet (Filter);

    IF (NOT CreateTaskColumnsTree()) THEN 
        RETURN CancelKey; 
    END;

    WITH FilterRecord DO
        NEW(FormValue[NAME].CharValue);
        Copy (Name, FormValue[NAME].CharValue^);

        NEW(FormValue[NOTE].CharValue);
        SetLengthOf(FormValue[NOTE].CharValue^, 0);
        IF TextExists(FilterNotes) THEN
            CopyLine(FilterNotes, 0, FormValue[NOTE].CharValue^);
        END;

        FormValue[FLTR].CardValue := ORD(Negative);
        FormValue[ANY].CardValue := ORD(Any);

        NEW(FormValue[AFTR].CharValue);
        SetLengthOf(FormValue[AFTR].CharValue^, 0);
        NEW(FormValue[BFOR].CharValue);
        SetLengthOf(FormValue[BFOR].CharValue^, 0);
        IF TestFilterBit (fltrset, FDate) THEN
            Copy (StartDateString, FormValue[AFTR].CharValue^);
            Copy (EndDateString, FormValue[BFOR].CharValue^);
        END;

        IF (TestFilterBit(fltrset,FSlack)) THEN
            FormValue[CRIT].CardValue := ORD(SlackCheck);
        ELSE
            FormValue[CRIT].CardValue := 0;
        END;

        FormValue[MILE].CardValue := ORD(TestFilterBit(fltrset,FMilestone));

        IF (TestFilterBit(fltrset, FComplete)) THEN
            FormValue[PERC].CardValue := ORD(NOT LessThan);
            FormValue[PERV].CardValue := PercentComplete;
        ELSE
            FormValue[PERC].CardValue := 0;
            FormValue[PERV].CardValue := 0;
        END;

        FormValue[STAT].CardValue := ORD(TestFilterBit(fltrset,FNeedsUpdate));

        FormValue[LATE].CardValue := ORD(TestFilterBit(fltrset,FLate));
        FormValue[PART].CardValue := ORD(TestFilterBit(fltrset,FJoin));
        FormValue[RCON].CardValue := ORD(TestFilterBit(fltrset, FResConflict));
        FormValue[LUP].CardValue := ORD(TestFilterBit(fltrset,FLoop));

            (* The pattern matching strings. *)

        GetFilterPattern(FNameHas, PATN);
        GetFilterPattern(FAUXHas, KEYW);
        GetFilterPattern(FWBSHas, WBS);
        GetFilterPattern(FOBSHas, OBS);
        GetFilterPattern(FRNameHas, RFUL);

        NEW(FormValue[COL1].CharValue);
        SetLengthOf(FormValue[COL1].CharValue^, 0);               (* 07-Jul-89 LAA *)
        FormValue[COL1].CardValue := DataField[FDataField1].FieldId;
        IF (FormValue[COL1].CardValue > 0) THEN
            GetTaskColumnName(  FormValue[COL1].CardValue,
                                FormValue[COL1].CharValue^);    (* 3-Jun-91 PFG *)
        END;
        NEW(FormValue[CMP1].CharValue);
        InsertMatchType(DataField[FDataField1].CompareTo,
                        DataField[FDataField1].CompareAs,
                        DataField[FDataField1].Inverted,
                        FormValue[CMP1].CharValue^);

        NEW(FormValue[COL2].CharValue);
        SetLengthOf(FormValue[COL2].CharValue^, 0);
        FormValue[COL2].CardValue := DataField[FDataField2].FieldId;
        IF (FormValue[COL2].CardValue > 0) THEN
            GetTaskColumnName(  FormValue[COL2].CardValue,
                                FormValue[COL2].CharValue^);    (* 3-Jun-91 PFG *)
        END;
        NEW(FormValue[CMP2].CharValue);
        InsertMatchType(DataField[FDataField2].CompareTo, 
                        DataField[FDataField2].CompareAs,
                        DataField[FDataField2].Inverted,
                        FormValue[CMP2].CharValue^);

        GetResourcePattern(FResource0, RNM);
        GetResourcePattern(FResource1, RNM + 1);
        GetResourcePattern(FResource2, RNM + 2);
        GetResourcePattern(FResource3, RNM + 3);
    END;

    code := DoForm(0,0,MaxColumn,GanttWEnd, 2, TRUE, FormValue, CheckFilters);

    anyerror := FALSE;

    IF (code = ExitKey) THEN
        WITH FilterRecord DO
            Copy(FormValue[NAME].CharValue^, Name);
            TrimRear(Name);
            DiscardText(Notes);                                   (* 10-Feb-88 LAA *)
            IF AssignText (FilterNotes, Notes) THEN END;
            Negative := ODD(FormValue[FLTR].CardValue);
            Any := ODD(FormValue[ANY].CardValue);

            fltrset := EmptyFilterSet;

            setdate(AFTR, StartDateString);
            setdate(BFOR, EndDateString);


            i := FormValue[CRIT].CardValue;           (* Slack. *)

            IF (i > 0) THEN
                SetFilterBit(fltrset,FSlack,TRUE);
                SlackCheck := VAL(ASlackCheck,i);
            END;

            MilestoneCheck := (FormValue[MILE].CardValue > 0);
            IF (MilestoneCheck) THEN
                SetFilterBit(fltrset,FMilestone,TRUE);
            END;

            LessThan := (FormValue[PERC].CardValue = 0);
            PercentComplete := FormValue[PERV].CardValue;
            IF (NOT LessThan) OR (PercentComplete <> 0) THEN
                SetFilterBit (fltrset, FComplete, TRUE);
            END;

            IF (FormValue[STAT].CardValue > 0) THEN
                SetFilterBit (fltrset, FNeedsUpdate, TRUE);
            END;

            LateCheck := (FormValue[LATE].CardValue > 0);
            IF (LateCheck) THEN
                SetFilterBit (fltrset, FLate, TRUE);
            END;

            PartialJoinCheck := (FormValue[PART].CardValue > 0);
            IF (PartialJoinCheck) THEN
                SetFilterBit (fltrset, FJoin, TRUE);
            END;

            ConflictCheck := (FormValue[RCON].CardValue > 0);
            IF (ConflictCheck) THEN
                SetFilterBit (fltrset, FResConflict, TRUE);
            END;

            LoopCheck := (FormValue[LUP].CardValue > 0);
            IF (LoopCheck) THEN
                SetFilterBit (fltrset, FLoop, TRUE);
            END;


            SetFilterPattern(PATN, FNameHas);
            SetFilterPattern(KEYW, FAUXHas);
            SetFilterPattern(WBS, FWBSHas);
            SetFilterPattern(OBS, FOBSHas);
            SetFilterPattern(RFUL, FRNameHas);
            SetResourcePattern(RNM, FResource0);
            SetResourcePattern(RNM + 1, FResource1);
            SetResourcePattern(RNM + 2, FResource2);
            SetResourcePattern(RNM + 3, FResource3);

            IF (SearchForTaskColumn(FormValue[COL1].CharValue^,   (* 07-Jul-89 LAA *)
                                    DataField[FDataField1].FieldId)) THEN
                SetFilterBit (fltrset, FDataField1, TRUE);
            ELSE
                DataField[FDataField1].FieldId := 0;              (* 14-Aug-89 LAA *)
            END;
            ExtractMatchType(FormValue[CMP1].CharValue^, FALSE,   
                             DataField[FDataField1].CompareAs,
                             DataField[FDataField1].Inverted,
                             DataField[FDataField1].CompareTo);       

            IF (SearchForTaskColumn(FormValue[COL2].CharValue^,
                                    DataField[FDataField2].FieldId)) THEN
                SetFilterBit (fltrset, FDataField2, TRUE);
            ELSE
                DataField[FDataField2].FieldId := 0;              (* 14-Aug-89 LAA *)
            END;
            ExtractMatchType(FormValue[CMP2].CharValue^, FALSE,
                             DataField[FDataField2].CompareAs,
                             DataField[FDataField2].Inverted,
                             DataField[FDataField2].CompareTo);

                (* Store the local copy of the filter record back into
                   FlexStor. *)

            IF (NOT SetExtData(FilterHandle,ADR(FilterRecord),SIZE(FilterRecord))) THEN
                DisposeTaskColumnsTree();
                RETURN CancelKey;    (* A serious error! *)
            END; 


            ScheduleSaved := FALSE;
        END (* WITH *)
    END;

    DISPOSE(FormValue[NAME].CharValue);
    DISPOSE(FormValue[NOTE].CharValue);
    DISPOSE(FormValue[AFTR].CharValue);
    DISPOSE(FormValue[BFOR].CharValue);
    DISPOSE(FormValue[PATN].CharValue);
    DISPOSE(FormValue[KEYW].CharValue);
    DISPOSE(FormValue[WBS].CharValue);
    DISPOSE(FormValue[OBS].CharValue);
    FOR i := COL1 TO CMP2 DO
        DISPOSE(FormValue[i].CharValue);
    END;
    DISPOSE(FormValue[RFUL].CharValue);
    FOR i := RNM TO LRNM DO
        DISPOSE(FormValue[i].CharValue);
    END;
    DiscardText(FilterNotes);                                     (* 10-Feb-88 LAA *)
    DisposeTaskColumnsTree();

    RETURN code;

    (*NORMAL>*)

    (*<GELDED
    RETURN CancelKey;
    GELDED>*)

END DoFilterForm;



PROCEDURE TLFltFrmBody();                                         (* 19-Jan-88 LAA *)
VAR
    Copyright                      : ARRAY[0..50] OF CHAR;
BEGIN                       (* TLFltFrmBody *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    PrivateOverlayContext := OverlayContext();

    WITH PrivateOverlayContext^ DO
        FilterOnForm := FilterNode;
        ReturnCode := DoFilterForm(FilterNode);
    END;

END TLFltFrmBody;



BEGIN

    OverlayID := ImAnInstallableOverlay(TLFltFrmBody, AnOverlayProc(NIL));       (* 19-Jan-88 LAA *)
    TLFltFrmBody();

END TLFltFrm.

