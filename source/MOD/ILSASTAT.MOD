IMPLEMENTATION MODULE IlsaStatic;

(*
    Ilsa Static     - Record definitions for ILSA.

    Client modules need not deal with HOLDER, just these procedures.
    Issues of creating, initializing, and saving the records are not
    up to the client, but to this module and the schedule load/save
    routines.


    Modification History:

        RSC  12-Apr-89  First Version.
        WKH  26-Apr-89  Put GetDefaultFontSpecs in here and zapped the
                        FontName module.  FontName used to support selectable
                        fonts but since exhaustive testing of Ilsa forms
                        showed that font selection capabilities were
                        overkill.  Hence, FontName is no more.  However, we
                        did have to implement GetDefaultFontSpecs here and
                        change it so that it no longer references a 
                        dynamically built font tree.  Instead, the values
                        are hard coded.
        WKH 28-Apr-89   SetString doesn't seem to like to take a variable as
                        a parameter.  Changed to TStringToLString instead.
        LAA 09-May-89   Changed Plot to Pert as in the .DEF, and init'd
                        new fields which I added to the Setup Record.
        LAA  10-May-89  Further changes to the PageRecord and SetupRecord.
                        Added a parameter to GetRecordFromHolder so its
                        clients can control where records are stored.
        WKH 10-May-89   Massive changes to gantt section for new forms!!! 
        WKH 11-May-89   Support for multiple color palettes.
        CMH 12-May-89   Set leading to twice the character size, 20 point.. 
        WKH 16-May-89   Totally changed the structure of the TLGSPlotRecord
                        to reflec "new streamlined" form.
        LAA 18-May-89   Incorporated the above 3 changes by Wayne and Carol,
                        and did a little general cleanup.  Then changed this
                        module to no longer use holder, but to allocate items
                        on the heap.
        WKH 22-May-89   Well, in all the shuffle between coordinating my 
                        fixes and Larry's fixes, it was inevitable something
                        would slip through the cracks.  I, not Larry, forgot
                        to copy over the line that initializes the Leading
                        field in the DefaultFontSpec.  This was causing a
                        cardinal overflow error in Sedona's code.
        WKH 24-May-89   Well, mis-communication between Sedona and Symantec has again
                        caused problems.  We were under the impression that image sizes
                        were to be stored in Sedona units(1000/inch) for 1)Sedona's
                        convenience and 2)country independence.  Well, they're actually
                        passing around inches(at least that's what I've determined
                        from snooping in their code).  I have made the necessary
                        adjustments here for now, but is this really the way we want
                        to go????
        LAA  26-May-89  Started changing this module to use FlexStor rather
                        than keeping its records on the heap.  This will be
                        done in stages; today's stage takes on the TitleBlock
                        and Palette records.  Also moved initialization of
                        these records to TLStart, trading off the permanent
                        existance of the data records for a smaller root.
        LAA  31-May-89  Created a new record type, the Config record, and
                        moved some fields from the Setup record to there.  
                        This record will be kept in the Config file, and
                        represents user preferences rather than information
                        about a specific device.
        LAA  01-Jun-89  Changed DefaultFontSpec to 12 and 24 points.
        LAA  08-Jun-89  Renamed the PrimPageX & Y and PlotAreaX & Y as Tall
                        and Wide since they will reflect sometimes X and 
                        sometimes Y depending on rotation.
        LAA  10-Jun-89  Added the PaletteTree arrays to support a scrolling 
                        list of palettes, one for each chart type.  The 
                        DefaultPalette is used by all.  Also added a Palette
                        field to the Gantt, Pert and Tree records.
        LAA  14-Jun-89  Added two spare palette trees for future use.
                        Removed procedures which dealt with 
                        TLGSColorAssignments, because they're now accessible
                        from the Gantt and Pert records.
        LAA  22-Jun-89  Put two new fields in the SetupRecord to keep around
                        the plottable area of a page, because we have to swap
                        the existing fields for Sedona if Rotate is TRUE.
        WKH  25-Jul-89  Changed default Gantt Chart time unit to Weeks.
        LAA  12-Sep-89  Removed the imports of Holder, as they are no longer
                        needed.
        RSC  22-Sep-89  Removed GraphSupport, which was in the root, and
                        this also pulls out ParseReal.
        LAA  01-Dec-89  'twas the night before code-freeze, and all through
                        the house, not a damn thing was working, not even 
                        DOS!  And I just returned from enjoying my perks, to
                        find that having a DefaultPalette shared between Gantt 
                        and PERT palettes just doesn't work!  
                        Even the identical color items are not mapped to the 
                        same element of the array.  So I've changed the 
                        DefaultPalette to be an array.
