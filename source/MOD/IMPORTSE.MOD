IMPLEMENTATION MODULE ImportSelect;

(*  =========================================================================
    Last Edit : August 13, 1991 9:51PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

       Oct. 6, 1985  AJL - Restore the original schedule name
                           after a Combine even if there was
                           an error loading the file.
       Mar. 23 1986  AJL - Add FindNonZeroScale to SanitizeTask;
                         - Reset ConfigSaved if ProjectName changed.
       25 Jul 86     AJL - Rearranged the order of assignments in
                           SanitizeTask.
        11/04/86 LAA    In LoadAFile, changed SetState(Filtered) to 
                        UnSetState(Scheduled).  The previous condition didn't
                        make sense, and was setting the Filtered state when
                        the antecedant states were not yet set.
        11/27/86 LAA    Removed import of Lights, but imported 
                        DisplayScheduleLight, which is used if the project
                        name has changed.
        03/20/87 EGK    Call SetAsOfDate procedure after a file is read in.
        04-Jun-87 LAA   Changed parameters for TraverseTree.
        6/16/87 EGK     Call UnSetState (Scheduled) only if the as-of date
                        changes after reading in the file.
        29-Jun-87 AJL   Added Notices.
         2-Jul-87 RSC   Removed disc check for media.  This way, Direct411
                        is ALWAYS called in "ChooseAFile"
        10-Sep-87 RSC   Preserve the returned path from direct 411, and do
                        not automaticly clobber the project media and 
                        project name.  It is up to the "LoadingProc" passed
                        to LoadAFile to update project media and file if
                        that is a reasonable thing to do.  Also, switch the
                        order of selecting and erasing.  Erase AFTER selecting.
        01-Feb-88 LAA   Enlarged the string holding the title of the Really
                        Erase box.
        02-Feb-88 EGK   Check for nonstandard layouts and filters in memory
                        along with tasks and resources.
        24-Feb-88 AJL   Enlarged string, s, in the LoadAFileProc;
        01-Mar-88 LAA   When putting up box for directory assistance, start
                        at GanttWStart rather than MenuStart + 1.  That way,
                        if the user presses F2 for the form, the form help
                        doesn't wipe out the top of the box.
        02-Mar-88 AJL  -Removed a call to FindNonZeroScale from SanitizeTask. 
                       -Use UnlockUnchanged... in SanitizeTask if no changes
                        to the task were made.  This should speed up file 
                        loading by not marking FlexStor buffers as dirty
                        unnecessarily.
                       -After loading, if any tasks are marked as needing
                        recomputation, set recalc needed. 
        28-Mar-88 RSC  -Split out the erasing of schedules from loading files.
        02-Jan-89 RSC  -Removed references to Compare() (not used).
        05-Mar-89 WKH  -Added support for schedule locking.  Also corrected 
                        Roger's error of not using a leading zero in the months
                        field of the datestamp in the previous comment.
        07-Apr-89 WKH  -Only try to lock retrieval of full schedule's.
        07-May-89 WKH  -Added lock class support
        04-Jun-89 EGK   Stopped putting hyphens in front of comments.  Put
                        in explicit call to SendNotices with BeforeActing,
                        since Permission() doesn't do it for us any more.
        06-Jun-89 AJL  -Put Filters into FlexStor.
        28-Jul-89 WKH  -Check for existance of a directory/file before actually
                        trying to read it in.
        02-Aug-89 WKH  -Well, the above fix works great except for importing.
                        Extension was the problem.  Fixed.
        23-Aug-89 RSC  -Call the TLERASE overlay to actually erase the
                        schedule.  This saves beaucoup bytes.
        25-Oct-89 RSC  -Enhance the way we clean up the project name if
                        schedule loading fails.  In particular, if we cannot
                        LOCK the file, rease the name.
        10-Nov-89 RSC  -Oops.  As per bug # 1735, I was a little too over-
                        zealous with my fix of 25-Oct.  Backed off one of
                        the changes.
        29-Nov-89 RSC  - 1) Again, back off further with the zapping of the
                            names.
                         2) Thanks to Wayne, I dicovered that I need to
                            unlock the schedule when I zap the name.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        01-Jun-90 AJL   Replaced the PlanLevel variables from Planner with
                        use of the CalculationState array.
        09-Jun-90 AJL   Get the current version file extension from the phrases.
        07-Jul-90 AJL   Don't prompt before a file retrieve unless the current
                        schedule has not been saved.

        12-Sep-90 RSC   Fixed for new Allocs.Def

        14-Sep-90 RSC   Import the file extension rather than hardcoding it.

        24-Oct-90 AJL   Only ask the question about retrieving the new schedule
                        without saving the old one once.
        25-Jan-91 RSC   Moved SanitizeTask to the individual schedule
                        importers.
        26-Jun-91 PFG   In TryToEraseSchedule(), don't check ConfigSaved
                        before erasing; only check ScheduleSaved.  Checking
                        ConfigSaved was causing the "Abandon schedule in
                        memory?" message to appear even when the schedule in
                        memory hadn't been changed.
        22-Jul-91 PFG   Added "DisplayErrors" parameter to ALoadingProc
                        so that importer can do the error reporting itself 
                        when needed.
        13-Aug-91 EGK   In LoadAFile, Use ExpandPath instead of Copy to set
                        up NewProjectMedia.  For the RetrieveDammit case,
                        this ensures that the directory will contain the
                        trailing backslash.  The Eve "disappearing file bug"
                        was happening whenever ProjectMedia didn't have the
                        backslash, and we were blindly concatenating the
                        schedule name to it.
        10-Sep-91 LAA   In LoadAFile, we were reading a phrase which had
                        belonged to TLStart (and which I'd previously 
                        removed).  We now use CurrentFileExtension, as we
                        should.
    =========================================================================
