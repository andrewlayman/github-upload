MODULE TlRollEm;    (*  Do rollup  *)

    (* MODIFICATION HISTORY:

       Aug. 9, 1985  AL   Changed to allow resources to have a rate of
                          zero.  I had to make special provisions in the
                          section that works backwards from total cost to
                          resource amount in this instance.
       11/03/86 LAA     Import ProjectMedia from Schedule rather than 
                        Transfer, changed GetProjectDates because summarizes
                        is not AText, ditto GetRollup and AskForMount.  Also
                        changed parameters of call to Menu in AskForMount to 
                        be compatible with the current version.
       05/11/87 AJL     - Changed to use new Costs module and changed Allocs.
       23-Sep-87 LAA    Imported AHeaderRecord from Transfer rather than
                        LoadCommon.
       30-Oct-87 RSC    Upgraded for new text format for TimeLink (SPIKE 3.0)
       29-Dec-87 LAA    GetDataObject hadn't been converted to 
                        LockFlexStorDataObject.  Removed TLROLLEM message.
       11-Jan-88 LAA    Changed UnlockFlexStorDataObject to UnlockUnchanged
                        where appropriate.
       20-Jan-88 LAA    Made this an installable overlay.
       19-Feb-88 RSC    1) remove baseline rollup for resources.
                        2) Handle non-billable with a dialog box iff there
                           are some billable and some non.
                        3) Improved error handling a little.
        3-Mar-88 EGK    Don't mess with the existing baseline of a linked
                        task.
       31-Oct-88 EGK    If a rollup file is found but has a bad format, we
                        remove the link permanently.
       21-Dec-88 LAA    Changed imports for Laslo reorganization.
        2-Jan-89 RSC    Added references to StringsEqual() rather than Compare().
        6-Jan-89 RSC    Moved "AnOverlayProc" reference.
       27-Jan-89 EGK    Removed specific rollup code.  This overlay now handles
                        only traversal of all tasks to find the right overlays
                        to call to do the linking.
       31-May-89 EGK    Changed GetRollup to ignore I/O errors on removable
                        media, since they might be fixable in AskForMount
                        (drive door open, for example).  Changed AskForMount
                        so that it doesn't prompt the user to "mount" a disk
                        containing an unavailable schedule if that disk is
                        non-removeable, but just puts up a warning box
                        stating that the schedule can't be found.
       10-Aug-89 KKC    Add copyright message.
       09-Oct-89 RSC    Made this overlay non-resident.  Often after this
                        overlay loads, recalc is run, and we want the reserved
                        layer free for recalcs.
        4-Jun-90 RSC    If, in our first exam of every task, we find that
                        there are NO linked tasks, vamoose, rather than
                        traversing the tree a second time.
        3-Nov-90 AJL   -Display a message showing the task and file name
                        during rollup. 
        9-Nov-90 TGS   -Integrate changes from 4.03
       16-Nov-90 AJL   -Any link that used to use TLLNKCLO will now use 
                        TLLNKSUM. 
        6-Nov-91 AJL   -USe a better ReadOnly access mode.
    *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ARollupStatus,
    (* VAR *)                   TaskTree;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Message, Error, FatalError, Burp,
                                WarningBox, MultipleChoiceBox,
                                NotYetImplemented;

FROM Directory              IMPORT
    (* TYPE *)                  AFileNamePart, ASetOfFileNameParts,
    (* PROC *)                  NormalizeFileName, RemovableMedia;

FROM FileAux                IMPORT PrepareForIO,
                                   DisplayFileError, CheckIO;

FROM FileSystem             IMPORT File, Response, Close,
                                   OpenFile, 
                                   FullAccessMode,ReadOnlyMode,
                                   ReadByte, ReadWord;

FROM Links                  IMPORT
        (* CONST *)             LinkOverlayNameLine, LinkFileTypeLine, LinkPathLine,
        (* TYPES *)             ALinkInterface, ARollupContext,
        (* PROC *)              GetSummaryInfoLine;

FROM LStrings               IMPORT LStringToTString, ConcatLS, SetString,
                                   Copy, SubStr, TrimRear, CtoS, ConcatS,
                                   StringsEqual, Insert, SetLengthOf, LengthOf;

FROM MsgFile                IMPORT  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay, CallOverlayWithContext;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM PTaskList              IMPORT
    (* CONST *)                 AlreadyScheduled;

FROM Schedule               IMPORT  ProjectMedia;

FROM SYSTEM                 IMPORT  ADR, SIZE, ADDRESS, TSIZE;

FROM Text                   IMPORT  TextExists, LineExists, CopyLine,
                                    Compress, AText, DiscardText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;


CONST
    ModuleNumber = 13400;    (* For GetMessage *)

VAR
    RollupsCount        : CARDINAL;



PROCEDURE FileComplaint(VAR f:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);    (* "Detail file " *)
    DisplayFileError( f, s );        (* RSC 2/19/88    *)
