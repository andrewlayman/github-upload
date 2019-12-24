(*----------------------------------------------------------------------------
    UPDATE LOG:
        May 13, 1986    Removed the references to ProjectDescriptionLine1
                        and 2, and replaced them with access to the first
                        two lines of the ProjectText.  Also, Projectstuff
                        comes from Schedule rather than Transfer.
        11/20/86 LAA    Changed FilterNotes to use Reveal and Highlight
                        filter record.
        02-Jan-87 LAA   Changes because the antetask and desctask are now
                        tree nodes, not task pointers.
        22-Jul-87 RSC   Added reference to As Of date for banners.  Made banner
                        notes text come out longer than 20 bytes.
        05-Aug-87 LAA   Removed all references to FiltersManual.
        27-Jan-88 EGK   Simplified printing of filter info (just prints
                        filter name).
        09-May-88 LAA   Removed print banner for promotional version.
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
        20-Apr-89 KKC   Modify pagehead for Report header and number of
                        notes lines print.
                        FiltersNotes prints out active filters if
                        ReportActiveFilters set to TRUE, otherwise no
                        active filters will be printed.
        4-May-89  KKC   Move CreateReportHeaderNotes from PrintSupport
       10-May-89  AJL   Renamed a few variables and types, changed a pointer
                        to an array, and allowed partial matches on keywords.
       11-May-89  KKC   Print a blank line after notes.
       06-Jun-89  KKC   Do not print trailing blank notes in PageHead.
       06-Jun-89  AJL   Put filters into FlexStor.
                        Check that the Reveal filter is not NIL before printing
                        its name, in case FiltersOn has been set to TRUE without
                        there being a Reveal filter.
       12-Jun-89  KKC   - Do not print trailing blank report header in PageHead.
                        - Add UserName in report header.
       14-Jun-89  KKC   - Declare one more buffer for printing blank lines in
                          PageHead.  
       15-Jun-89 AJL    - Removed F7Filtering.
       19-Jun-89 AJL    - Removed FiltersOn boolean, replaced by 
                          QueryRevealFilterOn.
       21-Jun-89  KKC   - Take out the message "Capabilities" from report
                          header.
       25-Jun-89  WKH   - Get UserName from Registry instead of Schedule.
       13-Jul-89  KKC   - Add new procedure DiscardReportHeader.
       22-Aug-89  AJL   - Move the keyword substitution code into a new
                          module, KeywdSub.
       30-Aug-89  KKC   - Discard ReportHeaderTextIn and ReportHeaderTextGen
                          if they are not enough memory to store the report
                          header.
                          Print an extra blank line after Dependency names.
       21-Feb-90  KKC   - Remove import of Timeu.
       1-Jun-90   AJL   - Removed import of Planner.
       8-Jan-91   AJL   - Check for a non-nil antetask before printing its name.
       2-Jul-91   AJL   - Added parameters to FilterNotes.

----------------------------------------------------------------------------*)

IMPLEMENTATION MODULE PrintCaptions;


FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr,
    (* PROC *)                  CheckTaskValid;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* VAR  *)                  ChartState;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecordPointer,
    (* VAR  *)                  RevealFilter, HighlightFilter;

FROM Filters                IMPORT
    (* PROC  *)                 QueryRevealFilterOn;

FROM Holder                 IMPORT
    (* TYPE *)                  AHoldTypeSet,
    (* PROC *)                  LocateHeldItem;

FROM Kbio                   IMPORT
    (* VAR *)                   VersionString;

FROM KeywdSub               IMPORT
    (* PROC *)                     MakeSubstitutions;

FROM LStrings               IMPORT SetString, SubStr, ConcatLS, Fill,
                                   RJust, LJust, Overlay, LengthOf, StoC,
                                   Search, Upshift, StringsEqual, Compare,
                                   TrimRear, CtoS, ConcatS, Copy, Remove,
                                   TrimFront, Insert, Procustes, SetLengthOf;

FROM Menus                  IMPORT
    (* PROC *)                     WordNumber;

FROM MsgFile                IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM PrintStatic            IMPORT
    (* VAR  *)                     ReportHeaderTextIn, NNotesPrintLines,
                                   ReportActiveFilters;

FROM PrintSupport           IMPORT
    (* PROC *)                  StartPage, PrintLine, PrintText, PageWidth;

FROM Registry               IMPORT
    (* VAR  *)                  UserName;

IMPORT SchedKey;

FROM Schedule               IMPORT
    (* VAR *)                   ProjectMedia, ProjectName, Author,
                                FullScheduleName, ProjectText;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADR, ADDRESS;

FROM Text                   IMPORT
    (* PROC *)                  CopyLine, AssignLine, Compress, CreateText,
                                LineExists, TextExists, AText, SizeOfText,
                                DiscardText;

FROM TimeFormat             IMPORT
    (* VAR *)                   DefaultDateAndTimeFormat, DefaultDateFormat,
    (* PROCS *)                 DtoS, TimeToString;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;


