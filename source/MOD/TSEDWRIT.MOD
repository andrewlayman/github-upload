IMPLEMENTATION MODULE TSEDWrite;

    (*  MODIFICATION HISTORY
         7-Sep-89 CMH   Removed obsolete procedures to open, write and
                        close the matrix size file.
        10-Oct-89 MWP   Moved text literal to phrases file.
        21-Nov-89 CMH   Added code to check the file record response
                        for WriteChar.
     *)

FROM Dialog                 IMPORT
    (* PROC *)                  Error;

FROM FileOpen               IMPORT
    (* PROC *)                  RequestFileOpen;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* PROC *)                  Close, Lookup,Delete,
                                SetOpen, SetWrite,
                                WriteChar;

FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM MsgFile                IMPORT
    (* PROCS *)                 GetMessage;
        
FROM Overlays               IMPORT
     (* VAR *)                  PackageOK;

CONST
    ModuleNumber  =  9600;

VAR

    fNetworkData    : File;

(*--------------------------------------------------------------------------*)
        (*
            OpenTLGSFile

            Open TLGSNET.DAT
         *)

PROCEDURE OpenTLGSFile():BOOLEAN;

VAR
    s    : ARRAY [0..255] OF CHAR;
    new,
    okay : BOOLEAN;

BEGIN

    new:= TRUE;
    Delete("tlgsnet.dat",fNetworkData);
    Lookup(fNetworkData,"tlgsnet.dat",new);

    IF (fNetworkData.res = done) THEN
        SetOpen(fNetworkData);
        SetWrite(fNetworkData);
        okay:= TRUE;
    ELSE
        GetMessage ( ModuleNumber, s );
        (* "network data file open failed" *)
        Error(s);
        okay:= FALSE;
    END;

    RETURN(okay);

END OpenTLGSFile;


(*--------------------------------------------------------------------------*)
        (*
            WriteToTLGSFile

            Write an LString to the active file, adding a
            CR LF sequence.
         *)

PROCEDURE WriteToTLGSFile(string : ARRAY OF CHAR);

CONST

    CR = 15C;
    LF = 12C;
VAR
    i : CARDINAL;

BEGIN

    FOR i:= 1 TO ORD(string[0]) DO
        WriteChar(fNetworkData,string[i]);
        IF (fNetworkData.res <> done) THEN
            PackageOK := FALSE;
        END;
    END; (*for*)
    WriteChar(fNetworkData,CR);
    IF (fNetworkData.res <> done) THEN
        PackageOK := FALSE;
    END;
    WriteChar(fNetworkData,LF);
    IF (fNetworkData.res <> done) THEN
        PackageOK := FALSE;
    END;

END WriteToTLGSFile;


(*--------------------------------------------------------------------------*)
        (*
            CloseTLGSFile

            Open TLGSNET.DAT
         *)

PROCEDURE CloseTLGSFile();

VAR

BEGIN

    Close(fNetworkData);

END CloseTLGSFile;


(*--------------------------------------------------------------------------*)

BEGIN                       (* TSEDWrite *)


END TSEDWrite.