END FileComplaint;







PROCEDURE LookupRollupFile  (    summarizes    : ARRAY OF CHAR;
                             VAR f             : File          ) : Response;

VAR
    Res         : Response;
    FileName    : ARRAY [0..99] OF CHAR;

BEGIN
    Copy( summarizes, FileName );
    NormalizeFileName(FileName, ASetOfFileNameParts{DevicePart..ExtensionPart});
    LStringToTString( FileName, FileName );
    PrepareForIO(f);
    OpenFile(f, FileName, FullAccessMode + ReadOnlyMode);
    Res := CheckIO(f);

    IF (Res = notdone) THEN
        Res := unknownfile;
    ELSIF (Res <> done) THEN
        FileComplaint(f);
    END;

    RETURN Res;
END LookupRollupFile;






PROCEDURE GetRollup ( Node : ATreeNode) : BOOLEAN;

VAR
    Res         : Response;
    Task        : ATaskPtr;
    s           : ARRAY [0..255] OF CHAR;
    s2,
    summarizes  : ARRAY [0..80] OF CHAR;
    Context     : ARollupContext;
    f           : File;
    ok          : BOOLEAN;
    

    PROCEDURE SetRollupLoadError();
    VAR
        Task        : ATaskPtr;
    BEGIN
        Task := Node^.Methods^.LockFlexStorDataObject (Node);
        Task^.rollupstatus := RollupLoadError;
        Node^.Methods^.UnlockFlexStorDataObject (Node);
    END SetRollupLoadError;


BEGIN
    ok := FALSE;
    GetSummaryInfoLine (Node, LinkPathLine, summarizes);

       (* Display a message showing the task name. *)
    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    GetMessage(ModuleNumber+20, s);
    ConcatLS(s,Task^.taskname);
    ConcatMessage(s,ModuleNumber+21);
    ConcatLS(s,summarizes);
    Message(s);
    Node^.Methods^.UnlockFlexStorDataObject (Node);
    
    Res := LookupRollupFile (summarizes, Context.f);

    IF (Res <> unknownfile) THEN
        IF (Res <> done) THEN

                (*  Probably some kind of I/O error.  If file is on a
                    hard disk, we're SOL.  If it's on a floppy (or some
                    other removable media), we won't mark it with an
                    error here, in case the user can fix the problem in
                    AskForMount (maybe by closing the drive door).
                *)

            IF (NOT RemovableMedia (summarizes)) THEN       (* 5/31/89 EGK *)
                SetRollupLoadError();
            END;

        ELSE
            GetSummaryInfoLine (Node, LinkOverlayNameLine, s);

                (*  For compatibility with version 3.0, look for the old
                    overlay name (which was always TLROLLEM) and change
                    it to TLLNKSUM, which now does the same thing.
                *)

            SetString (s2, "TLROLLEM");
            IF (StringsEqual (s, s2)) THEN
                SetString (s, "TLLNKSUM");
            END;

                (* Version 4 used an overlay called TLLNKCLO to link to
                   specific tasks.  This is now included into the function 
                   of TLLNKSUM. *)

            SetString (s2, "TLLNKCLO");
            IF (StringsEqual (s, s2)) THEN
                SetString (s, "TLLNKSUM");
            END;

            Context.Node := Node;
            IF (CallOverlayWithContext (s, ADR(Context))) THEN
                ok := TRUE;
            ELSE
                SetRollupLoadError();
            END;
        END;
    END;

    Close (Context.f);
    RETURN ok;

END GetRollup;





PROCEDURE LookForRollups    (VAR Node       : ATreeNode;
                                 Context    : ADDRESS   );
VAR
    Task            : ATaskPtr;
BEGIN
    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    IF (Task^.rollupstatus = RollupNotLoaded) THEN
        INC(RollupsCount);
    END;
    Node^.Methods^.UnlockUnchangedDataObject (Node);              (* 11-Jan-88 LAA *)
END LookForRollups;






    (*  Examine all tasks.   Rollup any that are available.  Don't
        complain about any that are not.  *)


PROCEDURE RollupOthers  (      StartNode    : ATreeNode;
                           VAR RollupsCount : CARDINAL     );
VAR
    Node        : ATreeNode;
    Task        : ATaskPtr;
    TempFlag    : BOOLEAN;

BEGIN
    IF (StartNode = NIL) THEN RETURN END;

    Node := StartNode;

    REPEAT
        Task := Node^.Methods^.LockFlexStorDataObject (Node);
        TempFlag := (Task^.rollupstatus = RollupNotLoaded);
        Node^.Methods^.UnlockUnchangedDataObject (Node);          (* 11-Jan-88 LAA *)
        IF (TempFlag) THEN
            IF (GetRollup (Node)) THEN
                DEC (RollupsCount);
            END;
        END;
        Node := Node^.Methods^.NextPreOrder (Node);
        IF (Node = NIL) THEN
            Node := TaskTree^.Methods^.GetFirst (TaskTree);
        END;
    UNTIL (Node = StartNode);
