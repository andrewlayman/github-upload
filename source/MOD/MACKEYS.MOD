IMPLEMENTATION MODULE MacKeys;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software

     13-Nov-89  RSC - Import from Space rather than Storage.
     28-Nov-89  RSC - Reallow alts R, P, V, and C.
     30-Nov-89  MWP - Removed text literals.
      6-Dec-89  RSC - The saving of the literals into FlexStor for
                      "NormKeys" was being done twice by accident,
                      the second time causing the item to be uninitialized.
      3-Jan-90  MWP - Allow mouse events to be recognized by macros.  
      8-Jan-90  RSC - Expand the range of extended keys to allow for mice.
     19-Jan-90  WKH - Import GetMessageWord from MsgFileAux instead of
                      RptCommon.
     18-Jul-91  AJL - Added F6 to the EditCodeSet now that F6 is a key
                      recognized by the editor.
---------------------------------------------------------------------------*)

(* Modifications:
   9/19/89 LVK : Removed alt-c and alt-v from available keys.
*)


FROM FlexStor  IMPORT CreateExtObject, SaveHeapCopy;

FROM MacVars IMPORT XKey, NormKey, Command,       (* TYPE *)
                    KeyOffset,                    (* TYPE *)
                    MacStoragePreference,
                    ExtendedCharSet,              (* VAR  *)
                    EditNavSet,
                    SpecialCharSet, EditCodeSet;  (* VAR  *)

FROM Codes   IMPORT SetCodeBits, MaxCode;

FROM LStrings IMPORT SetString, SetLengthOf, StoC, CtoS, ConcatS, ConcatLS;

FROM MsgFileAux         IMPORT
                            GetMessageWord;

FROM Space    IMPORT ALLOCATE;

FROM SYSTEM   IMPORT SIZE;


CONST
    ModuleNumber = 9700;

TYPE
     name = ARRAY [0..10] OF CHAR;
(*
VAR
    XKey    : ARRAY [0..182] OF name;
    NormKey : ARRAY [0..31] OF name;
    Command : ARRAY [0..10] OF name;

    see DEFINITION MODULE
*)



   (*
      The decimal value of the extended character is 256 + decimal (aux. byte).
      The decimal value of the character is calculated.
      The decimal is ([index]+271); the character is Key[decimal-271].
      These characters begin with Reverse-Tab; aux. byte = 15; (256 + 15 = 271).
        - For all reasonable purposes, this is first extended character.
      There are 118 - 23 = 95 of these extended keys.
      The missing two keys from Norton's list are Ctrl-PrtSc and Would-be-null.

   *)

PROCEDURE SetUpExKeys;
VAR
    ourXKey             : POINTER TO ARRAY [0..182] OF name;
    dummy,
    EntriesToRead,
    RowsToRead,
    i,j,k,Element       : CARDINAL;
    s                   : ARRAY[0..10] OF CHAR;

BEGIN

    NEW (ourXKey);

    (* 8-Jan-90 RSC Made these 182 rather than 117. *)
    FOR i := 0 TO 182 DO
      SetLengthOf (ourXKey^[i], 0);
    END;


    SetCodeBits (ExtendedCharSet, 0, MaxCode, FALSE);
    SetCodeBits (ExtendedCharSet, 271, 281, TRUE);
    SetCodeBits (ExtendedCharSet, 286, 294, TRUE);
    SetCodeBits (ExtendedCharSet, 300, 306, TRUE);
    SetCodeBits (ExtendedCharSet, 315, 324, TRUE);
    SetCodeBits (ExtendedCharSet, 327, 329, TRUE);
    SetCodeBits (ExtendedCharSet, 331, 331, TRUE);
    SetCodeBits (ExtendedCharSet, 333, 333, TRUE);
    SetCodeBits (ExtendedCharSet, 335, 369, TRUE);
    SetCodeBits (ExtendedCharSet, 371, 388, TRUE);

    SetCodeBits (ExtendedCharSet, 450, 453, TRUE);                  (* 3-Jan-89 MWP *)

    Element := 0;

    (* How many phrases are there to be read? *)
    GetMessageWord ( ModuleNumber, 0, s );
    k := 1;
    RowsToRead := StoC ( s, k );

    j := 1;


    REPEAT
       (* How many entries are there in this phrase? *)
       GetMessageWord ( ModuleNumber + j, 0, s );
       k := 1;
       EntriesToRead := StoC ( s, k );

       (* Read each entry. NOTE! There is no checking done to 
          ensure the phrase we read will fit in the array element.
          Also, we do not check that we have not passed the limit
          of the array ourXKey.
       *)
       FOR i := 1 TO EntriesToRead DO
          GetMessageWord ( ModuleNumber + j, i, ourXKey^[Element] );
          INC(Element);
       END;

       INC(j);
    UNTIL ( j > RowsToRead );

    (* 8-Jan-90 RSC Special mouse key reading.
    *)
    Element := 179;
    FOR i := 0 TO 3 DO
        GetMessageWord ( ModuleNumber + 30, i, ourXKey^[Element] );
        INC(Element);
    END;


    IF CreateExtObject (XKey, MacStoragePreference) THEN
      IF SaveHeapCopy (XKey, ourXKey, SIZE(ourXKey^)) THEN
        dummy := 1;
      END;
    END;


