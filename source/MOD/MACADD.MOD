(*<BIND IMPLEMENTATION BIND>*) MODULE MacAdd;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)


(*
Modifications:  5/24/88  :  Play back inserted items when recording.
                6/13/88  :  Added EditChangeMade.
                6/25/88  :  Removed hotkey from Secondary Macro insertion.
     10-Aug-89  KKC - Add copyright message.
     01-Oct-89  WKH - Fix coordination problems btwn Cybersoft and Symantec.
     13-Nov-89  RSC - Import from Space rather than Storage.
     22-Nov-89  RSC - Changed size of secondary macro name from 40 to 42.
     30-Nov-89  MWP - Placed hard coded literals into the phrases file.
     12-Dec-89  RSC - Added MODAL param to menus.
     17-Jan-90  RSC - Made MacSave load into the reserved layer.
     19-Jan-90  WKH - Import GetMessageWord from MsgFileAux instead of
                      RptCommon.
     20-Mar-90  RSC - Move a DISPOSE down a line to let the record be
                      disposed of under all conditions.

     20-Oct-90  RSC - Added BIND toggles.
     12-Apr-91  RSC - Changed params to MenuWithPrompts.
     12-Aug-91  PFG - The GetMessageWord calls for Input Pause were using the
                      wrong phrase number.
*)

FROM Codes          IMPORT
                            EmptyCodeSet, ACode;
                            
FROM Boxes          IMPORT
                            ABoxType, ABoxAttribute;

FROM Dialog         IMPORT  ContinuationBox, ADialogOption;

FROM Kbio           IMPORT  maxrow;

FROM Keys           IMPORT
                            CancelKey;

FROM Layout         IMPORT
                            MenuStart, MenuEnd;

FROM Lights         IMPORT
                            RemoveLight, ALight;

FROM LStrings       IMPORT
                            SetString, Fill, TrimRear, ConcatS;

FROM MacBuffs       IMPORT
                            PutStrInBuffer, PutCodeInBuffer,
                            PutMenuInBuffer, PutMessageInBuffer,
                            PushBuffer, PlayBuffer, MacBuffer, PopBuffer;

FROM MacCodes       IMPORT
                            BeginCode, EndCode,
                            NameCode,
                            MessageCode,
                            MenuCode,
                            PauseCode,
                            ChainCode;

FROM MacDo          IMPORT
                            DoName, DoMacroByName;

FROM MacHeader      IMPORT
                            PopMacHeaderStack;

FROM MacLights      IMPORT
                            RecordLight, PlaybackLight, DoOurLight;

FROM MacNodes       IMPORT
                            MacroTree, MacroNode;

FROM MacRcord       IMPORT
                            StopRecording;

FROM MacrosRc       IMPORT
                            FindMacroByName, CreateMacro;

FROM MacroSelect    IMPORT
                            SelectMacroName;

FROM MacState       IMPORT
                            PushState, AState, PopState;

FROM MacStore       IMPORT
                            StoreMacro;

FROM MacStrings     IMPORT
                            MacMessagePtr, MacMenuPtr;

FROM MacTalk        IMPORT
                            MacDeath;

FROM MacVars        IMPORT
                            LinkedMacro, Editing, FormAccepted,
                            Command, MacrosModified, EditMacroChange;

FROM Menus          IMPORT
    (* TYPE *)              APromptType,
                            MenuWithPrompts;

FROM MsgFile        IMPORT
                            GetMessage;

FROM Overlays       IMPORT
                            CallOverlay, 
                            CallOverlayWithContext;

FROM MsgFileAux     IMPORT
                            GetMessageWord;

FROM Rugs           IMPORT
                            ARug, GetRug, PutRug;

FROM Space          IMPORT
                            Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
                            SIZE;

FROM Text           IMPORT
    (* TYPE *)          AText;


CONST
     ModuleNumber = 9700;





(*------------------------------------------------------------------------

This is the Add Menu, that allows users to add macros, messages and menus
to their macros.  It can be used when recording or editing a macro.

-------------------------------------------------------------------------*)

