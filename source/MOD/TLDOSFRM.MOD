MODULE TLDOSFrm;

(*  =========================================================================
    Last Edit : November 9, 1990 5:34PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Run a DOS command.        

    MODIFICATION HISTORY:

    21-Sep-89 AJL  Created by moving the code here from TLDOS so that
                   the TLDOS overlay will be smaller by not including 
                   all the Forms stuff.
     9-Nov-90 PFG   Add the 4.0.3 changes:
                    23-Sep-90 TGS  
                        Require a program name to be filled in.
                    End of 4.0.3 changes.
    26-Apr-91 AJL  If there are parameters after the file name, move
                   them to the parameters field.
                   Remove unreferenced identifiers.
    =========================================================================
*)


FROM Codes          IMPORT
    (* TYPE *)           ACode;

FROM Dialog         IMPORT
    (* PROC *)           FatalError;

FROM FormCon        IMPORT
    (* TYPE *)           AFieldNo;

FROM Forms          IMPORT
    (* TYPE  *)          AForm, AFieldValue, ACheckReason,
    (* PROC  *)          DoForm, ShowValue;

FROM Kbio           IMPORT
    (* CONST *)          maxcol;

FROM Keys           IMPORT
    (* CONST *)          ExitKey;

FROM Layout         IMPORT
    (* VAR *)            GanttWEnd;

FROM LStrings       IMPORT
    (* PROC *)          SetString, ConcatS,
                        ConcatLS, Fill, LengthOf, SetLengthOf,
                        Copy, TrimRear, LJust, SubStr, Remove,
                        Search;

FROM MsgFile        IMPORT
    (* PROCS *)         DisplayMessage;
 
FROM Overlays       IMPORT
    (* PROC *)           OverlayContext;

FROM Space          IMPORT
    (* PROCS *)         ALLOCATE, DEALLOCATE;


CONST 
    ModuleNumber = 22900; (* For DisplayMessage *)


    (* Must match the one in TLDOS! *)
TYPE
    ASpecification = ARRAY [0..255] OF CHAR;
    AContextRecord = 
        RECORD
            Tag  : CARDINAL; 
            Spec : POINTER TO ASpecification;
            OK            : BOOLEAN; 
        END; 
VAR
    ContextRecord : POINTER TO AContextRecord;



(* 23-Sep-90 TGS Added this here CheckForm: *)

PROCEDURE CheckForm(    Form        : AForm;
                        FieldNo     : AFieldNo; 
                    VAR FormValue   : ARRAY OF AFieldValue; 
                        CheckReason : ACheckReason; 
                    VAR Code        : CARDINAL
                                                      ) : BOOLEAN;

CONST 
    PNM = 0; (* ProgramName *)
    PPS = 1; (* ProgramParameters *)

VAR 
    s         : ARRAY [0..255] OF CHAR; 
    CodeIn    : CARDINAL; 
    i         : CARDINAL;
    Space     : ARRAY [0..1] OF CHAR;

BEGIN 
    CodeIn := Code; 
    Code := 0;  (* For safety on return. *) 

    CASE FieldNo OF 
            (* NAME FIELD *)
      PNM: WITH FormValue[PNM] DO   
               LJust(    CharValue^); 
               TrimRear( CharValue^); 
               IF (LengthOf(CharValue^) = 0) THEN 
                   DisplayMessage(ModuleNumber+29); (*  "Please enter a program name."  *)
                   RETURN FALSE;
               END;
                   (* If there are parameters after the file name, move
                      them to the parameters field. *)
               Fill(Space," ",1);
               i := Search(CharValue^,Space,1);
               IF (i > 0) THEN
                   SubStr(CharValue^,s,i+1,LengthOf(CharValue^)-i);
                   Remove(CharValue^,i,LengthOf(CharValue^));
                   LJust(s);
                   Copy(s,FormValue[PPS].CharValue^);
                       (* Redisplay both fields. *)
                   ShowValue(Form,PNM,FormValue);
                   ShowValue(Form,PPS,FormValue);
               END;
           END; 

    | PPS:

    ELSE
    END;
    RETURN TRUE;
END CheckForm;



PROCEDURE GetSpecification(  VAR Specification : ASpecification ) : BOOLEAN;
CONST
    ExecFORMID      =   66;
    ExecFormLeft    =   0;
    ExecFormTop     =   0;
    ExecFormRight   =   maxcol;
VAR
    FormValue   :   ARRAY [0..1] OF AFieldValue;
    Code        :   ACode;
BEGIN

    NEW(FormValue[0].CharValue);
    SetLengthOf(FormValue[0].CharValue^,0);
    NEW(FormValue[1].CharValue);
    SetLengthOf(FormValue[1].CharValue^,0);

    Code := DoForm(ExecFormLeft, ExecFormTop,ExecFormRight, GanttWEnd,
                                 ExecFORMID, TRUE, FormValue, CheckForm); 

    Copy(FormValue[0].CharValue^,Specification);
    TrimRear(Specification);
    ConcatS(Specification,"(");
    TrimRear(FormValue[1].CharValue^);
    ConcatLS(Specification,FormValue[1].CharValue^);
    ConcatS(Specification,")");

    DISPOSE(FormValue[0].CharValue);
    DISPOSE(FormValue[1].CharValue);

    RETURN ( Code = ExitKey );
END GetSpecification;




BEGIN
    ContextRecord := OverlayContext();
    WITH ContextRecord^ DO
        IF (Tag = 9209) THEN                           (* Secret handshake. *)
            OK := GetSpecification(Spec^);
        ELSE 
            FatalError;
        END;
    END;
END TLDOSFrm.