*)


FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  LockObject, ReleaseObject,
                                CreateExtObjectWithSize;

FROM LStrings               IMPORT
    (* PROC *)                  SetLengthOf, TStringToLString, Fill;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, Available, HeapAvailable;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree;

FROM TypoGraph              IMPORT
    (* TYPE *)                  ATypoSpec, ATypoAttribute,
                                ASetOfTypoAttributes;





VAR
    CurrentTLGSPertRecordPtr        : ATLGSPertRecordPtr;
    CurrentTLGSGanttRecordPtr       : ATLGSGanttRecordPtr;
    CurrentTLGSPageRecordPtr        : ATLGSPageRecordPtr;
    CurrentTLGSSetupRecordPtr       : ATLGSSetupRecordPtr;
    CurrentTLGSConfigRecordPtr      : ATLGSConfigRecordPtr;
    CurrentTLGSTreeRecordPtr        : ATLGSTreeRecordPtr;
    CurrentTLGSTitleBlockPtr        : ARRAY ATLGSChartType OF AnExtHandle;
    DefaultFontSpec                 : ATypoSpec;
    ChartType                       : ATLGSChartType;




    (*  GetDefaultFontSpecs --

            Retrieves specs of the default font.

        Preconditions:
            None

        Postconditions:
            Default font info is returned, presently this info is hard coded

    *)
PROCEDURE GetDefaultFontSpecs(VAR FontSpec : ATypoSpec);

BEGIN

    FontSpec := DefaultFontSpec;

END GetDefaultFontSpecs;




(* *************************** PERT SECTION ********************** *)



(* TLGS Pert Record - Return the TLGSPertRecord pointer.

    Preconditions
                    None.

    Postconditions
                    If the record exists, a pointer is returned to it.
                    Otherwise, the record is created and a pointer is
                    returned to the newly initialized record.

                    If the pointer comes back as NIL, there was not
                    enough memory to allocate the record.
*)
PROCEDURE TLGSPertRecord()       : ATLGSPertRecordPtr;

BEGIN

    IF ((CurrentTLGSPertRecordPtr = NIL) AND (HeapAvailable())) THEN
        NEW(CurrentTLGSPertRecordPtr);
    (*
        WITH CurrentTLGSPertRecordPtr^ DO
            Tag                       := TlgsPertTagNumber;
            ID                        := 0;
            Compressed                := FALSE;
            Group                     := SDays;
            TaskBoxStyle              := Thin;
            TaskBoxCorners            := Square;
            TaskBoxShadows            := FALSE;
            DependLineStyle           := Thin;
            DependLineCorners         := Square;
            DependLineShadows         := FALSE;
            PeriodicPert              := FALSE;
            TaskArrangement           := Actual;

            GetDefaultFontSpecs(DefaultSpec);
            SetLengthOf (Name, 0);
            SetLengthOf (Layout, 0);
            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;
    *)
    END;

    RETURN CurrentTLGSPertRecordPtr;

END TLGSPertRecord;





(* TLGSPertRecordExists - Does the TLGS Pert Record exist?

    This is intended for use only by "schedule save", as TLGSPertRecord
    will create the record if need be.

    Preconditions
                    None.

    Postconditions
                    If the record exists, TRUE is returned.
                    Otherwise, FALSE is returned.
*)
PROCEDURE TLGSPertRecordExists() : BOOLEAN;