PROCEDURE DoMacAdd();

TYPE MacRecordPtr = POINTER TO RECORD
                                 name      : ARRAY [0..42] OF CHAR; (* 22-Nov-89 RSC was 40. *)
                                 hotkey    : CARDINAL;
                                 hotkeystr : ARRAY [0..10] OF CHAR;
                               END;

VAR
     rug       : ARug;
     oldcount,
     select    : CARDINAL;
     choice    : ACode;
     title     : ARRAY [0..30] OF CHAR;
     prefix    : ARRAY [0..15] OF CHAR;
     menu      : ARRAY [0..79] OF CHAR;
     MacName   : ARRAY [0..40] OF CHAR;
     S         : ARRAY [0..255] OF CHAR;
     MacRecord : MacRecordPtr;
     Copyright : ARRAY[0..50] OF CHAR;


BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  IF MacBuffer <> NIL THEN
    oldcount := MacBuffer^.count;
  ELSE
    oldcount := 0;
  END;
  select := 1;
  IF NOT GetRug (0,MenuStart,79,MenuEnd,rug) THEN RETURN; END;
  GetMessage (26359, prefix);
  GetMessage (26360, menu);
  LOOP
    choice :=
              MenuWithPrompts (prefix,menu,1,MenuStart,76,MenuEnd,
                               ABoxType{DoubleBox,ShadowBox},EmptyCodeSet,
                               PromptFromPhrases,26351, AText(NIL),
                               TRUE,        (* 12-Dec-89 RSC MODAL *)
                               select);
    IF choice = CancelKey THEN EXIT; END;
    CASE select OF
      1 :
            (* Macro *)
            Fill (MacName, " ", 0);
            GetMessage (26361, title);
            IF SelectMacroName (5,5,47,maxrow - 6, title, MacName) THEN
              IF NOT Editing THEN
                DoMacroByName (MacName);           (* plays it *)
                
                TrimRear (MacName);           (* inserts in recorded macro *)
                IF NOT PutCodeInBuffer (NameCode) THEN EXIT END;
                IF NOT PutStrInBuffer (MacName) THEN
                  DEC (MacBuffer^.count);
                  EXIT;
                END;
                IF NOT PutCodeInBuffer (NameCode) THEN
                  MacBuffer^.count := oldcount;
                END;
              ELSE
                MacroNode := FindMacroByName (MacName);
                IF MacroNode = NIL THEN EXIT; END;
                EditMacroChange := TRUE;
                DoName (MacName);                  (* plays it *)
              END;
            END;
          EXIT;
    | 2 :
          (* Secondary Macro *)
          IF Available (SIZE(MacRecord)) THEN
            NEW (MacRecord);
            SetString (S, "|MACSEC");
            PushState (Neutral);                    (* MacSec Pops State *)
            IF (CallOverlayWithContext (S, MacRecord) AND FormAccepted)
                        THEN
              IF Editing THEN

                IF NOT PushBuffer() THEN
                  DISPOSE (MacRecord);
                  EXIT;
                 END;

                GetMessageWord ( ModuleNumber + 22, 0, S );       (* 30-Nov-89 MWP *)
(*                 
                SetString (S, "{beginput}");
*)

                IF NOT PutStrInBuffer (S) THEN
                  PopBuffer;
                  DISPOSE (MacRecord);
                  EXIT;
                END;

                IF NOT PutStrInBuffer (MacRecord^.name) THEN
                  PopBuffer;
                  DISPOSE (MacRecord);
                  EXIT;
                END;

                GetMessageWord ( ModuleNumber + 22, 1, S );            (* 30-Nov-89 MWP *)
