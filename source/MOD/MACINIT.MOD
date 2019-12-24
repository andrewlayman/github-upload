(*<BIND IMPLEMENTATION BIND>*) MODULE MacInit;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)
(*
Modifications:  
     10-Aug-89  KKC - Add copyright message.
     01-Oct-89  WKH - ReSynch code btwn Cybersoft & Symantec.

     10-Nov-89  RSC - Make the UTILITIES,Macros menu choice dynamic.  That
                      is, it only appears when we are loaded.

      3-Jan-90  RSC - Moved init code from MACSETKE and MACAUTO to here
                      so that the init of TimeLine takes less time.
      7-Mar-90  RSC - Changed init of "menuOn", so that there is only one
                      copy of the boolean, not several pointers to it.
      5-Oct-90  RSC - Removed adding of the menu item.

     20-Oct-90  RSC - Added BIND toggles.
                      Made minor tweaks to put things on the stack
                      rather than in globals.

*)

FROM Dialog        IMPORT Error;

FROM Directory     IMPORT ExtractFileNameParts;

IMPORT Dispatcher;  (* 10-Nov-89 RSC *)

FROM FlexStor      IMPORT CreateExtObject, AnExtHandle, SetExtData;

FROM InitMenu      IMPORT
    (* PROCS *)           AddMenuItem;  (* 10-Nov-89 RSC *)

FROM LStrings      IMPORT SetString, Fill, Copy,
                          ConcatLS, Procustes, TrimRear,
                          ConcatS, SubStr, Remove;


FROM MacLoadTools  IMPORT LoadMacros;

FROM MacLights     IMPORT PlaybackLight, DoOurLight;

FROM MacTalk       IMPORT MacDeath;

FROM MacrosRc      IMPORT CreateMacro, MacroDefaults,
                          FindMacroByName;


FROM MacKeys       IMPORT
    (* PROC *)            SetUpExKeys, SetUpNormKeys, SetUpCommands,
                          SetUpEditCodeSet, SetUpEditNavSet;

FROM MacNodes      IMPORT EditTree, MacroTree, EditMacro, OurMacro,
                          AMacroRecordPointer, EditRecordPointer;

FROM MacStack      IMPORT MacStack, PushMacro;

FROM MacState      IMPORT PushState, AState;

FROM MacVars       IMPORT MacStoragePreference, OurCodeRecord,
                          OurEditRecord, OurRecordingRecord,
                          RecordingSecondaryMacro, InAForm,
                          Interlock, MacrosModified, EditCancel,
                          MacroFileMedia, MacroFileName, FileSpec,
                          LightsOnRecord,
                          
                          MenuOn    (* 8-Mar-90 RSC *);

FROM MsgFile       IMPORT GetMessage;

FROM ParmLine      IMPORT GetOption;

FROM RunMenu       IMPORT
    (* Type *)            AnItem;   (* 10-Nov-89 RSC *)

FROM Space         IMPORT Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM        IMPORT SIZE, ADDRESS;

FROM TreeObjects   IMPORT ATreeNode, CreateTree, ValidateTree, CreateTreeNode;

FROM MacCnfg       IMPORT ReadConfig;

FROM Words         IMPORT
    (* PROC *)            ParseBal; (* 10-Nov-89 RSC *)



PROCEDURE DoMacInit;
VAR
    MacroNode           : ATreeNode;
    argument            : ARRAY [0..79] OF CHAR;
    MacName             : ARRAY [0..79] OF CHAR;
    S                   : ARRAY [0..200] OF CHAR;
    option              : ARRAY [0..20] OF CHAR;
    found               : BOOLEAN;



(*-------------------------------------------------------------------------

Parses the first argument in the Time Line command line to get a
Macro Filename (with path), and a Macro Name.

The path is returned as argument1.

Both VARs are returned as LStrings.

---------------------------------------------------------------------------*)

PROCEDURE ParseArgument (VAR argument,
                             macroname  : ARRAY OF CHAR):BOOLEAN;
VAR
    i         : CARDINAL;
    specifier : BOOLEAN;



BEGIN

  specifier := TRUE;
  
  TrimRear (argument);
  IF ORD (argument[0]) = 0 THEN
    RETURN FALSE;
  END;    (* no argument *)

  (* sets position of i at last backslash *)
  i := ORD(argument[0]);  (* begin at end *)
  LOOP (* search for backslash *)
    IF i = 0 THEN
      GetMessage (26370, S);
      Error (S);
      RETURN FALSE;
    END;
    IF argument[i] = "\" THEN EXIT; END;
    DEC (i);
  END;

  (* extract macro name *)
  SubStr (argument, macroname, i+1, (ORD (argument[0]) +i-1));
  
  (* remove macro name and backslash *)
  Remove (argument, i, ORD (macroname[0])+1);

  (* set macro name to proper length *)
  Procustes (macroname, 40);


  (* searches for period *)
  i := ORD(argument[0]);  (* begin at end *)
  LOOP (* search for backslash *)
    IF i = 0 THEN
      specifier := FALSE;
    END;
    IF argument[i] = "." THEN EXIT; END;
    DEC (i);
  END;

  IF NOT specifier THEN  
    ConcatS (argument, FileSpec);
  END;
  
  RETURN TRUE;
