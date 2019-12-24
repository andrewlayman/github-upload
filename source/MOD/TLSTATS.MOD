MODULE TLStats;

    (* This program displays a status screen for Time Line by computing
       a few values and then calling a help screen which formats and
       displays them.  The help screen displays a number of other 
       values as well because it contains keywords which are evaluated
       by KeywdSub. 
    *)


    (* MODIFICATION HISTORY:
        7-Nov-89  AJL  - Original version.
       31-Jul-90  RSC  - Removed Mouse stuff, added UMB memory.
       21-Feb-91  RSC  - Fixed UMB, it was reporting paragraphs.
       11-Mar-91  AJL  - Report the EMB free and total.
                       - Report the run line.
       21-Mar-91  RSC  - Added "Na" strings when a memory type is
                         not available.
                       - Made the DOS free take into account free
                         heap space.
                       - Check for storage classes "Not Available"
                         and put in a "NA" where appropriate.
                       - Because of the above, the "KB" is here and
                         not hardcoded into the help text.
        2-Apr-91  AJL  - Added MS Windows checking.
                       - Use the procs in Allocs and Rsrcmod to query
                         the number of tasks in resources.
        3-Apr-91  AJL  - Increase the window size by one line by starting at
                         the top line of the screen.
       20-Apr-91  AJL  - Remove display of the run line, because it is not
                         reliable after an Exit to DOS, and also because
                         it does not display the effect of the SET TIMELINE
                         = environment variable, whose omission could be
                         misleading.
    *)

FROM Allocs    IMPORT
    (* PROC *)          QueryNumberOfTasks;

FROM DOSMemory   IMPORT 
    (* PROC *)          DOSAvail;

FROM EmsStorage     IMPORT
    (* CONST *)         EMSPageSizeInBytes,
    (* PROC *)          EMSStatistics;

FROM Helper         IMPORT
    (* TYPE *)          AScreenAction,
    (* PROC *)          GiveHelp;

FROM Layout         IMPORT
    (* VAR *)           GanttWEnd;

FROM LMouse         IMPORT
    (* PROC *)          GetMouseType;

FROM LStrings       IMPORT
    (* PROC *)          SubStr, SetString, TrimFront, ConcatS,
                        SetLengthOf, LengthOf, Fill, ConcatLS, Remove,
                        Copy, Insert, Procustes, CtoS, TrimRear;

FROM Mouse          IMPORT
    (* PROC *)          MousePresent;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          RegisterForNotices, Permission, SendNotices;

FROM OurPSP     IMPORT
    (* VAR *)       OurPSPAddress;

FROM RcDynMem    IMPORT
    (* TYPE *)      ABlock,
    (* PROC *)      CountOfFree;

FROM RsrcMod     IMPORT
    (* PROC *)          QueryNumberOfResources;

FROM RTSMain     IMPORT
    (* VAR *)       blockList;

FROM SegWords    IMPORT 
    (* PROC *)          WordNumber;

FROM SYSTEM      IMPORT
    (* TYPE *)          ADDRESS,
    (* PROC *)          ADR;

FROM TreeObjects IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder,
    (* PROC *)          ValidateTree, ValidateTreeNode;

FROM Windows     IMPORT
    (* TYPE *)          AWindowsType,
    (* PROC *)          WindowsIsRunning;

FROM XMSMem      IMPORT
    (* VAR  *)          HMAPresent,
    (* PROC *)          UMBAvailable, EMBAvailable, VideoAvailable;





CONST
    ModuleNumber = 29800;





        (* GetParmLine has a counterpart
           in the ParmLine module. *)

(*   This procedure is not reliable after an Exit To Dos.
PROCEDURE GetParmLine( VAR ParameterLine : ARRAY OF CHAR);

TYPE PSP = RECORD
                stuff: ARRAY [1..128] OF CHAR;
                text : ARRAY [0..127] OF CHAR
           END;

VAR PSPPtr : POINTER TO PSP;
    i      : CARDINAL;

BEGIN 

    PSPPtr := OurPSPAddress; 
    Copy(PSPPtr^.text, ParameterLine);

END GetParmLine;
*)












PROCEDURE EnoughFree() : BOOLEAN;
BEGIN                       (* EnoughFree *)
    RETURN FALSE;  (* We can NEVER get enough memory! *)
END EnoughFree;




PROCEDURE DosMemLeft():CARDINAL;



    PROCEDURE SumHeap() : CARDINAL;


         (* From Storage:    *)

    TYPE
        BlockPtr = RECORD
            CASE BOOLEAN OF
              TRUE  : ptr : POINTER TO DOSBlockHeader |
              FALSE : adr : ADDRESS;
            END;
        END;

        DOSBlockHeader = RECORD
            nextBlockSeg,
            prevBlockSeg  : CARDINAL;
            nextProceSeg,
            prevProceSeg  : CARDINAL;
            blockParaSize : CARDINAL;
            dynamic       : BOOLEAN;
            reserved      : ARRAY [0..4] OF CHAR;
        END;


    VAR
          a         : BlockPtr;
          TotalSize : CARDINAL;
          Free      : CARDINAL;
    BEGIN
        TotalSize := 0;
        a.adr := blockList;
        WHILE a.adr.SEGMENT # 0 DO
            IF a.ptr^.dynamic THEN
                INC( a.adr.SEGMENT );
                Free := CountOfFree(ABlock(a.adr), 16); (* Number of paras *)
                INC( TotalSize, Free );
                DEC( a.adr.SEGMENT );
            END;
            a.adr.SEGMENT := a.ptr^.nextBlockSeg
        END; (* while a # NIL *)

        RETURN TotalSize;

    END SumHeap;

BEGIN
        (* Free all freeable memory. *)
    SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree));

        (* Don't round, as we probably counted some small fragments,
           and we don't want to sound too optimistic.
        *)
    RETURN (DOSAvail() + SumHeap()) DIV (1024 DIV 16);

