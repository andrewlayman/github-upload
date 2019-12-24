MODULE PMDPatch;

(*  =========================================================================
    Last Edit : July 1, 1991 9:50AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Patch a PMD to be readable, even with the WOOSH overlay manager.

    MODIFICATION HISTORY:

    RSC 27-Jun-91  First version.

    =========================================================================
*)

FROM OurPSP     IMPORT
    (* VAR *)       OurPSPAddress;

FROM SYSTEM     IMPORT
    (* CONST *)     AX, BX, CX, DX,
    (* TYPE *)      ADDRESS,
    (* PROC *)      TSIZE, ADR, DOSCALL, SWI, SETREG;






(* In the PMD, the first three records are, in this order,

        - PMDHeader
        - PMDSysBlock
        - PMDTable

    Then comes the BlockTable

        - These identify what memory addresses are dumped.  Each record
          is of type APMDTableEntry.  There are PMDHeader.blkCount of them.
          Each is EntrySize (12) bytes.

        - First comes the entry for the low 1024 bytes of ram from
          0:0 to 0:400H for the interrupt vectors.

        - Then comes one for each overlay in the overlay chain for
          the current process.

        - Then comes one for each memory block in the block list

        - Then comes one for the video area

    Then come the memory blocks

        - These start at file offset ??

        - Each is a raw dump of bytes.

        - They are referenced by the BlockTable records.

        - First is the 1024 byte interrupt table (0:0 to 0:400H).

        - Then comes memory for each overlay in the overlay chain for
          the current process.

        - Then comes each memory block in the block list

        - Then comes the video area

*)



TYPE
    ADiskAddress = LONGINT;


    APMDHeader = RECORD
        version,     (* DW 0              ; PMD version                                *)
        target,      (* DW 0              ; target ID (0 for resident)                 *)
        blkCount,    (* DW 4              ; number of information blocks               *)
        progNamePos, (* DW NamePos        ; position of the program name               *)
        sysBlockPos, (* DW SysBlockPos    ; position of the system information block   *)
        crtBlockPos, (* DW CrtBlockPos    ; position of the CRT information block      *)
        tablePos     (* DW TablePos       ; position of the memory block table         *)
                 : CARDINAL;
        progName : ARRAY [1..40] OF CHAR; (* name of the crashed program (or overlay) *)
    END;

    APMDSysBlock = RECORD
        activProcess, (* address of current process's descriptor   *)
        overlayList,  (* driver & overlay list                     *)
        blockList     (* list of the blocks allocated by 'Storage' *)
                     : ADiskAddress;
        crtBlock     : ARRAY [1..17] OF CARDINAL; (* CrtTableStruc *)

    END;

    APMDTable = RECORD
        blockCount  : CARDINAL;     (* number of mem. blocks used by the prog. *)
                                    (* at least 2 (int. vectors and screen)    *)
        firstBlkPos : ADiskAddress; (* DD FirstEntryPos+2*EntrySize *)
    END;

    APMDTableEntry = RECORD
        filePos        : ADiskAddress; (* offset from the beginning of the *)
                                       (* memory area *)
        beginAddress   : ADiskAddress; (* address of first byte in the block *)
        endAddress     : ADiskAddress; (* address after first byte after the block *)
    END;

        (* First part of the file. *)
    APMD           = RECORD
        Header   : APMDHeader;
        SysBlock : APMDSysBlock;
        Table    : APMDTable;
    END;


CONST
    EntrySize = TSIZE(APMDTableEntry);



PROCEDURE Print( s : ARRAY OF CHAR; DoACR : BOOLEAN );
VAR
    i   : CARDINAL;
    s1  : ARRAY [0..255] OF CHAR;
BEGIN
    i := 0;
    WHILE (i <= HIGH(s)) AND (s[i] <> 0C) DO
        s1[i] := s[i];
        INC(i);
    END;

    IF (DoACR) THEN
        s1[i]   := 15C;
        s1[i+1] := 12C;
        INC(i,2);
    END;

    s1[i]   := "$";
    s1[i+1] := 0C;

    DOSCALL( 09H, ADR(s1) );

END Print;







PROCEDURE GetAndOpenFile( VAR Handle : CARDINAL ) : BOOLEAN;
CONST
    OpenAFile           = 3DH;
    ReadOnlyMode        =  0H;
    ReadOnlyDenyWrite   = 20H;
TYPE
    APSP    = RECORD
        OtherJunkWeDontNeed : ARRAY [1..128] OF CHAR;
        CommandLength       : CHAR;
        CommandLine         : ARRAY [0..126] OF CHAR;
    END;
VAR
    PSP         : POINTER TO APSP;
    Start,
    ErrorCode   : CARDINAL;
BEGIN

    PSP    := OurPSPAddress;
    Handle := 0;

    WITH PSP^ DO

        CommandLine[ORD(CommandLength)] := 0C;
        Start := 0;
        WHILE (CommandLine[Start] = " ") DO
            INC(Start);
        END;

        IF (CommandLine[Start] = 0C) THEN
            Print( "Please enter a PMD file name with extension on the command line.", TRUE );
            RETURN FALSE;
        END;

        DOSCALL( OpenAFile, ADR( CommandLine[Start] ),
                 ReadOnlyMode + ReadOnlyDenyWrite,
                 Handle, ErrorCode );
    END;

    IF (ErrorCode <> 0) THEN
        Print("Error opening the file: '", FALSE );
        Print( PSP^.CommandLine, FALSE );
        Print( "'", TRUE );
        Handle := 0; (* otherwise handle==error code *)
    END;

    RETURN (ErrorCode = 0);

END GetAndOpenFile;





PROCEDURE ReadFileHeader( VAR Handle : CARDINAL;
                          VAR PMD    : APMD     ) : BOOLEAN;
CONST
    ReadRecord  = 3FH;
VAR
    XferedBytes : CARDINAL;
    ErrorCode   : CARDINAL;
BEGIN
    DOSCALL( ReadRecord, Handle, TSIZE(APMD), ADR(PMD),
             XferedBytes, ErrorCode );
    IF (ErrorCode <> 0) OR (XferedBytes <> TSIZE(APMD)) THEN
        Print( "I can't read the PMD's header.", TRUE );
        RETURN FALSE;
    END;

    RETURN TRUE;

END ReadFileHeader;


CONST
    CloseFile = 3EH;

VAR
    FileHandle  : CARDINAL;
    ErrorCode   : CARDINAL;
    PMD         : APMD;

BEGIN

    Print( "PMDPATCH V0.9 28-Jun-91 (RSC)", TRUE );
    FileHandle := 0;

    IF (GetAndOpenFile( FileHandle )) AND
       (ReadFileHeader( FileHandle, PMD )) THEN
        Print( "PMD for ", FALSE );
        Print( PMD.Header.progName, TRUE );
    END;

    IF (FileHandle <> 0) THEN
        DOSCALL( CloseFile, FileHandle, ErrorCode );
    END;

END PMDPatch.