END ParseArgument;




PROCEDURE AutoLoad;

VAR
    device : ARRAY [0..3] OF CHAR;
    path   : ARRAY [0..56] OF CHAR;
    ext    : ARRAY [0..5] OF CHAR;
    Copyright   : ARRAY[0..50] OF CHAR;
    
BEGIN
      Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
      IF LoadMacros (argument, MacroTree, TRUE) THEN
        ExtractFileNameParts (argument, device, path, MacroFileName, ext);
        Copy (device, MacroFileMedia);
        ConcatLS (MacroFileMedia, path);
        MacroNode := FindMacroByName (MacName);
        IF MacroNode = NIL THEN
          GetMessage (26371, S);
          ConcatLS (S, MacName);
          Error (S);
        ELSE
          PushMacro (MacroNode);
          PushState (Playback);
          IF NOT LightsOnRecord.PlayLight THEN
            GetMessage (26376, S);
            DoOurLight (PlaybackLight, S);
            LightsOnRecord.PlayLight := TRUE;
          END;
        END;
      ELSE
        GetMessage (26373, S);
        ConcatLS (S, argument);
        Error (S);
      END;
END AutoLoad;




CONST MacroTag = 7653;

VAR
     handle             : AnExtHandle;
     i                  : CARDINAL;
     MenuString         : ARRAY [0..255] OF CHAR;
     Item               : AnItem;
     Copyright          : ARRAY [0..50] OF CHAR;



BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    (* 5-Oct-90 RSC removed. *)
(* **********************

    GetMessage( 26395, MenuString );    (* (UTILITIES)(Macros)(>MACMENUD)(Macros Menu) *)

    i := 1;
    WITH Item DO
        ParseBal( MenuString, i, Class        ); (* "UTILITIES" *)
        ParseBal( MenuString, i, ItemName     ); (* "Macros" *)
        ParseBal( MenuString, i, ActionString ); (* ">MACMENUD" *)
        ParseBal( MenuString, i, Description  ); (* "Macros Menu" *)
        Key          := 0;
        DispatchProc := Dispatcher.Dispatch;
    END;
    AddMenuItem( Item, 1 );
**************************** *)



    ReadConfig;

    IF NOT (CreateTree (MacroTree)) THEN
        MacDeath;
    END;
    ValidateTree (MacroTree);

    IF NOT (CreateTree (EditTree)) THEN
        MacDeath;
    END;
    ValidateTree (EditTree);

    IF NOT (CreateMacro (EditMacro)) THEN MacDeath; END;
    EditTree^.Methods^.AddFirst (EditTree, EditMacro);

    (* initialize the edit macro *)

    EditMacro := EditTree^.Methods^.GetFirst (EditTree);
    EditRecordPointer := EditMacro^.Methods^.LockFlexStorDataObject (EditMacro);
    GetMessage (26393, EditRecordPointer^.name);
    GetMessage (26394, EditRecordPointer^.description);
    EditRecordPointer^.cardlen := 0;
    EditRecordPointer^.tag     := MacroTag;
    EditMacro^.Methods^.UnlockFlexStorDataObject (EditMacro);

    OurMacro := NIL;

    NEW (OurCodeRecord);
    OurCodeRecord^.Pause := FALSE;
    OurCodeRecord^.InputPause := FALSE;
    OurCodeRecord^.Cancel := FALSE;
    OurCodeRecord^.code := 0;
    OurCodeRecord^.exit := TRUE;

    NEW (OurEditRecord);
    NEW (OurEditRecord^.macNamePtr);

    (* 7-Mar-90 RSC Removed init of "menuOn".
    *)
    NEW (OurRecordingRecord);
    OurRecordingRecord^.exit := FALSE;
    OurRecordingRecord^.break := FALSE;

    Interlock      := 0;
    MacrosModified := FALSE;
    InAForm        := FALSE;
    EditCancel     := FALSE;
    RecordingSecondaryMacro := FALSE;

    (* 3-Jan-90 RSC Moved here from MACSETKE to shorten startup time. *)

    SetUpExKeys;
    SetUpNormKeys;
    SetUpEditCodeSet;
    SetUpCommands;
    SetUpEditNavSet;

    (* 3-Jan-90 RSC Moved here from MACAUTO to shorten startup time. *)

    MacroNode := NIL;
    GetMessage (26374, option);
    GetOption (option, found, argument);
    IF found THEN
        IF ParseArgument (argument, MacName) THEN
            AutoLoad;
        ELSE
            GetMessage (26375, S);
            Error (S);
        END;
    END;

END DoMacInit;



(*<BIND
PROCEDURE MacInitBind();
BIND>*)

BEGIN

    DoMacInit();

(*<BIND
END MacInitBind;
BIND>*) 


END MacInit.