(*
                SetString (S, "{endinput}");
*)
 
                IF NOT PutStrInBuffer (S) THEN
                  PopBuffer;
                  DISPOSE (MacRecord);
                  EXIT;
                END;

                PlayBuffer;
                EditMacroChange := TRUE;

              ELSE                                (* must be recording *)
              
                IF NOT PushBuffer() THEN  
                  DISPOSE (MacRecord);    
                  EXIT;
                END;

                  (* play it now  *)
                IF NOT PutCodeInBuffer (BeginCode) THEN
                  DISPOSE (MacRecord);
                  PopBuffer;
                  EXIT;
                END;

                IF NOT PutStrInBuffer (MacRecord^.name) THEN
                  DISPOSE (MacRecord);
                  PopBuffer;
                  EXIT;
                END;

                IF NOT PutCodeInBuffer (EndCode) THEN      (* pause *)
                  DISPOSE (MacRecord);
                  PopBuffer;
                  EXIT;
                END;

                PlayBuffer;

              END;
            (* 20-Mar-90 RSC Was here... *)    
            END;
            DISPOSE (MacRecord);    (* 20-Mar-90 RSC Now is here. *)
          END;
          EXIT;
    | 3 :
          (* Input Pause *)
          IF Editing THEN
          
            IF NOT PushBuffer() THEN EXIT; END;
            GetMessageWord ( ModuleNumber+22, 0, S );                (* 30-Nov-89 MWP *)
(*
            SetString (S, "{beginput}");
*)
            IF PutStrInBuffer (S) THEN END;
            GetMessageWord ( ModuleNumber+22, 1, S );                (* 30-Nov-89 MWP *)
