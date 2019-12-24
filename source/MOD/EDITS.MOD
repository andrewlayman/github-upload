  (* MODIFICATION HISTORY:

       16-Dec-87   RSC   moved this into an overlay called TlEdits.Mod.
       04-Mar-88   LAA   Make sure the edit box title has a leading and
                         trailing blank.
       05-Mar-88   LAA   Fixed yesterday's fix.
       06-Mar-88   LAA   Fixed my fix to my fix.  Shit!
  *)


IMPLEMENTATION MODULE Edits;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, Copy, LengthOf, Insert, ConcatLS,
                                TrimFront, TrimRear, Overlay;

FROM Overlays               IMPORT
        (* PROCS *)             CallOverlayWithContext;

FROM SYSTEM                 IMPORT
        (* Thing *)             ADR;

FROM Text                   IMPORT
    (* TYPE *)                  AText;



CONST
    ModuleNumber                = 20000;  (* ALSO USED BY TlEdits.Mod *)


(*----------------------------------------------------------------------------
    EditText --

    Allow editing of the indicated text, and replace it if changed.

    Preconditions:
        The text must have been created by the Text module.

    Postconditions:
        The text, as changed, will be returned.
----------------------------------------------------------------------------*)

PROCEDURE EditText(    Ulx                  : ascreenx;
                       Uly                  : ascreeny;
                       Lrx                  : ascreenx;
                       Lry                  : ascreeny;
                       Box                  : ABoxType;
                   VAR Title                : ARRAY OF CHAR;
                       HelpNumber           : CARDINAL;
                   VAR Text                 : AText;
                   VAR Changed              : BOOLEAN );
VAR
    PrivateEditContext : APrivateEditContext;
    OverlayName        : ARRAY [0..9] OF CHAR;
    ok                 : BOOLEAN;
BEGIN                       (* EditText *)

    WITH PrivateEditContext DO
        PUlx           := Ulx;
        PUly           := Uly;
        PLrx           := Lrx;
        PLry           := Lry;
        PHelpNumber    := HelpNumber;
        PText          := Text;
        PBox           := Box;
        Copy( Title, PTitle );
        TrimFront(PTitle);                                        (* 04-Mar-88 LAA *)
        TrimRear(PTitle);
        IF ((LengthOf(PTitle) > 0) AND (LengthOf(PTitle) <= HIGH(PTitle)-2)) THEN            (* 05-Mar-88 LAA *)
            SetString(OverlayName, " ");
            Insert(PTitle, OverlayName, 1);
            ConcatLS(PTitle, OverlayName);
        END;
        PChanged       := Changed;
    END;
    SetString( OverlayName, "|TLEDITS" );
    ok := CallOverlayWithContext( OverlayName, ADR( PrivateEditContext ) );
    WITH PrivateEditContext DO
        Changed := PChanged;
        Text    := PText;
    END;

END EditText;


BEGIN                       (* Edits *)
END Edits.
