IMPLEMENTATION MODULE WBSCommon;

  (*   Common routines used by the WBS manager functions.

        MODIFICATION HISTORY:

         19-Apr-89  MWP  In the beginning...
         15-May-89  MWP  Added support for new method of storing WBS codes in
                         AText format.
          6-Jun-89  AJL  Removed import of AFilterRecordPointer.
         11-Jun-89  MWP  Removed ALL extraneous imports.
          5-Jul-89  MWP  Store BS form values in both Config file and
                         schedule file.
         11-Jul-89  MWP  When calling the routines to set a WBS highlight,
                         we were not reporting that a particular error type
                         had occured if we did not want highlights for that
                         error class. As people may want a range of tasks
                         verified, but not highlighted, this has been changed.
         19-Jul-89  MWP  Import WBS form defaults from phrases file.
         19-Jul-89  MWP  Initialize WBS DictionaryInUse flag to FALSE.
         29-Jul-89  MWP  Initialize default follow by value for segment 5 to
                         nil.
         29-Jul-89  MWP  SetBlankHighlight, SetDuplicateHighlight, and
                         SetBadCodeHighlight removed. New proc, SetWBSHighlight,
                         implemented. All WBS errors will call SetWBSHighlight,
                         and the appropriate error condition will be noted in
                         the AUX 20 field.
         29-Jul-89  MWP  CopyWBSFilterBits proc removed.
         15-Aug-89  MWP  Use AWBSPtr as parameter.
         18-Aug-89  MWP  Change order of heap checking.
         23-Aug-89  MWP  Change default of Always Show on first WBS segment to
                         Yes.
         25-Aug-89  MWP  WBS Messages are placed in new Gantt column, WBS Errors,
                         instead of Aux 20.
         25-Aug-89  MWP  Remove use of highlight 3 filter.
         29-Aug-89  MWP  Use '0' as the default for all Null character fields.
         19-Jan-90  WKH  Import GetMessageWord from MsgFileAux instead of
                         RptCommon.
         16-Nov-90  AJL -Enlarge the size of the WBS Prefix and add a version
                         number to the record.  This includes providing code in
                         the SetWBSValues procedure to upgrade version 4
                         WBS definitions.  
         23-Jan-91  RSC  Put Holder items in FlexStor.
         13-Feb-91  RSC  Don't delete flexstor holder items explicitly before
                         deleting the held item.
         15-Aug-91 PFG   ClearWBSFilterBitsInTask was using the wrong number
                         for the text line, so errors were never being 
                         cleared.
  *)


FROM Allocs         IMPORT
    (* CONST *)             WBSLine,
                            FirstOtherCodingLine,
    (* TYPE *)              ATaskPtr,
    (* VAR  *)              TaskTree,
    (* TYPE *)              ATaskFilter,
    (* PROC *)              GetCodingField, SetCodingField;

FROM Dialog         IMPORT
    (* TYPE *)              ADialogOption,
    (* PROC *)              MultipleChoiceBox, Error, NotYetImplemented;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, AnExtStoragePreference,
    (* PROC *)              CreateExtObjectWithSize, SetExtData,
                            DiscardExtObject, GetExtData;

FROM Holder         IMPORT
    (* TYPE *)              AHoldType, AHoldTypeSet,
    (* PROC *)              LocateHeldItem, HoldThis, DeleteHeldItem;

FROM LStrings       IMPORT
    (* PROCS *)             SetString, LJust, Copy, TrimRear,
                            SetLengthOf, LengthOf,
                            ConcatS, Search;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage;

FROM MsgFileAux     IMPORT
    (* PROC *)              GetMessageWord;

FROM Space          IMPORT
    (* PROCS *)             HeapAvailable, ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
    (* TYPE *)              SIZE, TSIZE, ADDRESS, ADR;

FROM TaskColNumbers IMPORT 
    (* CONST *)             NumberOfCodingFields;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder, ATree,
                            ATreeNodeAttribute;

CONST
    ModuleNumber    =  WBSModuleNumberBase;

TYPE
    AV4WBSFormsValue         = RECORD
        Prefix              :  ARRAY [0..4] OF CHAR;
        WBSColumns          :  ARRAY [0..MaxWbsRows] OF AWBSColumn;
    END;