BEGIN

    RETURN (CurrentTLGSPertRecordPtr <> NIL);
           
END TLGSPertRecordExists;






(* **************************** GANTT SECTION ****************** *)





(* TLGS Gantt Record - Return the TLGSGanttRecord pointer.

    Preconditions
                    None.

    Postconditions
                    If the record exists, a pointer is returned to it.
                    Otherwise, the record is created and a pointer is
                    returned to the newly initialized record.

                    If the pointer comes back as NIL, there was not
                    enough memory to allocate the record.
*)
PROCEDURE TLGSGanttRecord( HoursMinChars : REAL )  : ATLGSGanttRecordPtr;

BEGIN

    IF ((CurrentTLGSGanttRecordPtr = NIL) AND (HeapAvailable())) THEN
        NEW(CurrentTLGSGanttRecordPtr);
    (*
        WITH CurrentTLGSGanttRecordPtr^ DO
            Tag                       := TlgsGanttTagNumber;
            ID                        := 0;
            Group                     := SWeeks;  (* 25-Jul-89 WKH *)
            TimeScale                 := HoursMinChars;
            HorizGrid                 := FALSE;
            VertGrid                  := FALSE;
            ExtraSpacing              := FALSE;
            IndentLevel               := 1;

            GetDefaultFontSpecs(DefaultSpec);
            Leading := DefaultSpec.Leading;  (* 5/22/89 WKH temporary, should remove this field, redundant *)
            SetLengthOf(Name, 0);
            SetLengthOf(Layout, 0);
            GridStyle  := Thin; 
            Corners    := Square; 

            WITH Label1 DO
                ColumnID := 0;
                Width    := 0;
                Position := SLeft;
            END;

            Label2 := Label1;
            Label3 := Label1;
            Label4 := Label1;

            Symbology  := Piston;
            SetLengthOf(Starting, 0);
            StartDate  := 0;
            SetLengthOf(Ending, 0);
            EndDate    := 0;
            ShowActuals := FALSE; 

            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;
    *)
    END;

    RETURN CurrentTLGSGanttRecordPtr;

END TLGSGanttRecord;





(* TLGSGanttRecordExists - Does the TLGS Gantt Record exist?

    This is intended for use only by "schedule save", as TLGSGanttRecord
    will create the record if need be.

    Preconditions
                    None.

    Postconditions
                    If the record exists, TRUE is returned.
                    Otherwise, FALSE is returned.
*)
PROCEDURE TLGSGanttRecordExists() : BOOLEAN;

BEGIN

    RETURN (CurrentTLGSGanttRecordPtr <> NIL);
           
END TLGSGanttRecordExists;



(* ************************ TLGS PAGE SECTION ******************** *)






(* TLGS Page Record - Return the TLGSPageRecord pointer.

    Preconditions
                    None.

    Postconditions
                    If the record exists, a pointer is returned to it.
                    Otherwise, the record is created and a pointer is
                    returned to the newly initialized record.

                    If the pointer comes back as NIL, there was not
                    enough memory to allocate the record.
*)
PROCEDURE TLGSPageRecord()       : ATLGSPageRecordPtr;

BEGIN
    IF ((CurrentTLGSPageRecordPtr = NIL) AND (HeapAvailable())) THEN
        NEW(CurrentTLGSPageRecordPtr);
    (*
        WITH CurrentTLGSPageRecordPtr^ DO
            (* Initialize Defaults *)
            ImageXVirtual    := 11.;
            ImageYVirtual    := 8.5;
            Border1XVirtual  := 1.0;
            Border2XVirtual  := 1.0;
            Border1YVirtual  := 1.0;
            Border2YVirtual  := 0.1;
            Scale            := 1.0;
            On1Page          := FALSE;
            Borders          := FALSE;
            GraphStyle       := DraftQ;
            Preview          := TRUE;
            Rotated          := FALSE;
            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;
    *)
    END;

    RETURN CurrentTLGSPageRecordPtr;