(***
  SetCodeBits (ExtendedCharSet, 0, MaxCode, FALSE);
  SetCodeBits (ExtendedCharSet, 271, 281, TRUE);
  SetString (ourXKey^[0], '{revtab}');  (*271*)
  SetString (ourXKey^[1], '{altq}');  (*272*)
  SetString (ourXKey^[2], '{altw}');  (*273*)
  SetString (ourXKey^[3], '{alte}');  (*274*)
  SetString (ourXKey^[4], '{altr}');  (*275*)   (* 28-Nov-89 RSC enabled *)
  SetString (ourXKey^[5], '{altt}');  (*276*)
  SetString (ourXKey^[6], '{alty}');  (*277*)
  SetString (ourXKey^[7], '{altu}');  (*278*)
  SetString (ourXKey^[8], '{alti}');  (*279*)
  SetString (ourXKey^[9], '{alto}');  (*280*)
  SetString (ourXKey^[10], '{altp}'); (*281*)   (* 28-Nov-89 RSC enabled *)
  

  SetString (ourXKey^[11], '');  (**)
  SetString (ourXKey^[12], '');  (**)
  SetString (ourXKey^[13], '');  (**)
  SetString (ourXKey^[14], '');  (**)
                                  (* missing 11,12,13,14 = 4 *)
  SetCodeBits (ExtendedCharSet, 286, 294, TRUE);
  SetString (ourXKey^[15], '{alta}'); (*286*)
  SetString (ourXKey^[16], '{alts}'); (*287*)
  SetString (ourXKey^[17], '{altd}'); (*288*)
  SetString (ourXKey^[18], '{altf}'); (*289*)
  SetString (ourXKey^[19], '{altg}'); (*290*)
  SetString (ourXKey^[20], '{alth}'); (*291*)
  SetString (ourXKey^[21], '{altj}'); (*292*)
  SetString (ourXKey^[22], '{altk}'); (*293*)
  SetString (ourXKey^[23], '{altl}'); (*294*)

  SetString (ourXKey^[24], '');  (**)
  SetString (ourXKey^[25], '');  (**)
  SetString (ourXKey^[26], '');  (**)
  SetString (ourXKey^[27], '');  (**)
  SetString (ourXKey^[28], '');  (**)
                                  (* missing 24,25,26,27,28 = 5 *)
  SetCodeBits (ExtendedCharSet, 300, 306, TRUE);
  SetString (ourXKey^[29], '{altz}'); (*300*)
  SetString (ourXKey^[30], '{altx}'); (*301*)
  SetString (ourXKey^[31], '{altc}'); (*302*)
  SetString (ourXKey^[32], '{altv}'); (*303*)  (* 28-Nov-89 RSC allow altC and V *)
  SetString (ourXKey^[33], '{altb}'); (*304*)
  SetString (ourXKey^[34], '{altn}'); (*305*)
  SetString (ourXKey^[35], '{altm}'); (*306*)
         
  SetString (ourXKey^[36], '');  (**)
  SetString (ourXKey^[37], '');  (**)
  SetString (ourXKey^[38], '');  (**)
  SetString (ourXKey^[39], '');  (**)
  SetString (ourXKey^[40], '');  (**)
  SetString (ourXKey^[41], '');  (**)
  SetString (ourXKey^[42], '');  (**)
  SetString (ourXKey^[43], '');  (**)
                              (* missing 36,37,38,39,40,41,42,43 = 8 *)
  SetCodeBits (ExtendedCharSet, 315, 324, TRUE);
  SetString (ourXKey^[44], '{f1}'); (*315*)
  SetString (ourXKey^[45], '{f2}'); (*316*)
  SetString (ourXKey^[46], '{f3}'); (*317*)
  SetString (ourXKey^[47], '{f4}'); (*318*)
  SetString (ourXKey^[48], '{f5}'); (*319*)
  SetString (ourXKey^[49], '{f6}'); (*320*)
  SetString (ourXKey^[50], '{f7}'); (*321*)
  SetString (ourXKey^[51], '{f8}'); (*322*)
  SetString (ourXKey^[52], '{f9}'); (*323*)
  SetString (ourXKey^[53], '{f10}');  (*324*)   (**)   (* should this be excluded, as well as
                                        some others *)
  SetString (ourXKey^[54], '');  (**)
  SetString (ourXKey^[55], '');  (**)
                                  (* missing 54,55 = 2 *)
  SetCodeBits (ExtendedCharSet, 327, 329, TRUE);
  SetString (ourXKey^[56], '{home}'); (*327*)
  SetString (ourXKey^[57], '{up}');   (*328*)
  SetString (ourXKey^[58], '{pgup}'); (*329*)

  SetString (ourXKey^[59], '');  (**)
                                  (* missing 59 = 1 *)
  SetCodeBits (ExtendedCharSet, 331, 331, TRUE);
  SetString (ourXKey^[60], '{lft}');  (*331*)
                                  (* missing 61 = 1 *)
  SetString (ourXKey^[61], '');  (**)

  SetCodeBits (ExtendedCharSet, 333, 333, TRUE);
  SetString (ourXKey^[62], '{rgt}');  (*333*)

  SetString (ourXKey^[63], '');  (**)
                                  (* missing 63 = 1 *)
  SetCodeBits (ExtendedCharSet, 335, 369, TRUE);
  SetString (ourXKey^[64], '{end}');  (*335*)
  SetString (ourXKey^[65], '{dn}');   (*336*)
  SetString (ourXKey^[66], '{pgdn}'); (*337*)
  SetString (ourXKey^[67], '{ins}');  (*338*)
  SetString (ourXKey^[68], '{del}');  (*339*)
  SetString (ourXKey^[69], '{capsf1}'); (*340*)
  SetString (ourXKey^[70], '{capsf2}'); (*341*)
  SetString (ourXKey^[71], '{capsf3}'); (*342*)
  SetString (ourXKey^[72], '{capsf4}'); (*343*)
  SetString (ourXKey^[73], '{capsf5}'); (*344*)
  SetString (ourXKey^[74], '{capsf6}'); (*345*)
  SetString (ourXKey^[75], '{capsf7}'); (*346*)
  SetString (ourXKey^[76], '{capsf8}'); (*347*)
  SetString (ourXKey^[77], '{capsf9}'); (*348*)
  SetString (ourXKey^[78], '{capsf10}'); (*349*)
  SetString (ourXKey^[79], '{ctrlf1}'); (*350*)
  SetString (ourXKey^[80], '{ctrlf2}'); (*351*)
  SetString (ourXKey^[81], '{ctrlf3}'); (*352*)
  SetString (ourXKey^[82], '{ctrlf4}'); (*353*)
  SetString (ourXKey^[83], '{ctrlf5}'); (*354*)
  SetString (ourXKey^[84], '{ctrlf6}'); (*355*)
  SetString (ourXKey^[85], '{ctrlf7}'); (*356*)
  SetString (ourXKey^[86], '{ctrlf8}'); (*357*)
  SetString (ourXKey^[87], '{ctrlf9}'); (*358*)
  SetString (ourXKey^[88], '{ctrlf10}'); (*359*)
  SetString (ourXKey^[89], '{altf1}'); (*360*)
  SetString (ourXKey^[90], '{altf2}'); (*361*)
  SetString (ourXKey^[91], '{altf3}'); (*362*)
  SetString (ourXKey^[92], '{altf4}'); (*363*)
  SetString (ourXKey^[93], '{altf5}'); (*364*)
  SetString (ourXKey^[94], '{altf6}'); (*365*)
  SetString (ourXKey^[95], '{altf7}'); (*366*)
  SetString (ourXKey^[96], '{altf8}'); (*367*)
  SetString (ourXKey^[97], '{altf9}'); (*368*)
  SetString (ourXKey^[98], '{altf10}'); (*369*)

  SetString (ourXKey^[99], '');  (**)
                                       (* missing 99 = 1 *)
  SetCodeBits (ExtendedCharSet, 371, 388, TRUE);
  SetString (ourXKey^[100], '{ctrllft}'); (*371*)
  SetString (ourXKey^[101], '{ctrlrgt}'); (*372*)
  SetString (ourXKey^[102], '{ctrlend}'); (*373*)
  SetString (ourXKey^[103], '{ctrlpgdn}'); (*374*)
  SetString (ourXKey^[104], '{ctrlhome}'); (*375*)
  SetString (ourXKey^[105], '{alt1}'); (*376*)
  SetString (ourXKey^[106], '{alt2}'); (*377*)
  SetString (ourXKey^[107], '{alt3}'); (*378*)
  SetString (ourXKey^[108], '{alt4}'); (*379*)
  SetString (ourXKey^[109], '{alt5}'); (*380*)
  SetString (ourXKey^[110], '{alt6}'); (*381*)
  SetString (ourXKey^[111], '{alt7}'); (*382*)
  SetString (ourXKey^[112], '{alt8}'); (*383*)
  SetString (ourXKey^[113], '{alt9}'); (*384*)
  SetString (ourXKey^[114], '{alt0}'); (*385*)
  SetString (ourXKey^[115], '{alt-}'); (*386*)
  SetString (ourXKey^[116], '{alt=}'); (*387*)
  SetString (ourXKey^[117], '{ctrlpgup}'); (*388*)
********************)