VAR
    LocalWBSRecord : AnWBSFormsValue;   (* 23-Jan-91 RSC  *)
    Handle         : AnExtHandle;       (* 23-Jan-91 RSC  *)


PROCEDURE SetWBSValues ( VAR ProgramName    : ARRAY OF CHAR;
                         VAR WBSFormP       : AWBSPtr ) : BOOLEAN;  (* 15-Aug-89 MWP *)
VAR
    Size,
    Class,
    i                       : CARDINAL;
    Category                : AHoldTypeSet;
    Found,
    WBSAddress              : ADDRESS;
    V4WBSValue              : AV4WBSFormsValue;   (* Old, version 4 type. *)
    ok                      : BOOLEAN;
    UpgradeFromVersion4     : BOOLEAN;
BEGIN

    Class := 1;
    UpgradeFromVersion4 := FALSE;

    WBSFormP := ADR(LocalWBSRecord);

    (* Are we holding a previous instance of the Forms record? *)

    IF LocateHeldItem( ProgramName, Class, Category, WBSAddress, Size) THEN
        Handle := AnExtHandle( WBSAddress );
        IF (Size = TSIZE(AnWBSFormsValue) ) THEN
            IF (GetExtData( Handle, WBSFormP ) = TSIZE(AnWBSFormsValue)) AND
                (* If it isn't the version we understand, remove it. *)
               (WBSFormP^.Version = 50) THEN
                RETURN TRUE;
            END;
        ELSIF (Size = TSIZE(AV4WBSFormsValue) ) THEN
                (* If there is a version 4 WBS form, copy it to a local item,
                   and remove it from Holder. *)
            Size := GetExtData( Handle, ADR(V4WBSValue) );
            UpgradeFromVersion4 := TRUE;
        END;
        DeleteHeldItem( ProgramName, Class );
    END;

    (* No instances being held, so set WBSForm to defaults. *)

    InitializeWBSColumns ( WBSFormP );

        (* If there was a Version4 WBS form, transfer its information to
           the new form. *)

    IF (UpgradeFromVersion4) THEN
        FOR i := 0 TO HIGH(V4WBSValue.WBSColumns) DO
            WBSFormP^.WBSColumns[i] := V4WBSValue.WBSColumns[i];
        END;
        Copy(V4WBSValue.Prefix, WBSFormP^.Prefix);
    END;

    ok := CreateExtObjectWithSize( Handle, ExtSlow, TSIZE(AnWBSFormsValue) );
    IF (NOT ok) THEN
        Handle := AnExtHandle(NIL);
    END;

    RETURN ok;

END SetWBSValues;


PROCEDURE SaveWBSValues ( VAR ProgramName    : ARRAY OF CHAR;
                          VAR WBSFormP       : AWBSPtr );           (* 15-Aug-89 MWP *)
VAR
    Class                   : CARDINAL;
    Category                : AHoldTypeSet;

BEGIN
    Class := 1;

    Category := AHoldTypeSet{HoldInDataFile,
                             HeapNoOwner,
                             HoldInFlexStor,    (* 23-Jan-91 RSC *)
                             HoldInConfig};

    IF ((Handle <> AnExtHandle(NIL)) AND
         SetExtData( Handle, WBSFormP, TSIZE(AnWBSFormsValue))) THEN
        HoldThis( ProgramName, Class, Category,
                  ADDRESS(Handle), TSIZE( AnWBSFormsValue ) );
    END;

END SaveWBSValues;






PROCEDURE  InitializeWBSColumns ( VAR  WBSFormP  : AWBSPtr );       (* 15-Aug-89 MWP *)
VAR
    Loop                    : CARDINAL;
    s                       : ARRAY [0..25] OF CHAR;
    s1                      : ARRAY [0..25] OF CHAR;
    s2                      : ARRAY [0..25] OF CHAR;
    s3                      : ARRAY [0..25] OF CHAR;
BEGIN

    WITH  WBSFormP^  DO
        Version := 50;                (* For version 5.0 of Time Line. AJL 16-Nov-90 *)

        SetLengthOf ( Prefix, 0 );

        GetMessageWord ( ModuleNumber , 2, s2);
        (* 0 *)

        (* Setup regular defaults for all WBS rows. *)
        FOR Loop := 0 TO HIGH( WBSColumns ) DO
           WBSColumns[ Loop ].SizeMin := 0;
           WBSColumns[ Loop ].SizeMax := 0;
           SetLengthOf ( WBSColumns[ Loop ].CharacterSequence, 0 );
           SetLengthOf ( WBSColumns[ Loop ].StartWith, 0 );
           WBSColumns[ Loop ].StartOffset := 0;
           WBSColumns[ Loop ].AlwaysShow := No;
(*
           SetLengthOf ( WBSColumns[ Loop ].Null, 0 );
**)
           Copy ( s2, WBSColumns[ Loop ].Null);                     (* 29-Aug-89 MWP *)
           SetLengthOf ( WBSColumns[ Loop ].FollowBy, 0 );
        END;

        GetMessageWord ( ModuleNumber , 0, s);                     (* 19-Jul-89 MWP *)
        (* 0..9 *)
        GetMessageWord ( ModuleNumber , 1, s1);
        (* 1 *)
        GetMessageWord ( ModuleNumber , 2, s2);
        (* 0 *)
        GetMessageWord ( ModuleNumber , 3, s3);
        (* . *)


        FOR Loop := 0 TO 2 DO
           WBSColumns[ Loop ].SizeMin := 2;
           WBSColumns[ Loop ].SizeMax := 2;
           Copy ( s, WBSColumns[ Loop ].CharacterSequence );
           Copy ( s1, WBSColumns[ Loop ].StartWith );
           WBSColumns[ Loop ].StartOffset := 1;
           WBSColumns[ Loop ].AlwaysShow := No;
           Copy ( s2, WBSColumns[ Loop ].Null);
           Copy ( s3, WBSColumns[ Loop ].FollowBy);
        END;


        GetMessageWord ( ModuleNumber + 1, 0, s);
        (* A..HJ..NP..Y *)
        GetMessageWord ( ModuleNumber + 1, 1, s1);
        (* A *)
        GetMessageWord ( ModuleNumber + 1, 2, s2);
        (* 0 *)
        GetMessageWord ( ModuleNumber + 1, 3, s3);
        (* . *)


        FOR Loop := 3 TO 4 DO
           WBSColumns[ Loop ].SizeMin := 2;
           WBSColumns[ Loop ].SizeMax := 2;
           Copy ( s, WBSColumns[ Loop ].CharacterSequence );
           Copy ( s1, WBSColumns[ Loop ].StartWith );
           WBSColumns[ Loop ].StartOffset := 1;
           WBSColumns[ Loop ].AlwaysShow := No;
           Copy ( s2, WBSColumns[ Loop ].Null);
           Copy ( s3, WBSColumns[ Loop ].FollowBy);
        END;

        WBSColumns[ 0 ].SizeMin := 3;
        WBSColumns[ 0 ].SizeMax := 3;
        WBSColumns[ 0 ].AlwaysShow := Yes;                          (* 21-Aug-89 MWP *)
        SetLengthOf ( WBSColumns[ 4 ].FollowBy, 0 );                (* 29-Jul-89 MWP *)
    END;

END InitializeWBSColumns;






PROCEDURE SelectWBSRangeDialog ( VAR Text     : ARRAY OF CHAR;
                                 VAR BoxTitle : ARRAY OF CHAR;
                                 VAR Choice   : CARDINAL ) : BOOLEAN;
VAR
    Choices                 : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..1]   OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    SetLengthOf ( s, 0 );

    GetMessage ( ModuleNumber + 2, Choices );
    (*  All Tasks, This Task and Family, Children, This Task *)

    ok := MultipleChoiceBox ( Text, BoxTitle, OfferHelp, s, Choices, Choice);

    RETURN ok;