*)


FROM Allocs       IMPORT
    (* TYPE *)          ATaskStatus, ATaskPtr,
    (* PROC *)          TaskTree;

FROM AsOf         IMPORT
    (* TYPE *)          AsOfDate,
    (* PROC *)          SetAsOfDate;

FROM ChartControl IMPORT  AChartState, UnSetState;

FROM ChartForms   IMPORT
    (* TYPE *)          AChartFormatPtr,
    (* VAR  *)          LayoutTree;

FROM Dialog       IMPORT
    (* PROC *)          Message, Error, FatalError, Burp,
                        ContinuationBox, MultipleChoiceBox,
                        WarningBox, ADialogOption;

FROM Direct411    IMPORT  GiveDirectoryAssistance,
                          AQualificationProcedure;

FROM Directory    IMPORT  NormalizeFileName,
                          ExtractFileNameParts, AFileNamePart,
                          ASetOfFileNameParts,
                          MaximumDeviceNameLength, MaximumPathNameLength,
                          MaximumFileNameLength, MaximumExtensionLength,
                          ExpandPath;

FROM FileOpen     IMPORT  RequestFileFind;

FROM FilterRc     IMPORT
    (* TYPE *)          AFilterRecordPointer,
    (* VAR  *)          FilterTree;

FROM Kbio         IMPORT  avidmode, maxcol,
                          PutString, ascreeny;

FROM Layout       IMPORT  MenuStart, MenuEnd, GanttWEnd, GanttWStart;

FROM LStrings     IMPORT  Fill, SubStr, SetString, ConcatLS, ConcatS,
                          TrimRear, LJust, Procustes,
                          LengthOf, Copy, Insert, Search, Remove;

FROM Memos        IMPORT  MemoTree;

FROM MsgFile      IMPORT  GetMessage, ConcatMessage, DisplayMessage;

FROM Notices      IMPORT
    (* TYPE *)            AnOccasion, AStep,
    (* PROC *)            Permission, SendNotices;

FROM Overlays     IMPORT
    (* PROC *)            CallOverlayWithContext;

FROM Planner      IMPORT 
    (* TYPE *)            ACalcComponent, AWhenToCalc, 
    (* VAR *)             ScheduleComputedOk, ScheduleEndDate,
                          CalculationState, Levelling,
    (* PROC *)            Pert; 

FROM RsrcMod      IMPORT
    (* VARS *)            ResourceTree;

FROM Schedule     IMPORT  AScheduleLockClass, ConfigSaved, ScheduleSaved, 
                          Loaded, ProjectName, DisplayScheduleLight,
                          RetrievalName, ProjectMedia, LockSchedule,
                          UnLockSchedule,
    (* CONST *)           CurrentFileExtension;


FROM Space        IMPORT  HeapAvailable;