END TLGSPageRecord;






(* TLGSPageRecordExists - Does the TLGS Page Record exist?

    This is intended for use only by "schedule save", as TLGSPageRecord
    will create the record if need be.

    Preconditions
                    None.

    Postconditions
                    If the record exists, TRUE is returned.
                    Otherwise, FALSE is returned.
*)
PROCEDURE TLGSPageRecordExists() : BOOLEAN;

BEGIN

    RETURN (CurrentTLGSPageRecordPtr <> NIL);
           
END TLGSPageRecordExists;



(* ************************ TLGS SETUP SECTION ******************** *)








(* TLGS Setup Record - Return the TLGSSetupRecord pointer.

    Preconditions
                    None.

    Postconditions
                    If the record exists, a pointer is returned to it.
                    Otherwise, the record is created and a pointer is
                    returned to the newly initialized record.

                    If the pointer comes back as NIL, there was not
                    enough memory to allocate the record.
*)
PROCEDURE TLGSSetupRecord()  : ATLGSSetupRecordPtr;

BEGIN

    IF ((CurrentTLGSSetupRecordPtr = NIL) AND (HeapAvailable())) THEN
        NEW(CurrentTLGSSetupRecordPtr);
        WITH CurrentTLGSSetupRecordPtr^ DO
            (* Initialize Defaults *)
            PhysPageWide    := 8500.0;
            PhysPageHigh    := 11000.0;
            PlotAreaWide    := 8000.0;                            (* 09-May-89 LAA *)
            PlotAreaHigh    := 10000.0;
            Orientation     := Portrait;
            AskContinuous   := FALSE;
            ContinuousPrint := FALSE;
            DeviceDescription := AText(NIL);
            PrimColorDesc   := AText(NIL);
            OrigPlotAreaWide:= 8000.0;                            (* 22-Jun-89 LAA *)
            OrigPlotAreaHigh:= 10000.0;
            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;
    END;

    RETURN CurrentTLGSSetupRecordPtr;

END TLGSSetupRecord;










(* TLGSSetupRecordExists - Does the TLGS Setup Record exist?

    This is intended for use only by "schedule save", as TLGSSetupRecord
    will create the record if need be.

    Preconditions
                    None.

    Postconditions
                    If the record exists, TRUE is returned.
                    Otherwise, FALSE is returned.
*)
PROCEDURE TLGSSetupRecordExists() : BOOLEAN;

BEGIN

    RETURN (CurrentTLGSSetupRecordPtr <> NIL);
           
END TLGSSetupRecordExists;





(* ************************ TLGS CONFIG SECTION ******************** *)



(* TLGS Config Record - Return the TLGSConfigRecord pointer.

    Preconditions
                    None.

    Postconditions
                    If the record exists, a pointer is returned to it.
                    Otherwise, the record is created and a pointer is
                    returned to the newly initialized record.

                    If the pointer comes back as NIL, there was not
                    enough memory to allocate the record.
*)
PROCEDURE TLGSConfigRecord()  : ATLGSConfigRecordPtr;

BEGIN                       (* TLGSConfigRecord *)

    IF ((CurrentTLGSConfigRecordPtr = NIL) AND (HeapAvailable())) THEN
        NEW(CurrentTLGSConfigRecordPtr);
        WITH CurrentTLGSConfigRecordPtr^ DO
            ConfigDescription := AText(NIL);
            OutputToFile      := FALSE;
            Units             := Inches;
        END;
    END;

    RETURN CurrentTLGSConfigRecordPtr;

END TLGSConfigRecord;






(* TLGSConfigRecordExists - Does the TLGS Config Record exist?

    This is intended for use only by "schedule save", as TLGSConfigRecord
    will create the record if need be.

    Preconditions
                    None.

    Postconditions
                    If the record exists, TRUE is returned.
                    Otherwise, FALSE is returned.
*)
PROCEDURE TLGSConfigRecordExists() : BOOLEAN;