END SetUpExKeys;


PROCEDURE SetUpNormKeys;
VAR
    ourNormKey : POINTER TO ARRAY [0..31] OF name;
    dummy      : CARDINAL;
    EntriesToRead,
    RowsToRead,
    i,j,k,Element       : CARDINAL;
    s                   : ARRAY[0..10] OF CHAR;

BEGIN

    NEW (ourNormKey);
  
    FOR i := 0 TO 31 DO
      SetLengthOf (ourNormKey^[i], 0);
    END;

    SetCodeBits (SpecialCharSet, 0, MaxCode, FALSE);
    SetCodeBits (SpecialCharSet, 0, 31, TRUE);

    Element := 1;

    GetMessageWord ( ModuleNumber + 16, 0, s );
    k := 1;
    RowsToRead := StoC ( s, k );

    j := 1;
    REPEAT
       GetMessageWord ( ModuleNumber + 16 + j, 0, s );
       k := 1;
       EntriesToRead := StoC ( s, k );

       FOR i := 1 TO EntriesToRead DO
          GetMessageWord ( ModuleNumber + 16 + j, i, ourNormKey^[Element] );
          INC(Element);
       END;

       INC(j);
    UNTIL ( j > RowsToRead );

    IF CreateExtObject (NormKey, MacStoragePreference) THEN
      IF SaveHeapCopy (NormKey, ourNormKey, SIZE(ourNormKey^)) THEN
        dummy := 1;
      END;
    END;