END RollupOthers;





    (*  Loop, examining all tasks, until there are no more needing
        rollup.  Ask for diskettes to be mounted whenever we find
        a task that needs rollup.  After each sucessful file read,
        attempt to rollup any other projects on the same disk. *)



PROCEDURE AskForMount;
VAR
    Choice      : CARDINAL;
    Node        : ATreeNode;
    Task        : ATaskPtr;
    Prefix      : ARRAY [0..127] OF CHAR;
    Choices     : ARRAY [0..30] OF CHAR;
    Name        : ARRAY [0..20] OF CHAR;
    Title       : ARRAY [0..40] OF CHAR;
    Result      : BOOLEAN;
    SkippedFlag : BOOLEAN;
    summarizes  : ARRAY [0..64] OF CHAR;
    DriveName   : ARRAY [0..5] OF CHAR;
    TempFlag    : BOOLEAN;
    
BEGIN
    RollupsCount := 0;

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentAfterChild, 9999,
                                     LookForRollups, NIL);

    (* 4-Jun-90 RSC If there are no rollups to be done, exit now. *)

    IF (RollupsCount = 0) THEN
        RETURN;
    END;


    Node := TaskTree^.Methods^.GetFirst (TaskTree);

    RollupOthers(Node,RollupsCount);  (*  Roll-up any that are already mounted. *)

    SkippedFlag := FALSE;
    LOOP
        IF (Node = NIL) THEN
            IF (SkippedFlag) THEN
                Node := TaskTree^.Methods^.GetFirst (TaskTree);
                SkippedFlag := FALSE;
            ELSE
                EXIT;
            END;
        END;
        Task := Node^.Methods^.LockFlexStorDataObject (Node);
        TempFlag := (Task^.rollupstatus = RollupNotLoaded);
        Node^.Methods^.UnlockUnchangedDataObject (Node);          (* 11-Jan-88 LAA *)

        IF (TempFlag) THEN
            GetSummaryInfoLine (Node, LinkPathLine, summarizes);
            IF (RemovableMedia (summarizes)) THEN           (* 5/31/89 EGK *)
                GetMessage(ModuleNumber+11,Prefix);   (*  "Directory "  *)
                ConcatLS(Prefix,ProjectMedia);
                Message(Prefix);
                GetMessage(ModuleNumber+12,Prefix);   (*  "Please insert disk with rollup project "  *)

                ConcatLS(Prefix,summarizes);
                ConcatMessage (Prefix, ModuleNumber+13);    (* " in drive " *)
                SubStr (summarizes, DriveName, 1, 2);
                ConcatLS (Prefix, DriveName);

                GetMessage(ModuleNumber+14,Choices);   (*  "Ready,Not Available"  *)
                IF (RollupsCount > 1) THEN
                    ConcatMessage(Choices,ModuleNumber+15);   (*  ",Skip"  *)
                END;
                Choice := 1;
                SetLengthOf (Title, 0);
                Result := MultipleChoiceBox (Prefix, Title, OfferHelp, Title,
                                         Choices, Choice);
                Name[0] := 0C;
                Message(Name);
            ELSE
                GetMessage (ModuleNumber+17, Prefix);       (* "Linked schedule " *)
                ConcatLS (Prefix, summarizes);
                ConcatMessage (Prefix, ModuleNumber+18);    (* " is no longer available" *)
                GetMessage (ModuleNumber+19, Title);        (* "Link problem" *)
                WarningBox (Prefix, Title, OfferHelp);
                Result := TRUE;
                Choice := 2;        (* Not available *)
            END;

            IF (NOT Result) OR (Choice=3) THEN
                SkippedFlag := TRUE;
            ELSIF (Choice = 1) THEN
                IF (GetRollup(Node)) THEN
                    DEC(RollupsCount);
                    RollupOthers(Node,RollupsCount);
                ELSE
                    GetMessage(ModuleNumber+16,Prefix);   (*  "I cannot find project "  *)
                    ConcatLS(Prefix,summarizes);
                    Message(Prefix);
                    SkippedFlag := TRUE;
                END;
            ELSE
                Task := Node^.Methods^.LockFlexStorDataObject (Node);
                Task^.rollupstatus := RollupNotAvailable;
                Node^.Methods^.UnlockFlexStorDataObject (Node);
            END;
        END;
        Node := Node^.Methods^.NextPreOrder (Node);
    END;
END AskForMount;





PROCEDURE TlRollEmBody();
VAR
    Copyright       : ARRAY[0..50] OF CHAR;
BEGIN                       (* TlRollEmBody *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    AskForMount;

END TlRollEmBody;


BEGIN                       (* TlRollEm *)

    (* Removed reserved-layer status.       9-Oct-89 RSC. *)
    TlRollEmBody();

END TlRollEm.



