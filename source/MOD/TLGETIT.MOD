    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

(*<DOS*)
MODULE TLGetIt;
(*DOS>*)

(*<OS2
IMPLEMENTATION MODULE TLGetIt;
OS2>*)

    (*
            TL Get It - Get a file to IMPORT.

                This overlay manages the process of importing and retrieving
            schedules.

                1) If not RetrieveDammit, 
                     Do a directory lookup.

                2) Given the file, call the appropriate overlay.

    
    MODIFICATION HISTORY:

        RSC  9/22/87 - First version.
        RSC  9/30/87 - Added most of TRANSFER's Import functions here.
        RSC  1/18/88 - Added 'one moment' box.
        RSC  2/18/88 - Only recalc if auto recalc selected.
        EGK  3/3/88  - Check overlay context for success after loading.
        WKH  4/11/89 - Disallow selection of 0 length files.
        AJL  5/14/89 - Removed references to Alarms.
        WKH  5/25/89 - Get DontAllowZero from Direct411.
        KKC  9/09/89 - Add copyright message.
        WKH 11/20/89 - Well, don't tack on a "/" for things like DK: and C:
        31-May-90 AJL   Changed the exported variables from Planner.
                        Eliminated the PlanLevel stuff, and added new options.
        18-Jun-90 AJL - Modified the AnalyzeExtensionForOverlayName proc so that
                        it reads a list of file extensions and overlay names
                        from the phrases file.
        10-Sep-90 RSC - Change a ">" to ">=" to get file combine to work.
         6-Feb-91 RSC - Import LOADCOMMON to move it out of the kids of
                        this overlay.  Add hook to call overlays like TLSTART.
         4-Jun-91 RSC - More general hook for overlays using OverlayPackage.
                        This will be used with Steve Alexandar's OnTarget
                        importer.
        22-Jul-91 PFG - Give the overlay that loads a schedule the option
                        of displaying its own errors.  This was needed for
                        the On Targer importer.
        26-Jul-91 PFG - Set PackageOK to false if the schedule load gets
                        cancelled so that the load won't continue in the
                        case of an On Target imported file.
*)


FROM Chart        IMPORT  
        (* VARS *)      CursorTask, 
        (* PROCS *)     MChToday;

FROM ChartControl       IMPORT
    (* TYPE *)              AChartState,
    (* VAR *)               ChartState;

FROM Overlays     IMPORT
        (* PROCS *)     OverlayContext, CallOverlayWithContext,
                        OverlayPackage,
        (* VARS  *)     PackageOK;

FROM LStrings     IMPORT
        (* PROCS *)     Upshift, Procustes, SetString, LengthOf, Remove,
                        Copy, ConcatS, ConcatLS, SetLengthOf, StoC;

FROM MsgFile      IMPORT
        (* PROCS *)     GetMessage;

FROM ImportSelect IMPORT
        (* PROCS *)     LoadAFile;

FROM Dialog       IMPORT
        (* TYPE *)      ABoxHandle,
        (* PROCS *)     ProgressBox, ReleaseBox, Error, FatalError;

FROM Direct411    IMPORT 
        (* TYPES *)     AQualificationProcedure,
        (* PROCS *)     DontAllowZero;

FROM Directory    IMPORT
        (* TYPES *)     AFileNameRecord, AFileAttributeSet,
        (* PROCS *)     StartFileNodeLookup, ExpandPath;

FROM Schedule     IMPORT
        (* VARS *)      ProjectMedia;

FROM Searcher     IMPORT
    (* PROC *)           PatternSearch;

FROM Space        IMPORT SetHeapLevels;

FROM SYSTEM       IMPORT
        (* THINGS *)    ADR;

FROM Timei        IMPORT
         (* VAR *)      Today;

FROM Transfer     IMPORT
        (* TYPES *)     ARetrieveType, 
        (* VARS  *)     RollupAnySummaries, RetrieveDammit, RetrieveType;

FROM Filters      IMPORT
        (* PROCS *)     Filter;

FROM Planner      IMPORT
        (* TYPE *)         ACalcComponent, AWhenToCalc,
        (* VAR *)          CalculationState,
        (* PROC *)         WeShouldRecalc, Pert;

FROM Words        IMPORT
    (* PROC *)             ParseBal;


IMPORT LoadCommon;              (* 6-Feb-91 RSC *)


CONST ModuleNumber = 20500;   (* For GetMessage *)


VAR
    BoxHandle    : ABoxHandle;
    BoxUp,
    IsFullRetrieval : BOOLEAN;




 (* Recompute the schedule after loading it.  This includes rolling up 
    summary tasks, filtering, etc.

    MOVED HERE FROM TRANSFER 9/30/87 by RSC
 *)