(***
  SetCodeBits (SpecialCharSet, 0, MaxCode, FALSE);
  SetCodeBits (SpecialCharSet, 0, 31, TRUE);
  SetString (ourNormKey^[0], '');          (*0*)
  SetString (ourNormKey^[1], '{ctrla}');   (*1*)
  SetString (ourNormKey^[2], '{ctrlb}');   (*2*)
  SetString (ourNormKey^[3], '{ctrlc}');   (*3*)
  SetString (ourNormKey^[4], '{ctrld}');   (*4*)
  SetString (ourNormKey^[5], '{ctrle}');   (*5*)
  SetString (ourNormKey^[6], '{ctrlf}');   (*6*)
  SetString (ourNormKey^[7], '{ctrlg}');   (*7*)
  SetString (ourNormKey^[8], '{bks}');     (*8*)
  SetString (ourNormKey^[9], '{tab}');     (*9*)
  SetString (ourNormKey^[10], '{ctrlj}');  (*10*)
  SetString (ourNormKey^[11], '{ctrlk}');  (*11*)
  SetString (ourNormKey^[12], '{ctrll}');  (*12*)
  SetString (ourNormKey^[13], '{enter}');  (*13*)
  SetString (ourNormKey^[14], '{ctrln}');  (*14*)
  SetString (ourNormKey^[15], '{ctrlo}');  (*15*)
  SetString (ourNormKey^[16], '{ctrlp}');  (*16*)
  SetString (ourNormKey^[17], '{ctrlq}');  (*17*)
  SetString (ourNormKey^[18], '{ctrlr}');  (*18*)
  SetString (ourNormKey^[19], '{ctrls}');  (*19*)(* special... Screen Scroll stop.. 3 hits*)
  SetString (ourNormKey^[20], '{ctrlt}');  (*20*)
  SetString (ourNormKey^[21], '{ctrlu}');  (*21*)
  SetString (ourNormKey^[22], '{ctrlv}');  (*22*)
  SetString (ourNormKey^[23], '{ctrlw}');  (*23*)
  SetString (ourNormKey^[24], '{ctrlx}');  (*24*)
  SetString (ourNormKey^[25], '{ctrly}');  (*25*)
  SetString (ourNormKey^[26], '{ctrlz}');  (*26*)
  SetString (ourNormKey^[27], '{esc}');    (*27*)
  SetString (ourNormKey^[28], '{ctrl\}');  (*28*)
  SetString (ourNormKey^[29], '{ctrl]}');  (*29*)
  SetString (ourNormKey^[30], '{ctrl^}');  (*30*)
  SetString (ourNormKey^[31], '{ctrl_}');  (*31*)

********************)
(* ************ REMOVED 6-Dev-89 By RSC!!!
  IF CreateExtObject (NormKey, MacStoragePreference) THEN
    IF SaveHeapCopy (NormKey, ourNormKey, SIZE(ourNormKey^)) THEN
      dummy := 1;
    END;
  END;
************************ *)

