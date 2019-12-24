IMPLEMENTATION MODULE Chainer;

    (* MODIFICATION HISTORY:

       15 Jun 89  AJL -Pick up overlay names from the run line parameter
                       ADDIN=( ).  This is a comma-separated list of
                       overlay names.  Any that begin with "-" will be
                       avoided instead of loaded, so, for example,
                       ADDIN=(MOREMEM,-TLMACROS) would prevent macros from 
                       loading, and add an overlay called "MOREMEM" to the
                       chain list.

       29 Jun 89  RSC -Minor improvement to fix bug Wayne noticed.
       25 Jul 89  RSC -Removed improvement of 29-Jun-89 - Didn't work.
       23 May 90  AJL -Converted to use a linked list to save space.
                      -Calls with OverlayPackage so that we can have
                       parameters to overlays. 
    *)  
                       




FROM LStrings   IMPORT
    (* PROC *)         Copy, SetString, Upshift, Search, LengthOf,
                       Remove, StringsEqual;

FROM Menus      IMPORT
    (* PROC *)         WordNumber;

FROM Overlays   IMPORT
    (* PROC *)         OverlayPackage;

FROM Paranoia   IMPORT
    (* TYPE *)         AProgramState,
    (* VAR  *)         ProgramState;

FROM ParmLine   IMPORT
    (* PROC *)         GetOption;

FROM Space                  IMPORT
  (* PROCS *)                   ALLOCATE, DEALLOCATE, Available;

FROM Words      IMPORT
  (* TYPE *)           ASetOfDelimiters,
  (* PROC *)           ParseBalWithDelimiter; 



CONST
    MaxNameSize = 30;


TYPE
    AChainRecordPointer = POINTER TO AChainRecord;
    AChainRecord  =  RECORD
                         Name : ARRAY [0..MaxNameSize] OF CHAR;
                         Load : BOOLEAN;
                         Next : AChainRecordPointer;
                     END;


VAR
    Top             : AChainRecordPointer;
    RunLineLoaded   : BOOLEAN;



    (* Additional module -- Add the module to the set of modules to
                            load, or to avoid. *)


PROCEDURE AdditionalModule( VAR NewName : ARRAY OF CHAR;
                                NewLoad    : BOOLEAN        );
VAR
    i,j : CARDINAL;
    Node : AChainRecordPointer;
    S1 : ARRAY [0..1] OF CHAR;
BEGIN
         (* Look for an existing entry.  If found, do 
            not overwrite.   We actually look for any substring
            match so that "/!TLMACRO" will match "TLMACRO". *)
    Node := Top;
    WHILE (Node <> NIL) DO
        j := 1;
        IF (Search(NewName,Node^.Name,j) <> 0) THEN
            SetString(S1,"(");
            i := Search(S1,Node^.Name,j);
            IF (i = 0) OR (i > j) THEN	 (* Name found before any parms. *)
                RETURN;  
            END;
        END;
        Node := Node^.Next;
    END;
 
        (* Add the entry. *)

    NEW(Node);
    IF (Node = NIL) THEN
        RETURN;
    END;

    WITH Node^ DO
        Copy(NewName,Name);
        Load := NewLoad;
        Next := Top;   
    END;

    Top := Node;
    

END AdditionalModule;






PROCEDURE AddModuleName( VAR Name     : ARRAY OF CHAR );    (* LString *)
BEGIN
       (* After the program is safely running, load the list of
          overlay names to avoid. *)
    IF (Top = NIL) THEN
        Init(FALSE);
    END; 
    AdditionalModule(Name,TRUE);
END AddModuleName;



PROCEDURE Chain;
VAR
    S : ARRAY [0..MaxNameSize] OF CHAR;
    Node : AChainRecord;
    NextPointer : AChainRecordPointer;
    OK : BOOLEAN;
BEGIN
        (* Load any add-ins mentioned on the run line before any
           others. *)
    IF (NOT RunLineLoaded) THEN 
        Init(TRUE);
        RunLineLoaded := TRUE;
    END;

        (* Call the next stacked overlay. *)

	(* Run through the stack, popping entries, and calling the 
           overlays, unless they are marked as not to load, in which
           case we skip them.  If we fail on a load, we stop calling.
        *) 

    OK := TRUE;

    WHILE (Top <> NIL) DO
            (* Pop(Top) *)
        Node := Top^;
        NextPointer := Top^.Next;
        DISPOSE(Top);
        Top := NextPointer;

        IF (OK) AND (Node.Load) THEN
            OK := OverlayPackage(Node.Name);
        END;
    END;
END Chain;



PROCEDURE Init(AddRealOverlays:BOOLEAN);
VAR
    Skip,
    Delimit : ASetOfDelimiters;
    S2 : ARRAY [0..81] OF CHAR;
    S  : ARRAY [0..255] OF CHAR;

    i,j  : CARDINAL;
    OK : BOOLEAN;
BEGIN
    SetString(S2,"ADDIN");
    GetOption(S2,OK,S);
    Upshift(S);

    Skip    := ASetOfDelimiters{" "};
    Delimit := ASetOfDelimiters{"("," ",","};

    IF (OK) THEN
        i := 1;
        j := 1;
        LOOP
                (* Tolerate either lists separated by commas or grouped
                   by parenthesis. *)
            ParseBalWithDelimiter( S,j,Skip,Delimit,S2);
            IF (S[j]=",") THEN                          (* Skip any comma separator. *)
                INC(j);
            END;
            IF (LengthOf(S2)=0) THEN
                EXIT;
            ELSE
                IF (S2[1]="-") THEN
                    OK := FALSE;
                    Remove(S2,1,1);
                ELSE
                    OK := TRUE;
                END;
                    (* Either add the ones to call, or the ones to
                       avoid. *)
                IF (OK = AddRealOverlays) THEN
                    AdditionalModule(S2,OK);
                END;
            END;
            INC(i);
        END;  
    END;
END Init;



BEGIN
    RunLineLoaded := FALSE;
    Top := NIL;
END Chainer.