PROCEDURE RecomputeAfterLoad( LoadedProperly : BOOLEAN );
BEGIN
    IF (LoadedProperly) AND
       (NOT(Scheduled IN ChartState)) AND
       (WeShouldRecalc(CalculationState,AutoCalc))
       THEN
        RollupAnySummaries; 
        IF (Pert(Today,AutoCalc)) THEN
        END; 
    END;
        (* CheckForCalendarRoom; *) 
    Filter; 
    CursorTask := NIL;
    MChToday;
    RetrieveDammit := FALSE;                 (* 11/10/86 LAA *)
END RecomputeAfterLoad;



  (* Get Instructions And Box Title - 

     Get the instruction text and box title for the directory lookup.
  *)
PROCEDURE GetInstructionsAndBoxTitle( VAR Instructions,
                                          BoxTitle : ARRAY OF CHAR );
VAR
    StartingNumber : CARDINAL;
    Copyright      : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    StartingNumber := 1;
    GetMessage( ModuleNumber + StartingNumber    , Instructions );
    GetMessage( ModuleNumber + StartingNumber + 1, BoxTitle     );
END GetInstructionsAndBoxTitle;




  (* Get File Name And Retrieve Flag -

        Parse the incoming context area for a file name extension and the
        retrieve flag.  Any errors are fatal, as they show carelessness in
        the TLWHAT file, something I can't tolerate!  The format is:

        ....   ,TLGETIT( Y *.T$0 )

        'Y' is the retrieve flag (?, Y or N), and *.T$0 is the default 
        file name to look up.

  *)
PROCEDURE GetFileNameAndRetrieveFlag( VAR FileName     : ARRAY OF CHAR;
                                      VAR RetrieveFlag : BOOLEAN ) : BOOLEAN;
VAR
    i, j    : CARDINAL;
    P       : POINTER TO ARRAY [0..99] OF CHAR;
    Default : ARRAY [0..9] OF CHAR;
    s       : ARRAY [0..99] OF CHAR;
    ok      : BOOLEAN;
BEGIN
    P := OverlayContext();
    IF (P <> NIL) THEN
        i := 1;

    (* Absorb leading blanks, then the Retrieve flag. *)

        WHILE (i <= ORD(P^[0])) AND (P^[i] = " ") DO
            INC(i);
        END;
        j := 0;
        WHILE (i <= ORD(P^[0])) AND (P^[i] <> " ") DO
            INC(j);
            s[j] := P^[i];
            INC(i);
        END;
        SetLengthOf( s, j );
        Upshift(s);
        IF (s[1] = "@") THEN    (* 6-Feb-91 RSC hook for tlstart *)
            Remove(s,1,1);
            ok := OverlayPackage(s);    (* 4-Jun-91 RSC More general. *)
            RETURN FALSE;
        ELSIF  (j <> 1) OR 
           ((s[1] <> "Y") AND (s[1] <> "N")) THEN
            GetMessage( ModuleNumber + 3, s );
            Error(s);
            FatalError();
        END;
        RetrieveFlag := (s[1] = "Y");

    (* Absorb leading blanks, then the file name. *)

        WHILE (i <= ORD(P^[0])) AND (P^[i] = " ") DO
            INC(i);
        END;
        j := 0;
        WHILE (i <= ORD(P^[0])) AND (P^[i] <> " ") DO
            INC(j);
            s[j] := P^[i];
            INC(i);
        END;
        SetLengthOf( s, j );
        SetLengthOf(Default, 0 );
        ExpandPath( ProjectMedia, Default, FileName );
        ConcatLS(   FileName, s );
    ELSE
        GetMessage( ModuleNumber + 4, s );
        Error(s);
        FatalError();
    END;

    RETURN TRUE;

END GetFileNameAndRetrieveFlag;



  (* Analyze Extension For Overlay Name -

        Given an extension, figure out which importer ought to be called.
  *)
PROCEDURE AnalyzeExtensionForOverlayName( VAR Extension,
                                              OverlayName : ARRAY OF CHAR
                                        ) : BOOLEAN;
VAR
    ExtensionIndex, i : CARDINAL;
    s                 : ARRAY [0..255] OF CHAR;
    ExtensionTemplate : ARRAY [0..3] OF CHAR;
    Check             : ARRAY [0..3] OF CHAR;
    TempS             : ARRAY [0..41] OF CHAR;


    PROCEDURE IsFullRetrievalCheck() : BOOLEAN;
    BEGIN
        IF (IsFullRetrieval) THEN
            RETURN TRUE;
        ELSE
            GetMessage(ModuleNumber + 5, s);
                        (* "Cannot COMBINE with this kind of file." *)
            Error(s);
            RETURN FALSE;
        END;
    END IsFullRetrievalCheck;