CONST
    ModuleNumber        =   10700;    (* For GetMessage *)
    Normal              =   0;
    Bold                =   1;
    MaxWidth            =   255;
    NDefaultReportHeaderLines  =   3;

    MAXCARDINAL = 0FFFFH;

VAR
    ReportHeaderTextGen     :       AText;



    (*  FilterNotes -- Print a list of the filters currently in
                       effect. *)


    (*  FilterNotes -- Print a list of the filters currently in
                       effect.  Shows the Select filter if ShowSelect
                       is TRUE, shows any highlight filters if 
                       ShowHighlights is true. *)

(*$O-*)         (* After seeing what the optimizer did with ShowJoins, I'm
                   not about to trust it here either.       EGK 1/27/88    *)

PROCEDURE FilterNotes( ShowSelect, ShowHighlights : BOOLEAN );


VAR
    Line                    : ARRAY [0..255] OF CHAR;
    i                       : CARDINAL;
    FilterRecord            : AFilterRecordPointer;
    TaskPtr                 : ATaskPtr;


    PROCEDURE PrintFilterName   ( Node      : ATreeNode;
                                  Mode      : CARDINAL      );
    BEGIN
        FilterRecord := Node^.Methods^.LockFlexStorDataObject (Node);
        PrintLine (FilterRecord^.Name, Mode);
        Node^.Methods^.UnlockUnchangedDataObject (Node);   FilterRecord := NIL;
    END PrintFilterName;



BEGIN                   (* FilterNotes *)

    IF ( NOT ReportActiveFilters ) THEN RETURN; END;  (* KKC Apr 20, 1989 *)
    IF (ShowSelect) AND (QueryRevealFilterOn())  THEN
        GetMessage (ModuleNumber+1, Line);  (* "Select filter:" *)
        PrintText (Line, Normal);
        PrintFilterName (RevealFilter, Normal);
    END;

    IF (ShowHighlights) THEN
        FOR i := 3 TO 5 DO
            IF (HighlightFilter[i] <> NIL) THEN
                GetMessage (ModuleNumber+i-1, Line);    (* "Highlight (1):" *)
                PrintText (Line, Bold);
                PrintFilterName (HighlightFilter[i], Bold);
            END;
        END;
    END;

    IF (ShowHighlights) AND (HighlightFilter[1] <> NIL) THEN
        GetMessage (ModuleNumber+5, Line);      (* "Dependencies: " *)
        PrintText (Line, Bold);
        FilterRecord := HighlightFilter[1]^.Methods^.LockFlexStorDataObject (HighlightFilter[1]);
        WITH FilterRecord^ DO
            IF (antetask <> NIL) THEN
                CheckTaskValid (antetask);
                TaskPtr := antetask^.Methods^.LockFlexStorDataObject (antetask);
                Copy (TaskPtr^.taskname, Line);
                PrintLine (Line, Bold);
                antetask^.Methods^.UnlockUnchangedDataObject (antetask);
            END;
        END;
        HighlightFilter[1]^.Methods^.UnlockUnchangedDataObject (HighlightFilter[1]);
        FilterRecord := NIL;
    END;

    SetLengthOf(Line, 0);
    PrintLine(Line,0);

END FilterNotes;
(*$O=*)


    (*  PageHead -- Advance the printer to a new page and print the
                    basic information about the schedule. *)

PROCEDURE PageHead;
VAR
    Where                      : ADDRESS;
    i, Size,
    Year,Month,Day,Hour,Minute : CARDINAL;
    Category                   : AHoldTypeSet;
    Line                       : ARRAY [0..255] OF CHAR;
    BlankLine                  : ARRAY[0..0] OF CHAR;
    NBlankLines                : CARDINAL;

BEGIN
    StartPage;

    i := 0;

    NBlankLines := 0;
    WHILE ( LineExists(ReportHeaderTextGen, i) ) DO (* KKC May 4, 1989 *)
        CopyLine(ReportHeaderTextGen, i, Line);
        TrimRear(Line);
        IF ( LengthOf(Line) > 0 ) THEN
            SetLengthOf( BlankLine, 0 );
            WHILE ( NBlankLines <> 0 ) DO
                PrintLine( BlankLine, 0 );
                DEC ( NBlankLines );
            END;
            PrintLine(Line, 0);
        ELSE
            INC( NBlankLines );
        END;
        INC (i);
    END;

    Fill(Line," ",0);
    PrintLine(Line,0);

    IF ( NNotesPrintLines <> 0 ) THEN               (* KKC Apr 20, 1989 *)
        NBlankLines := 0;
        FOR i := 0 TO NNotesPrintLines - 1 DO
            IF LineExists(ProjectText, i) THEN
                CopyLine(ProjectText, i, Line);
                TrimRear(Line);
                IF ( LengthOf(Line) > 0 ) THEN
                    SetLengthOf( BlankLine, 0 );
                    WHILE ( NBlankLines <> 0 ) DO
                        PrintLine( BlankLine, 0 );
                        DEC ( NBlankLines );
                    END;
                    PrintLine(Line, 0);
                ELSE
                    INC( NBlankLines );
                END;
            ELSE
                INC( NBlankLines );
            END;
        END;
    END;

    SetLengthOf(Line, 0);
    PrintLine(Line, 0);

  (* Based on the secret capabilities bits, put out different banners. *)

    SetString( Line, "Capabilities" );
    IF (LocateHeldItem( Line, 1, Category, Where, Size )) THEN
        WarnOfLimitations( BITSET( Size ) );
    END;

    SetLengthOf(Line, 0);
    PrintLine(Line,0);