FROM SYSTEM       IMPORT
    (* TYPE *)            ADDRESS, ADR;

FROM Timei        IMPORT
    (* TYPE *)            ADate,
    (* VAR  *)            Today,
    (* PROC *)            FindToday;

FROM TimeXlate    IMPORT
    (* PROC *)            BigTimeToCalendarTime;

FROM Transfer     IMPORT  RetrieveType, ARetrieveType, RetrieveDammit;

FROM TreeObjects  IMPORT
    (* TYPE *)            ATreeNode, ATreeOrder;




CONST
    ModuleNumber = 10500;   (* For GetMessage *)
    MAXCARDINAL  = 65535;






PROCEDURE WarnOfLoadError;
VAR
    S : ARRAY [0..255] OF CHAR;
    Title : ARRAY [0..10] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,Title);   (* "Load Error" *)
        (*  "$WARNING:$Not all of schedule was retrieved.$Schedule may be wrong or incomplete.$$"  *)
        (*  "(Press [Esc] to continue.)"  *)
    GetMessage(ModuleNumber+2,S);
    WarningBox(S,Title,NoHelp);
    SendNotices(ModelLoad,FailureToAct,NIL);
END WarnOfLoadError;











PROCEDURE NonStandardFiltersExist() : BOOLEAN;

VAR
    Node                : ATreeNode;
    FilterRecord        : AFilterRecordPointer;
    Found               : BOOLEAN;

BEGIN

    Found := FALSE;
    Node := FilterTree^.Methods^.GetFirst (FilterTree);
    WHILE (Node <> NIL) AND (NOT Found) DO
        FilterRecord := Node^.Methods^.LockFlexStorDataObject (Node);
        IF NOT (0 IN FilterRecord^.FilterFlags) THEN
            Found := TRUE;                          (* not saved in config *)
        END;
        Node^.Methods^.UnlockUnchangedDataObject (Node);
        Node := Node^.Methods^.GetNext (Node);
    END;
    RETURN Found;

END NonStandardFiltersExist;




PROCEDURE NonStandardLayoutsExist() : BOOLEAN;

VAR
    Node                : ATreeNode;
    LayoutRecord        : AChartFormatPtr;
    Found               : BOOLEAN;

BEGIN

    Found := FALSE;
    Node := LayoutTree^.Methods^.GetFirst (LayoutTree);
    WHILE (Node <> NIL) AND (NOT Found) DO
        LayoutRecord := Node^.Methods^.GetDataObject (Node);
        IF NOT (0 IN LayoutRecord^.LayoutFlags) THEN
            Found := TRUE;                          (* not saved in config *)
        END;
        Node := Node^.Methods^.GetNext (Node);
    END;
    RETURN Found;

END NonStandardLayoutsExist;




PROCEDURE ChooseAFile( VAR Instructions,
                           BoxTitle,
                           FileNameIn,
                           ProjectName : ARRAY OF CHAR;
                           Qualifies   : AQualificationProcedure;
                       VAR FileNameOut : ARRAY OF CHAR ) : BOOLEAN;
VAR
    CursorName : ARRAY [0..99] OF CHAR;
BEGIN
    Copy( ProjectName, CursorName );

    Message(Instructions);

    Copy( FileNameIn, FileNameOut );
    NormalizeFileName( FileNameOut, ASetOfFileNameParts{DevicePart..ExtensionPart});

        (*  Look up the current project, or maybe
            a different one.  If the user picks one,
            it will be returned in "s". *)

    RETURN (GiveDirectoryAssistance(GanttWStart,                  (* 01-Mar-88 LAA *)
                                    GanttWEnd,
                                    BoxTitle,
                                    FileNameOut,
                                    CursorName, (* Returns the date. ugh. *)
                                    Qualifies));
END ChooseAFile;




PROCEDURE TryToEraseSchedule() : BOOLEAN;
VAR
    Selection            : CARDINAL;
    s                    : ARRAY [0..255] OF CHAR;
    MenuText             : ARRAY [0..121] OF CHAR;
    Prefix               : ARRAY [0..79]  OF CHAR;
    Title                : ARRAY [0..39]  OF CHAR;
    ok,
    TasksInMemory        : BOOLEAN;
    RsrcsInMemory        : BOOLEAN;
    FiltersInMemory      : BOOLEAN;
    LayoutsInMemory      : BOOLEAN;
    NotesInMemory        : BOOLEAN;