BEGIN
    Upshift(   Extension );
    Procustes( Extension, 3 );

        (* Get a list of extension templates and the overlay to read them. *)
        (* Compare each template against the actual extension.  If they match, *)
        (* use that overlay. *)
        (* Format is multiple occurrences of ((<template>)(<Overlay>)(<Check>))    *)
        (* E.G.  ((T%?)(|TLITL45)(Y))((T$?)(|TLITL4)(Y))((T#?)(|TLITL3)(Y))((T@?)(|TLITL2)(N)) *)

    GetMessage(ModuleNumber+7,s);
    ExtensionIndex := 1;
    LOOP
        ParseBal(s,ExtensionIndex,TempS);           (* (<Extension>)(Overlay>(<Check>)) *)
        IF (LengthOf(TempS)=0) THEN
            EXIT;
        END;
        i := 1;
        ParseBal(TempS,i,ExtensionTemplate);
        IF (PatternSearch(Extension,ExtensionTemplate)=1) THEN
            ParseBal(TempS,i,OverlayName);
            ParseBal(TempS,i,Check);
            IF (Check[0] >= 1C) AND (Check[1] = "Y") THEN   (* 10-Sep-90 RSC  *)
                RETURN TRUE;
            ELSE
                RETURN IsFullRetrievalCheck();
            END;
        END;
    END;

    GetMessage(ModuleNumber + 0, s); (* "Unknown type of file." *)
    ConcatLS(s,Extension);
    Error(s);
    RETURN FALSE;
END AnalyzeExtensionForOverlayName;




  (* Load The Schedule -

        This is the routine passed to (and called by) ImportSelect.

        Here we load the proper overlay (if there is one) and have that
        overlay do the work of loading the file.
  *)
PROCEDURE LoadTheSchedule( VAR Media, 
                               Name,
                               Extension : ARRAY OF CHAR;
                           VAR DisplayErrors : BOOLEAN ) : BOOLEAN;
VAR
    BoxText,
    Context  : ARRAY [0..99] OF CHAR;
    Overlay  : ARRAY [0..19] OF CHAR;
    OverlayResult       : BOOLEAN;

BEGIN
    DisplayErrors := TRUE;
    IF (NOT AnalyzeExtensionForOverlayName( Extension,
                                            Overlay )) THEN
        RETURN FALSE;
    END;

    Copy( Media, Context );
    IF (Context[ ORD(Context[0]) ] <> "\") AND
       (Context[ ORD(Context[0]) ] <> ":") THEN (* 20-Nov-89 WKH  *)
        ConcatS( Context, "\"  );
    END;
    ConcatLS(    Context, Name );
    ConcatS (    Context, "."  );
    ConcatLS(    Context, Extension );
    
    GetMessage( ModuleNumber + 6, BoxText ); (* "One moment, while I load your schedule" *)
    BoxHandle := ProgressBox( BoxText );
    BoxUp := TRUE;

    IF (NOT CallOverlayWithContext( Overlay, ADR(Context) )) THEN
        RETURN FALSE;
    END;

        (*  The overlay agrees to return a "1" in the context if he
            loaded successfully, "0" otherwise.     (3/3/88 EGK)         *)
        (*  Added the additional option of "2" which means the load
            was unsuccessful, but don't display an error.  This was
            need for the OnTarget importer.         (22-Jul-91 PFG)      *)

    DisplayErrors := (Context[1] <> "2");
        
    RETURN (Context[1] = "1");

END LoadTheSchedule;








  (* ImportASchedule - Read a schedule in from disc.

                This handles any of the known schedule types, including
            Lotus, SPIKE, Version 2, Version 1, DBase, etc.

  *)
PROCEDURE ImportASchedule();
VAR
    ok,
    RetrieveFlag : BOOLEAN;
    FileName,
    Instructions : ARRAY [0..99] OF CHAR;
    BoxTitle     : ARRAY [0..29] OF CHAR;
BEGIN
    GetInstructionsAndBoxTitle( Instructions, BoxTitle );

    IF (NOT GetFileNameAndRetrieveFlag( FileName, RetrieveFlag )) THEN
        RETURN;
    END;

    IF (RetrieveFlag) THEN
        RetrieveType := RetrieveAll;
        IsFullRetrieval := TRUE;
    ELSE
        RetrieveType := RetrievePart;
        IsFullRetrieval := FALSE;
    END;

    BoxUp := FALSE;

    ok := (LoadAFile( Instructions, 
                      BoxTitle,
                      FileName,       (* template name, incl. path. *)
                      RetrieveFlag,
                      DontAllowZero,  (* 4/11/89 WKH *)
                      LoadTheSchedule ));

    IF (NOT ok) THEN
        (*  Something went wrong or user cancelled the load.  Don't 
            continue with the overlay package (e.g. for the On Target
            importer) in this case.  *)
        PackageOK := FALSE;         (* 26-Jul-91 PFG *)
    END;

    IF (BoxUp) THEN
        ReleaseBox( BoxHandle );
    END;
    RecomputeAfterLoad( ok );

END ImportASchedule;





BEGIN

    ImportASchedule();

END TLGetIt.