BEGIN                       (* TLGSConfigRecordExists *)

    RETURN (CurrentTLGSConfigRecordPtr <> NIL);

END TLGSConfigRecordExists;








(* ****************** TLGS TREE SECTION ************************ *)





(* TLGS Tree Record - Return the TLGSTreeRecord pointer.

    Preconditions
                    None.

    Postconditions
                    If the record exists, a pointer is returned to it.
                    Otherwise, the record is created and a pointer is
                    returned to the newly initialized record.

                    If the pointer comes back as NIL, there was not
                    enough memory to allocate the record.
*)
PROCEDURE TLGSTreeRecord()  : ATLGSTreeRecordPtr;

BEGIN
    IF ((CurrentTLGSTreeRecordPtr = NIL) AND (HeapAvailable())) THEN
        NEW(CurrentTLGSTreeRecordPtr);
    (*
        WITH CurrentTLGSTreeRecordPtr^ DO
            Tag                       := TLGSTreeTagNumber;
            ID                        := 0;
            Shadows                   := FALSE;
            Orientation               := Tall;
            GridStyle                 := Thin;   (* 3/22/89 WKH *)
            Corners                   := Square; (* 3/22/89 WKH *)

            GetDefaultFontSpecs(DefaultSpec);
            Leading := DefaultSpec.Leading;  (* 5/22/89 WKH temporary, should remove this field, redundant *)
            SetLengthOf (Name, 0);
            SetLengthOf (Layout, 0);
            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;
    *)
    END;

    RETURN CurrentTLGSTreeRecordPtr;

END TLGSTreeRecord;






(* TLGSTreeRecordExists - Does the TLGS Tree Record exist?

    This is intended for use only by "schedule save", as TLGSTreeRecord
    will create the record if need be.

    Preconditions
                    None.

    Postconditions
                    If the record exists, TRUE is returned.
                    Otherwise, FALSE is returned.
*)
PROCEDURE TLGSTreeRecordExists() : BOOLEAN;

BEGIN

    RETURN (CurrentTLGSTreeRecordPtr <> NIL);
           
END TLGSTreeRecordExists;






(* ***************** TLGS TITLE SECTION ********************* *)

VAR
    TLGSTitleBlockName  : ARRAY ATLGSChartType OF ARRAY [0..9] OF CHAR; 





(* LockTLGSTitleBlockRecord - Return the TLGSTitleBlock pointer.

    Preconditions
                    None.

    Postconditions
                    If the record exists, it is locked and a pointer is 
                    returned to it. Otherwise, the record is created and 
                    locked, and a pointer is returned to the newly 
                    initialized record.

                    If the pointer comes back as NIL, there was not
                    enough memory to allocate the record.
*)

PROCEDURE LockTLGSTitleBlock( TitleClient : ATLGSChartType ) : ATLGSTitleBlockPtr; 

VAR
    i                       : CARDINAL;
    TitleBlock              : ATLGSTitleBlockPtr;
    ok                      : BOOLEAN;

BEGIN