BEGIN

    TasksInMemory   := (TaskTree^.Methods^.GetFirst (TaskTree) <> NIL);    (* There are existing tasks left over. *)
    RsrcsInMemory   := (ResourceTree^.Methods^.GetFirst (ResourceTree) <> NIL);
    FiltersInMemory := NonStandardFiltersExist();       (* 2/2/88 EGK *)
    LayoutsInMemory := NonStandardLayoutsExist();       (* 2/2/88 EGK *)
    NotesInMemory   := (MemoTree^.Methods^.GetFirst( MemoTree ) <> NIL);

    ok := TRUE;
    IF (RsrcsInMemory  OR TasksInMemory OR  NotesInMemory OR
       FiltersInMemory OR LayoutsInMemory) THEN
        IF (ScheduleSaved) THEN     (* 26-Jun-91 PFG  Used to be "AND ConfigSaved" *)
            ok := TRUE;
        ELSE
            GetMessage(ModuleNumber+3,s);        
            GetMessage(ModuleNumber+10,Title);   
            GetMessage(ModuleNumber+4,Prefix);   
            GetMessage(ModuleNumber+5,MenuText); (*  "Cancel,Abandon"  *)
            Selection := 1;
            ok := (MultipleChoiceBox( s, Title, OfferHelp, Prefix, MenuText, Selection )) AND
                  (Selection = 2);
        END;

        IF (ok) THEN
            SetString( s, "TLERASE" );
            SetString( Title, "N" );
            ok := CallOverlayWithContext( s, ADR(Title) );
            TasksInMemory := FALSE;
            ok := (ok AND HeapAvailable());
        END;
        
    END;

    RETURN ok;

END TryToEraseSchedule;





  (* Load a File.  RSC 9/10/87 - DOES NOT SAVE PROJECT NAME OR PROJECT MEDIA.
                   THE LOADING PROC IS NOW RESPONSIBLE FOR THAT!!
  *)
PROCEDURE LoadAFile(VAR Instructions: ARRAY OF CHAR;
                    VAR BoxTitle    : ARRAY OF CHAR;
                    VAR FileName    : ARRAY OF CHAR;
                        MustErase   : BOOLEAN;
                        Qualifies   : AQualificationProcedure;
                    LoadingProc     : ALoadingProc):BOOLEAN;
