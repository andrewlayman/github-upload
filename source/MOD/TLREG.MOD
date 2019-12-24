    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

(*<OS2
IMPLEMENTATION MODULE TLReg;
OS2>*)
(*<DOS*)
MODULE TLReg;
(*DOS>*)

    (*  TLReg - Validate user access to Time Line


        MODIFICATION HISTORY:
        
        25-Jun-89 WKH   Initial Version
        06-Aug-89 WKH   Initial OS/2 edits.
        09-Aug-89 KKC   Add copyright message.
        10-Sep-90 WKH   Change network registration system to use simultaneous
                        user counting instead of registration by specific
                        user name.
    *)

FROM Dialog             IMPORT
    (* PROC *)              Error;

FROM LStrings           IMPORT
    (* PROC *)              SetLengthOf, SetString, CtoS, ConcatLS, ConcatS;

FROM MsgFile            IMPORT
    (* PROC *)              ConcatMessage;

FROM Paranoia           IMPORT
    (* TYPE *)              AProgramState,
    (* VAR  *)              InitializationOK, ProgramState;

FROM Registry           IMPORT
    (* CONST *)             QCapacity,      QProductPermission, QProductType,
                            TLRetail,       TLNotForResale,     TLEducational,
                            TLTrial,        TLAlpha,            TLBeta,
                            TLProgrammer,
    (* TYPE *)              ARegistryDataRecord,
    (* VAR  *)              UserName,
    (* PROC *)              GetRegistryInfo;


(*<NAMED
FROM RegForm            IMPORT  
                            InitRegistryForm;
NAMED>*)


(*<SIMULTANEOUS*)
FROM RegSimultaneous    IMPORT
    (* PROC *)              InitRegistrySimultaneous;
(*SIMULTANEOUS>*)

FROM RegSupport         IMPORT
    (* PROC *)              InitRegistrySupport;


CONST
    ModuleNumber         = 7600;
    TLStartModuleNumber  = 12300; (* For GetMessage. TLStart's ModuleNumber*)
    ProductCode          = "104"; (* Time Line Version 4.0.  RSC/WKH 20-Jun-89 *)
    TimeLinesName        = "TIMELINE";

VAR
    s                       : ARRAY[0..21] OF CHAR;
    DataRecord              : ARegistryDataRecord;


PROCEDURE WarnOfLimitations();

VAR
    RegistryDataRecord  : ARegistryDataRecord;
    s1,
    ProductName         : ARRAY [0..19]  OF CHAR;
    s                   : ARRAY [0..255] OF CHAR;
    Copyright           : ARRAY[0..50] OF CHAR;

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    SetLengthOf( s, 0 );
    SetString( ProductName, TimeLinesName );

    IF (GetRegistryInfo( UserName,
                         ProductName,
                         QProductType,
                         RegistryDataRecord )) THEN

        CASE RegistryDataRecord.CardinalValue OF
            TLRetail        :
        |   TLNotForResale  :
                ConcatMessage( s, TLStartModuleNumber + 61 ); (* "Promotional copy.  Not for resale." *)

        |   TLEducational   :
                ConcatMessage( s, TLStartModuleNumber + 63 ); (* "Educational Edition.  Not for resale." *)

        |   TLTrial         :
                ConcatMessage( s, TLStartModuleNumber + 65 ); (* "Trial Size.  Not for resale." *)

        |   TLAlpha         :
                ConcatMessage( s, TLStartModuleNumber + 66 ); (* "ALPHA VERSION.  Not for resale." *)

        |   TLBeta          :
                ConcatMessage( s, TLStartModuleNumber + 60 ); (* "Beta Edition." *)

        |   TLProgrammer    :
                ConcatMessage( s, TLStartModuleNumber + 67 ); (* "PROGRAMMER VERSION.  Not for resale." *)

        ELSE
        END;
    END;

    IF (GetRegistryInfo( UserName,
                         ProductName,
                         QCapacity,
                         RegistryDataRecord )) AND
       (RegistryDataRecord.CardinalValue > 0)  THEN

        IF (s[0] <> 0C) THEN
            ConcatS( s, "ü" );
        END;

        ConcatMessage( s, TLStartModuleNumber + 62 ); (* "This version of Time Line has a maximum task limit of ~" *)
        CtoS( RegistryDataRecord.CardinalValue, s1 );
        ConcatLS( s, s1 );
        ConcatS( s, "." );   (* as in "task limit is 10." *)
    END;

    IF (s[0] <> 0C) THEN
        Error(s);
    END;

END WarnOfLimitations;


(*<OS2
PROCEDURE TLRegBind();
OS2>*)

  (* MAIN OF TLReg *)

BEGIN

    IF (InitializationOK) THEN

        InitRegistrySupport();

(*<NAMED
        InitRegistryForm();
NAMED>*)

(*<SIMULTANEOUS*)
        InitRegistrySimultaneous();   (* 10-Sep-90 WKH *)
(*SIMULTANEOUS>*)

        SetString(s, TimeLinesName);
        SetString( DataRecord.StringValue, ProductCode );
        IF (NOT GetRegistryInfo(UserName, s, QProductPermission, DataRecord)) THEN 
            InitializationOK := FALSE;
        ELSE
            WarnOfLimitations();    (* 20-Jun-89 RSC *)
            ProgramState := TLMainStarting;
        END;  (* 08-Jun-89 WKH *)

    END;

(*<OS2
END TLRegBind;
OS2>*)

END TLReg.