(*$O-*)
    TitleBlock := NIL;
    ok := TRUE;

    IF (CurrentTLGSTitleBlockPtr[TitleClient] = AnExtHandle(NIL)) THEN    (* 26-May-89 LAA *)
        ok := CreateExtObjectWithSize(CurrentTLGSTitleBlockPtr[TitleClient],
                                      ExtSlow, TSIZE(ATLGSTitleBlock));
    END;

    IF (ok) THEN
        i := LockObject(CurrentTLGSTitleBlockPtr[TitleClient], TitleBlock);
        IF (i <> TSIZE(ATLGSTitleBlock)) THEN
            FatalError();
        END;
    END;

    RETURN TitleBlock;

    (*
        WITH CurrentTLGSTitleBlockPtr[TitleClient]^ DO
            ExistTitle                := FALSE;
            TitlePlace                := SUpLeft;
            TitleBorder.LineWidth     := GetDefaultBorder();
            TitleBorder.CornerRadius  := 0;
            ExistLegend               := FALSE;
            LegendPlace               := SUpLeft;
            LegendBorder.LineWidth    := GetDefaultBorder();
            LegendBorder.CornerRadius := 0;
            ExistSymbol               := FALSE;
            SymbolPlace               := SUpLeft;
            SymbolBorder.LineWidth    := GetDefaultBorder();
            SymbolBorder.CornerRadius := 0;

            FOR i := 1 TO HIGH(Title) DO
                SetLengthOf(Title[i].LineOfText, 0);
                GetDefaultFontSpecs(Title[i].TextSpec);
            END;

            FOR i := 1 TO HIGH(Legend) DO
                SetLengthOf(Legend[i].LineOfText, 0);
                GetDefaultFontSpecs(Legend[i].TextSpec);
            END;           
        END;
    *)

(*$O=*)

END LockTLGSTitleBlock;





(*  UnlockTLGSTitleBlockRecord --

    Unlock a previously locked Title Block record.

    Preconditions:
        The indicated TitleBlockRecord must have been previously locked, and
        not yet unlocked.

    Postconditions:
        The lock on the TitltBlockRecord will be released.  Any pointer to 
        that record should be considered invalid after this call is made.
*)

PROCEDURE UnlockTLGSTitleBlock( TitleClient : ATLGSChartType);

BEGIN                       (* UnlockTLGSTitleBlock *)

    ReleaseObject(CurrentTLGSTitleBlockPtr[TitleClient]);

END UnlockTLGSTitleBlock;





(* TLGSTitleBlockExists - Does the TLGS Plot Record exist?

    This is intended for use only by "schedule save", as TLGSTitleBlock
    will create the record if need be.

    Preconditions
                    None.

    Postconditions
                    If the record exists, TRUE is returned.
                    Otherwise, FALSE is returned.
*)
PROCEDURE TLGSTitleBlockExists( TitleClient : ATLGSChartType ) : BOOLEAN; 

BEGIN

    RETURN (CurrentTLGSTitleBlockPtr[TitleClient] <> AnExtHandle(NIL));  (* 26-May-89 LAA *)
           
END TLGSTitleBlockExists;






BEGIN
    CurrentTLGSPertRecordPtr                      := NIL; 
    CurrentTLGSGanttRecordPtr                     := NIL; 
    CurrentTLGSPageRecordPtr                      := NIL; 
    CurrentTLGSSetupRecordPtr                     := NIL; 
    CurrentTLGSTreeRecordPtr                      := NIL; 
    CurrentTLGSConfigRecordPtr                    := NIL;                (* 31-May-89 LAA *)

    FOR ChartType := TLGSGanttChart TO TLGSTreeChart DO           (* 10-Jun-89 LAA *)
        CurrentTLGSTitleBlockPtr[ChartType]      := AnExtHandle(NIL);   (* 26-May-89 LAA *)
        PaletteTree[ChartType] := ATree(NIL);
        DefaultPalette[ChartType] := ATreeNode(NIL);              (* 01-Dec-89 LAA *)
    END;

    SparePaletteTree1 := ATree(NIL);                              (* 14-Jun-89 LAA *)
    SparePaletteTree2 := ATree(NIL);

    WITH DefaultFontSpec DO    (* 4/26/89 WKH *)
        PointSize     := 192;
        Leading       := 384;  (* 5/22/89 WKH *)
        FontFamily    := 1;
        FontMember    := 1;
        Aspect        := 1.2;
        MinPointSize  := 6;
        CompAndWeight := 0;
        ForeColor     := 0;
        BackColor     := 0;
        AttrColor     := 0;
        Attributes    := ASetOfTypoAttributes{};
    END;

END IlsaStatic.