VAR
    OldAsOfDate          : ADate;
    Selection            : CARDINAL;
    Position             : CARDINAL;
    Length               : CARDINAL;
    s                    : ARRAY [0..255] OF CHAR;
    OriginalProjectName  : ARRAY [0..MaximumFileNameLength] OF CHAR;
    OriginalProjectMedia : ARRAY [0..MaximumDeviceNameLength+MaximumPathNameLength+2] OF CHAR;
    NewProjectName       : ARRAY [0..MaximumFileNameLength] OF CHAR;
    NewProjectMedia      : ARRAY [0..MaximumDeviceNameLength+MaximumPathNameLength+2] OF CHAR;
    Path                 : ARRAY [0..MaximumPathNameLength]  OF CHAR;
    Extension            : ARRAY [0..MaximumExtensionLength] OF CHAR;
    Title                : ARRAY [0..39] OF CHAR;                 (* 01-Feb-88 LAA *)
    TasksInMemory        : BOOLEAN;
    NewProjectFullName   : ARRAY [0..12] OF CHAR;                 (* 04-Apr-89 WKH *)
    OKToTryLoad          : BOOLEAN;                               (* 07-Apr-89 WKH *)           
    DisplayErrors        : BOOLEAN;                     (* 22-Jul-91 PFG *)


    PROCEDURE ErrorCleanup();   (* 25-Oct-89 RSC moved here *)
    BEGIN
        IF (MustErase) THEN
            ProjectName[0] := 0C; (* If it wouldn't load, erase the name. *)
            UnLockSchedule(DualLock);   (* 29-Nov-89 RSC/WKH *)
        END;
    END ErrorCleanup;

BEGIN
    s[0] := 0C;
    Message(s);
    LJust(ProjectMedia);
    LJust(ProjectName);
    Copy( ProjectName,  OriginalProjectName  );
    Copy( ProjectMedia, OriginalProjectMedia );
    Copy( ProjectName,       NewProjectName  );
    IF (LengthOf(NewProjectName)=0) THEN
        Copy( RetrievalName, NewProjectName );
    END;

        (* RetrieveDammit will shortcut the selection of a project. *)

    ExpandPath (ProjectMedia, s, NewProjectMedia);  (* 8/13/91 EGK *)
    IF (RetrieveDammit) THEN
            (*  Convert ".5T0" into "5T0"  *)
        SubStr( CurrentFileExtension, Extension, 2, 3 );       (* 10-Sep-91 *)
    ELSE
        IF (NOT ChooseAFile( Instructions,
                             BoxTitle,
                             FileName, 
                             NewProjectName, (* CURSOR NAME *)
                             Qualifies, 
                             s) ) THEN
            RETURN FALSE;
        END;
        ExtractFileNameParts( s, NewProjectMedia, Path, NewProjectName, Extension );
        ConcatLS( NewProjectMedia, Path );
    END;

    IF (MustErase) THEN
        IF (NOT TryToEraseSchedule()) THEN 
            RETURN FALSE; 
        END;
    END;

        (* Call the client-supplied procedure to actually load the
        file. *)

    IF (RetrieveType = RetrieveAll) THEN
        Copy(NewProjectName, NewProjectFullName);
        IF (LengthOf(Extension) > 0) THEN
            ConcatS(NewProjectFullName, ".");
            ConcatLS(NewProjectFullName, Extension);
        END;

        OKToTryLoad := RequestFileFind(NewProjectMedia,
                                       NewProjectFullName,
                                       s,
                                       s,
                                       s);   (* 28-Jul-89 WKH *)


        SetString(s, ".");
        Position := Search(NewProjectFullName, s, 1);

        IF (Position > 0) THEN
            Length := LengthOf(NewProjectFullName) - Position + 1;
            Remove(NewProjectFullName, Position, Length);
            ConcatLS(NewProjectFullName, CurrentFileExtension);  (* 14-Sep-90 RSC  *)
        END;

        OKToTryLoad := OKToTryLoad AND LockSchedule(NewProjectMedia, 
                                                    NewProjectFullName, 
                                                    TRUE, 
                                                    DualLock); (* 4/5/89 WKH *)
    ELSE
        OKToTryLoad := TRUE;
    END;
    
    IF (OKToTryLoad) THEN
        IF (Permission(ModelLoad,NIL)) THEN
            SendNotices (ModelLoad, BeforeActing, NIL);     (* 6/4/89 EGK *)
            IF (LoadingProc(NewProjectMedia, NewProjectName,
                            Extension, DisplayErrors)) THEN

                TasksInMemory := (TaskTree^.Methods^.GetFirst (TaskTree) <> NIL);
                Today         := FindToday();

                OldAsOfDate := AsOfDate;
                SetAsOfDate();                          (* 3/20/87   EGK  *)
                IF (AsOfDate <> OldAsOfDate) AND (TasksInMemory) THEN
                    UnSetState (Scheduled);
                END;

                SendNotices(ModelLoad,AfterActing,NIL);
                Loaded := TRUE;
                IF (NOT TasksInMemory) THEN
                    ScheduleSaved := TRUE;
                END;

                    (* Most people would not want Automatic Leveling. *)
                IF (Levelling) AND
                   (CalculationState[Scheduling].When = AutoCalc) THEN
                    GetMessage(ModuleNumber+8,s);     (*  "I notice that you have Automatic Resource Leveling on."  *)
                    GetMessage(ModuleNumber+9,Title); (*  "Make it MANUAL (F9) instead?"  *)
                    IF (ContinuationBox(s, Title, OfferHelp )) THEN
                        CalculationState[Scheduling].When := ManualCalc;
                    END;
                END;
                IF (MustErase) THEN
                    Copy( NewProjectMedia, ProjectMedia );  (* Save these names. *)
                    Copy( NewProjectName,  ProjectName  );
                END;

            ELSE
                ErrorCleanup();     (* 25-Oct-89 RSC *)
                IF (DisplayErrors) THEN         (* 22-Jul-91 PFG *)
                    WarnOfLoadError;
                END;
            END;
        END;

        DisplayScheduleLight();   (* We may have changed the project name. *)

        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END LoadAFile;








BEGIN
END ImportSelect.