END SelectWBSRangeDialog;






PROCEDURE PerformConfirmationDialog ( VAR Prefix : ARRAY OF CHAR;
                                      VAR Choice : CARDINAL ) : BOOLEAN;
VAR
    Title                   : ARRAY [0..1] OF CHAR;
    Choices                 : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..1]   OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    ok  :=  TRUE;
    SetLengthOf ( Title, 0 );
    SetLengthOf ( s, 0 );

    GetMessage ( ModuleNumber + 3, Choices );
    (*  Proceed,Cancel *)

    ok := MultipleChoiceBox ( Prefix, Title, OfferHelp, s, Choices, Choice);

    RETURN ok;

END PerformConfirmationDialog;





PROCEDURE GetWBSCode   (     Node    : ATreeNode;
                         VAR s       : ARRAY OF CHAR );
VAR
    TaskPtr                 : ATaskPtr;

BEGIN
    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);

    GetCodingField ( TaskPtr^, WBSLine, s );

    Node^.Methods^.UnlockUnchangedDataObject (Node);

    LJust    ( s );
    TrimRear ( s );

END GetWBSCode;







PROCEDURE SetWBSCode   ( VAR Node    : ATreeNode;
                         VAR s       : ARRAY OF CHAR );
VAR
    TaskPtr                 : ATaskPtr;