END SetUpNormKeys;

PROCEDURE SetUpCommands;
VAR
    EntriesToRead,
    i,k, Element        : CARDINAL;
    s                   : ARRAY[0..10] OF CHAR;

BEGIN

    Element := 0;
    GetMessageWord ( ModuleNumber + 21, 0, s );
    k := 1;
    EntriesToRead := StoC ( s, k );

    FOR i := 1 TO EntriesToRead DO
       GetMessageWord ( ModuleNumber + 21, i, Command[Element] );
       INC(Element);
    END;

(****
  SetString (Command[0], '{begmsg}');
  SetString (Command[1], '{endmsg}');
  SetString (Command[2], '{begmenu}');
  SetString (Command[3], '{endmenu}');
  SetString (Command[4], '{pause}');
  SetString (Command[5], '{begloop}');
  SetString (Command[6], '{endloop}');
  SetString (Command[7], '{beglink}');
  SetString (Command[8], '{endlink}');
**********)
END SetUpCommands;



PROCEDURE SetUpEditCodeSet;
BEGIN
    EditCodeSet := ExtendedCharSet;
    SetCodeBits (EditCodeSet, 13, 13, FALSE);     (* enter *)
    SetCodeBits (EditCodeSet, 371, 372, FALSE);     (* Ctrl-left & right *)
    SetCodeBits (EditCodeSet, 317, 317, FALSE);     (* F3 *)
    SetCodeBits (EditCodeSet, 320, 323, FALSE);     (* F6,F7,F8,F9 *)
    SetCodeBits (EditCodeSet, 328, 328, FALSE);     (* up *)
    SetCodeBits (EditCodeSet, 331, 331, FALSE);     (* lft *)
    SetCodeBits (EditCodeSet, 333, 333, FALSE);     (* rgt *)
    SetCodeBits (EditCodeSet, 336, 336, FALSE);     (* dn *)
    SetCodeBits (EditCodeSet, 327, 327, FALSE);     (* home *)
    SetCodeBits (EditCodeSet, 337, 337, FALSE);     (* pgdn *)
    SetCodeBits (EditCodeSet, 329, 329, FALSE);     (* pgup *)
    SetCodeBits (EditCodeSet, 335, 335, FALSE);     (* end *)
    SetCodeBits (EditCodeSet, 338, 339, FALSE);     (* ins, del *)
    SetCodeBits (EditCodeSet, 348, 348, FALSE);     (* Shift/F9 *)
    SetCodeBits (EditCodeSet, 363, 363, FALSE);     (* AltF4 *)
    SetCodeBits (EditCodeSet, 368, 369, FALSE);     (* AltF9, AltF10 *)
END SetUpEditCodeSet;


PROCEDURE SetUpEditNavSet;
BEGIN
  SetCodeBits (EditNavSet, 322, 323, TRUE);         (* F8, F9 *)
  SetCodeBits (EditNavSet, 13, 13, TRUE);           (* Enter *)
  SetCodeBits (EditNavSet, 338, 338, TRUE);         (* Ins *)
  SetCodeBits (EditNavSet, 331, 331, TRUE);         (* left *)
  SetCodeBits (EditNavSet, 333, 333, TRUE);         (* right *)
  SetCodeBits (EditNavSet, 335, 337, TRUE);         (* end, down, pgdn *)
  SetCodeBits (EditNavSet, 327, 329, TRUE);         (* home, up, pgup *)
  SetCodeBits (EditNavSet, 371, 372, TRUE);         (* ctrl/left, ctrl/rt *)
END SetUpEditNavSet;


END MacKeys.              