END PageHead;




 (* THIS CODE IS ALMOST IDENTICAL TO THE CODE IN TLSTART. *)

PROCEDURE WarnOfLimitations( Capabilities : BITSET );

CONST
        TaskLimitStartByte = 10;
        MagicMode          = 0;
        Limited            = 1;  (* Bit 1 in the capabilities byte *)
        Promo              = 2;  (*     2 *)
        LAN                = 3;
        Educ               = 4;
        Beta               = {Promo,Educ}; (* Beta kluge *)
VAR
    s   : ARRAY [0..255] OF CHAR;
    C   : CHAR;
BEGIN
    s[0] := 0C;
    IF ((Beta * Capabilities) = Beta) THEN
        GetMessage( ModuleNumber + 44, s ); (* "Beta Edition." *)
        PrintLine( s, 0 );
    ELSE
        (*                                                        (* 09-May-88 LAA *)
        IF (Promo IN Capabilities) THEN
            GetMessage( ModuleNumber + 45, s ); (* "Promotional copy.  Not for resale." *)
            PrintLine( s, 0 );
        END;
        *)
        IF (Educ IN Capabilities) THEN
            GetMessage( ModuleNumber + 47, s ); (* "Educational Edition.  Not for resale." *)
            PrintLine( s, 0 );
        END;
    END;
    IF (Limited IN Capabilities) THEN
        GetMessage( ModuleNumber + 46, s ); (* "This version of Time Line has a maximum task limit of ~" *)
        C := VersionString[ TaskLimitStartByte ];
        IF (C <> "0") THEN
            INC(s[0]);
            s[ ORD(s[0]) ] := C;
        END;
        C := VersionString[ TaskLimitStartByte + 1 ];
        INC(s[0]);
        s[ ORD(s[0]) ] := C;
        ConcatS( s, "0." );   (* as in "task limit is 10." *)
        PrintLine( s, 0 );
    END;

END WarnOfLimitations;


PROCEDURE CreateReportHeaderNotes();        (* KKC Apr 20, 1989 *)
VAR
    s                       :   ARRAY [0..MaxWidth] OF CHAR;
    i                       :   CARDINAL;
BEGIN
    IF ( TextExists(ReportHeaderTextIn) ) THEN RETURN; END;

    ReportHeaderTextIn := CreateText();
    IF  ( ReportHeaderTextIn = AText(NIL) ) THEN RETURN; END;

    FOR i := 0 TO NDefaultReportHeaderLines - 1 DO
        GetMessage( ModuleNumber + i + 70 , s);
        IF NOT AssignLine(s, i , ReportHeaderTextIn) THEN
            GetMessage( ModuleNumber + 48, s ); (* "Report Header description not saved: out of memory." *)
            Error(s);
            DiscardText(ReportHeaderTextIn);
            ReportHeaderTextIn := AText(NIL);
            RETURN;
        END;
    END;
    Compress(ReportHeaderTextIn);
END CreateReportHeaderNotes;




PROCEDURE GenerateReportHeader();       (* KKC Apr 20, 1989 *)
VAR
    Line    :   ARRAY [0..MaxWidth] OF CHAR;
    i       :   CARDINAL;
BEGIN
    CreateReportHeaderNotes();
    ReportHeaderTextGen := CreateText();
    IF  ( ReportHeaderTextGen = AText(NIL) ) THEN RETURN; END;
    i := 0;
    WHILE ( LineExists(ReportHeaderTextIn, i) ) DO
        CopyLine(ReportHeaderTextIn, i, Line);
        MakeSubstitutions(Line,PageWidth(),SchedKey.GetKeyWordValue,NIL);
        IF NOT AssignLine(Line, i, ReportHeaderTextGen) THEN
            GetMessage( ModuleNumber + 20, Line ); (* "Report Header description not generated: out of memory." *)
            Error(Line);
            DiscardText(ReportHeaderTextGen);
            ReportHeaderTextGen := AText(NIL);
            RETURN;
        END;
        INC(i);
    END;
    Compress(ReportHeaderTextGen);
END GenerateReportHeader;




PROCEDURE DiscardReportHeader();
BEGIN
    IF ( TextExists(ReportHeaderTextGen) ) THEN 
        DiscardText(ReportHeaderTextGen);
    END;
END DiscardReportHeader;

BEGIN
END PrintCaptions.