BEGIN

    IF ( LengthOf ( s ) > MaxWbsSize ) THEN
       SetLengthOf ( s, MaxWbsSize );
    END;

    LJust    ( s );
    TrimRear ( s );

    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);

    SetCodingField ( TaskPtr^, WBSLine, s );

    Node^.Methods^.UnlockFlexStorDataObject (Node);

END SetWBSCode;






PROCEDURE SetWBSHighlight (VAR TaskNode : ATreeNode );              (* 29-Jul-89 MWP *)
BEGIN

    TaskNode^.Methods^.SetAttributeBit ( TaskNode, TempFlag2, TRUE ); (* 25-Aug-89 MWP *)

END SetWBSHighlight;






PROCEDURE ClearWBSFilterBitsInTree ( VAR Tree : ATree );
VAR
    TaskNode                : ATreeNode ;
BEGIN
    TaskNode := ATreeNode(NIL);

    Tree^.Methods^.TraverseTree( Tree,
                                 ParentAfterChild,
                                 9999,
                                 ClearWBSFilterBitsInTask,
                                 ADR(TaskNode) );
END ClearWBSFilterBitsInTree;








PROCEDURE ClearWBSFilterBitsInTask ( VAR TaskNode : ATreeNode;
                                         Context  : ADDRESS );
VAR
    TaskPtr                 : ATaskPtr;
    s                       : ARRAY [0..1] OF CHAR;
BEGIN
    SetLengthOf ( s , 0 );

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    SetCodingField ( TaskPtr^, 
                     FirstOtherCodingLine + NumberOfCodingFields, (* 15-Aug-91 PFG *)
                     s );               (* 25-Aug-89 MWP *)

    TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);

    TaskNode^.Methods^.SetAttributeBit ( TaskNode, TempFlag2, FALSE ); (* 25-Aug-89 MWP *)

END ClearWBSFilterBitsInTask;






PROCEDURE ErrorsInTask ( VAR TaskNode : ATreeNode ) : BOOLEAN;
VAR
    ok                      : BOOLEAN;
BEGIN
    ok := TaskNode^.Methods^.TestAttributeBit ( TaskNode, TempFlag2 );    (* 25-Aug-89 MWP *)

    RETURN ( ok );
END ErrorsInTask;







PROCEDURE CheckForWildCardCharacter ( VAR CheckString : ARRAY OF CHAR ) : BOOLEAN;
VAR
    MatchSeq                : ARRAY [0..1] OF CHAR;
    OutLen                  : CARDINAL;
BEGIN
    SetLengthOf ( MatchSeq, 1 );
    MatchSeq[1] := '?';

    OutLen := Search ( CheckString, MatchSeq, 1 );

    IF ( OutLen <> 0 ) THEN
       RETURN FALSE;
    END;

    RETURN TRUE;
END CheckForWildCardCharacter;







PROCEDURE DisplayErrorMessage ();
VAR
    ErrorMessage            : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage ( ModuleNumber + 25, ErrorMessage );
    (* "Error(s) have occured generating WBS codes" *)
    Error ( ErrorMessage );
END DisplayErrorMessage;




BEGIN
    DictionaryInUse := FALSE;                                       (* 19-Jul-89 MWP *)
    Handle          := AnExtHandle(NIL);
END WBSCommon.