END DosMemLeft;






PROCEDURE CrushSpace( VAR S : ARRAY OF CHAR);
VAR
    i : CARDINAL;
BEGIN
    i := 1;
    WHILE (i <= LengthOf(S)) DO
        IF (S[i] = " ") AND ((i=1) OR (S[i-1] = " ")) THEN
            Remove(S,i,1);
        ELSE
            INC(i);
        END;
    END;
END CrushSpace;




PROCEDURE DoTheStats;
VAR
    A       : ADDRESS;
    Total,
    Free,
    i       : CARDINAL;
    Subject : ARRAY [0..257] OF CHAR;
    S       : ARRAY [0..255] OF CHAR;
    S31     : ARRAY [0..31] OF CHAR;
    Na      : ARRAY [0..9]   OF CHAR;
    Kb      : ARRAY [0..9]   OF CHAR;

    PROCEDURE KBtoS(     KiloBytes : CARDINAL;
                     VAR s         : ARRAY OF CHAR );
    BEGIN
        CtoS(KiloBytes,s);   (* Turn paras into KB  *)
        ConcatLS( s, Kb );
    END KBtoS;

BEGIN
    GetMessage( ModuleNumber + 1, Na );  (* "NA" *) (* 21-Mar-91 RSC  *)
    GetMessage( ModuleNumber + 2, Kb );  (* "KB" *) (* 21-Mar-91 RSC  *)


        (* Get the name of the help panel. *)
    SetString(Subject,".STATS");
    ConcatS(Subject,"((");

        (* Tasks  1  *)
    CtoS(QueryNumberOfTasks(),S);
    ConcatLS(Subject,S);
    ConcatS(Subject,")(");
        (* Resources 2  *)
    CtoS(QueryNumberOfResources(),S);
    ConcatLS(Subject,S);
    ConcatS(Subject,")(");
        (* DOS Memory free, in KB,  3   *)
    KBtoS(DosMemLeft(),S);
    ConcatLS(Subject,S);
    ConcatS(Subject,")(");

        (* 31-Jul-90 RSC Added UMB   4   *)

    Free := UMBAvailable();  (* Not even one lousy paragraph?? *)
    IF (Free > 0) THEN
        KBtoS(Free DIV (1024 DIV 16),S);   (* Turn paras into KB  *)
        ConcatLS( Subject, S );
    ELSE
        ConcatLS(Subject,Na);
    END;

    ConcatS(Subject,")(");

        (* 11-Mar-91 AJL Added EMB.  Free/Total 5/6 *)

    Free := EMBAvailable(Total);
    IF (Total = 0) AND (Free = 0) THEN
        ConcatLS(Subject,Na);
        ConcatS(Subject,")(");
        ConcatLS(Subject,Na);
    ELSE
        KBtoS(Free,S);
        ConcatLS( Subject, S );
        ConcatS(Subject,")(");
        KBtoS(Total,S);
        ConcatLS( Subject, S );
    END;
    ConcatS(Subject,")(");

        (* EMS Free/Total    7/8 *)

    EMSStatistics(Total,Free,i);
    IF (Total = 0) AND (Free = 0) THEN
        ConcatLS(Subject,Na);
        ConcatS(Subject,")(");
        ConcatLS(Subject,Na);
    ELSE
        KBtoS(Free * (EMSPageSizeInBytes DIV 1024), S);
        ConcatLS( Subject, S );
        ConcatS(Subject,")(");
        KBtoS(Total * (EMSPageSizeInBytes DIV 1024), S);
        ConcatLS( Subject, S );
    END;
    ConcatS(Subject,")(");


        (* HMA Free/Total    9/10 *)

    IF (HMAPresent) THEN
        A.SEGMENT := 0FFFFH;
        A.OFFSET  := 00010H;
        Free := CountOfFree(ABlock(A), 16) DIV (1024 DIV 16);
        KBtoS(Free, S);
        ConcatLS( Subject, S );
        ConcatS(Subject,")(");
        KBtoS(64, S);
        ConcatLS( Subject, S );
    ELSE
        ConcatLS(Subject,Na);
        ConcatS(Subject,")(");
        ConcatLS(Subject,Na);
    END;
    ConcatS(Subject,")(");


        (* VIDEO Free/Total  11/12 *)

    VideoAvailable(Free,Total);
    IF (Total = 0) AND (Free = 0) THEN
        ConcatLS(Subject,Na);
        ConcatS(Subject,")(");
        ConcatLS(Subject,Na);
    ELSE
        KBtoS(Free, S);
        ConcatLS( Subject, S );
        ConcatS(Subject,")(");
        KBtoS(Total, S);
        ConcatLS( Subject, S );
    END;
    ConcatS(Subject,")(");


        (* The Windows Type #13 *)

    GetMessage( ModuleNumber + 3, S);
    WordNumber(S,ORD(WindowsIsRunning())+1,S31);
    ConcatLS(Subject,S31);

    ConcatS(Subject,"))");
    GiveHelp(Subject,0,GanttWEnd,RestoreTheScreen);
END DoTheStats;



BEGIN
    DoTheStats();
END TLStats.