(*
            SetString (S, "{endinput}");
*)
            IF PutStrInBuffer (S) THEN END;
            PlayBuffer;
            EditMacroChange := TRUE;
            
          ELSE  (* must be recording *)
          
             (* put in recorded macro *)
            IF NOT PutCodeInBuffer (BeginCode) THEN EXIT; END;
            IF NOT PutCodeInBuffer (EndCode) THEN
              DEC (MacBuffer^.count);
              EXIT;
            END;
            
            IF NOT PushBuffer() THEN EXIT; END;  (* play it now *)
            IF PutCodeInBuffer (BeginCode) THEN END;
            IF PutCodeInBuffer (EndCode) THEN END;
            PlayBuffer;
              
           END;
          EXIT;
    | 4 :
          (* Choices *)
          SetString (S, "|MACMENUF");
          IF CallOverlay (S) THEN
            IF ((MacMenuPtr <> NIL) AND FormAccepted) THEN
              IF Editing THEN
              
                IF NOT PushBuffer() THEN EXIT; END;
                IF PutStrInBuffer (Command[2]) THEN END;
                IF PutMenuInBuffer() THEN END;
                IF PutStrInBuffer (Command[3]) THEN END;
                PlayBuffer;
                EditMacroChange := TRUE;
                
              ELSE    (* must be recording *)
              
                (*  Put in recorded macro *)
                IF NOT PutCodeInBuffer (MenuCode) THEN EXIT; END;
                IF NOT PutMenuInBuffer() THEN
                  MacBuffer^.count := oldcount;
                  EXIT;
                END;
                IF NOT PutCodeInBuffer (MenuCode) THEN
                  MacBuffer^.count := oldcount;
                  EXIT; 
                END;
                
                (* Play it now *)
                IF NOT PushBuffer() THEN EXIT; END;  (* play it now *)
                IF PutCodeInBuffer (MenuCode) THEN END;
                IF PutMenuInBuffer() THEN END;
                IF PutCodeInBuffer (MenuCode) THEN END;
                PlayBuffer;
            
              END;
              DISPOSE (MacMenuPtr);
              MacMenuPtr := NIL;
            END;
          END;
          EXIT;

    | 5 :
          (* Dialog *)
          SetString (S, "|MACMSGFO");
          IF CallOverlay (S) THEN
            IF ((MacMessagePtr <> NIL) AND FormAccepted) THEN
              IF Editing THEN
              
                IF NOT PushBuffer() THEN EXIT; END;
                IF PutStrInBuffer (Command[0]) THEN END;
                IF PutMessageInBuffer() THEN END;
                IF PutStrInBuffer (Command[1]) THEN END;
                PlayBuffer;
                EditMacroChange := TRUE;
                
              ELSE  (* must be recording *)
              
                (* put in recorded macro *)
                IF NOT PutCodeInBuffer (MessageCode) THEN EXIT; END;
                IF NOT PutMessageInBuffer() THEN
                  MacBuffer^.count := oldcount;
                  EXIT;
                END;
                IF NOT PutCodeInBuffer (MessageCode) THEN
                  MacBuffer^.count := oldcount;
                  EXIT; 
                END;
 
                (* play it now *)
                IF NOT PushBuffer() THEN EXIT; END;
                IF PutCodeInBuffer (MessageCode) THEN END;
                IF PutMessageInBuffer() THEN END;
                IF PutCodeInBuffer (MessageCode) THEN END;
                PlayBuffer;
                 
              END;
              DISPOSE (MacMessagePtr);
              MacMessagePtr := NIL;
            END;
          END;
          EXIT;
    | 6 :
          (* Pause *)
          IF Editing THEN
            IF NOT PushBuffer() THEN EXIT; END;
            IF PutStrInBuffer (Command[4]) THEN END;
            PlayBuffer;
            EditMacroChange := TRUE;
            
          ELSE  (* recording *)
          
            (* put in recorded macro *)
            IF NOT PutCodeInBuffer (PauseCode) THEN EXIT; END;
           
            (* play it now *)
            IF NOT PushBuffer() THEN EXIT; END;
            IF PutCodeInBuffer (PauseCode) THEN END;
            PlayBuffer;
              
          END;
          EXIT;
    | 7 :
          (* Link *)
          SetString (S, "|MACLINK");
          IF NOT CallOverlay(S) THEN EXIT; END;
          IF FormAccepted THEN
            IF Editing THEN
            
              IF NOT PushBuffer() THEN EXIT; END;
              IF PutStrInBuffer (Command[7]) THEN END;
              IF PutStrInBuffer (LinkedMacro) THEN END;
              IF PutStrInBuffer (Command[8]) THEN END;
              PlayBuffer;
              EditMacroChange := TRUE;
              
            ELSE  (* must be recording *)
            
              (* put in recorded macro *)
              IF NOT PutCodeInBuffer (ChainCode) THEN EXIT; END;
              IF NOT PutStrInBuffer (LinkedMacro) THEN
                MacBuffer^.count := oldcount;
                EXIT; 
              END;
              IF NOT PutCodeInBuffer (ChainCode) THEN
                MacBuffer^.count := oldcount;
                EXIT; 
              END;
               
              (* play it now *)
              (* need to: 
                           * stop recording and store macro,
                           * prompt user to save macros
                           * push buffer, stuff it, play buffer.
                           * put up a Playback light  *)

              StopRecording;
              GetMessage (26362, S);
              DoOurLight (PlaybackLight, S);
              
              GetMessage (26363, S);
              GetMessage (26364, title);
              IF ContinuationBox (S, title, NoHelp) THEN
                SetString (S, "|MACSAVE");  (* 17-Jan-90 RSC *)
                IF CallOverlay (S) THEN END;
                IF FormAccepted THEN MacrosModified := FALSE; END;
              ELSE
                MacrosModified := FALSE;
              END;
              RemoveLight (PlaybackLight);

              IF NOT PushBuffer() THEN EXIT; END;  (* plays it *)
              IF PutCodeInBuffer (ChainCode) THEN END;
              IF PutStrInBuffer (LinkedMacro) THEN END;
              IF PutCodeInBuffer (ChainCode) THEN END;
              PlayBuffer;
              
            END;
          END;
          EXIT;
    | 8 :
          (* Quit *)
          EXIT;
    ELSE ;
    END;
  END;

  PutRug (0,0,79,2, rug);
END DoMacAdd;



(*<BIND
PROCEDURE MacAddBind();
BIND>*) 

BEGIN

    DoMacAdd();

(*<BIND
END MacAddBind;
BIND>*) 


END MacAdd.
