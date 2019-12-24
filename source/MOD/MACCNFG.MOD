IMPLEMENTATION MODULE MacCnfg;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software


        30-May-91 RSC  Removed globals, put them on the stack.
         4-Jun-91 RSC  Removed spurious EOF marker.

---------------------------------------------------------------------------*)



(*---------------------------------------------------------------

   Read and Write TL/Macro configuration settings to disk.
   The disk file is assumed to be on the default drive and directory,
   and named "MACWHAT.CFG".


   DATA:

      (Hotkeys)
   (Record 1)   StartRecordKey,
   (Record 2)   StopRecordKey,
   (Record 3)   MenuKey
   (Record 4)   ListKey
   (Record 5)   MacInsertKey          : CARDINAL;

      (Playback Style)
   (Record 6)   StepMode         : BOOLEAN;
   (Record 7)   PlayBackSpeed    : APlayBackSpeed;        (store as card)
                  ^------(save: ORD(PlayBackSpeed, value saved to file)
                         (read: VAL(PlayBackSpeed, value read from file)

      (MacroPath)
   (Record 8)   MacroFileMedia : ARRAY [0..56] OF CHAR;   
   (Record 9)   LastMacroSaved  : ARRAY [0..8] OF CHAR;   
   
   -----------------------------------------------------------------*)



(*============================================================================*)
(*----------------------------------------------------------------------------*)
(*============================================================================*)

FROM Dialog       IMPORT Error;

FROM FileSystem   IMPORT File, Lookup, Delete, Close, Response, WriteByte(*,
                         Create, Rename*);

FROM LStrings     IMPORT SetString;

FROM MacSetUp     IMPORT StartRecordKey, StopRecordKey, MenuKey, ListKey,
                         APlayBackSpeed, PlayBackSpeed, StepMode,
                         MacInsertKey;

FROM MacVars      IMPORT MacStoragePreference,
                         MacroFileMedia, LastMacroSaved;

FROM MsgFile      IMPORT GetMessage;

FROM RecordIO     IMPORT ReadRecord, WriteRecord;

FROM Subfiles     IMPORT StartFileInput, StartSubfileInput,
                         StartFileOutput, StartSubfileOutput,
                         EndSubfileOutput, EndFileOutput;

FROM SYSTEM       IMPORT ADR, SIZE;


CONST
    ConfigFile = "MACCNFG.DAT";




PROCEDURE ReadConfig;
VAR
    version,
    type,
    PlayCard     : CARDINAL;
    f            : File;
    S            : ARRAY [0..128] OF CHAR;

BEGIN
    Lookup (f, ConfigFile, FALSE);
    IF f.res <> done THEN
      Close (f);
      RETURN;
    END;

    IF NOT StartFileInput (f) THEN
      GetMessage (26386, S);
      Error (S);
      Close (f);
      Delete (ConfigFile, f);
      RETURN;
    END;
    IF NOT StartSubfileInput (f, 1, version) THEN
      GetMessage (26386, S);
      Error (S);
      Close (f);
      Delete (ConfigFile, f);
      RETURN;
    END;

    (*Read the file configuration data *)

    ReadRecord (f, type, ADR(StartRecordKey), SIZE(StartRecordKey));
    ReadRecord (f, type, ADR(StopRecordKey), SIZE(StopRecordKey));
    ReadRecord (f, type, ADR(MenuKey), SIZE(MenuKey));
    ReadRecord (f, type, ADR(ListKey), SIZE(ListKey));
    ReadRecord (f, type, ADR(MacInsertKey), SIZE(MacInsertKey));
    ReadRecord (f, type, ADR(StepMode), SIZE(StepMode));
    ReadRecord (f, type, ADR(PlayCard), SIZE(PlayCard));
    ReadRecord (f, type, ADR(MacroFileMedia), SIZE(MacroFileMedia));
    ReadRecord (f, type, ADR(LastMacroSaved), SIZE(LastMacroSaved));

    PlayBackSpeed := VAL(APlayBackSpeed, PlayCard);

    Close (f);

END ReadConfig;



PROCEDURE WriteConfig;
VAR
    version,
    type,
    PlayCard     : CARDINAL;
    f            : File;
    S            : ARRAY [0..128] OF CHAR;


  PROCEDURE CreateConfigFile ():BOOLEAN;
  BEGIN
    Delete (ConfigFile, f);
    Lookup (f, ConfigFile, TRUE);
    (*Create (f, "DK;");
    Rename (f, ConfigFile);*)
    IF f.res <> done THEN
      RETURN FALSE;
    END;
    RETURN TRUE;
  END CreateConfigFile;

  PROCEDURE InitConfigFile ():BOOLEAN;
  BEGIN
    StartFileOutput (f, 5);
    StartSubfileOutput (f, 1, 1);
    RETURN TRUE;
  END InitConfigFile;


BEGIN
    IF NOT CreateConfigFile() THEN Close (f); RETURN; END;
    IF NOT InitConfigFile() THEN Close (f); RETURN; END;

    PlayCard := ORD(PlayBackSpeed);

    WriteRecord (f, 1, ADR(StartRecordKey), SIZE(StartRecordKey));
    WriteRecord (f, 2, ADR(StopRecordKey), SIZE(StopRecordKey));
    WriteRecord (f, 3, ADR(MenuKey), SIZE(MenuKey));
    WriteRecord (f, 4, ADR(ListKey), SIZE(ListKey));
    WriteRecord (f, 5, ADR(MacInsertKey), SIZE(MacInsertKey));
    WriteRecord (f, 6, ADR(StepMode), SIZE(StepMode));
    WriteRecord (f, 7, ADR(PlayCard), SIZE(PlayCard));
    WriteRecord (f, 8, ADR(MacroFileMedia), SIZE(MacroFileMedia));
    WriteRecord (f, 9, ADR(LastMacroSaved), SIZE(LastMacroSaved));

    EndSubfileOutput (f, 1);
    EndFileOutput (f);
(*    WriteByte (f, 32C);*)     (* 4-Jun-91 RSC removed. *)
    Close (f);

END WriteConfig;

END MacCnfg.
