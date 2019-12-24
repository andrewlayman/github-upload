IMPLEMENTATION MODULE PrintStatic;
    (* MODIFICATION HISTORY:

        Apr 19, 1989    KKC - Init NNotesPrintLines to 2
                              Set ReportHeaderTextIn to NIL;
                              Set ReportHeaderTextGen to NIL;
                              Set ReportActiveFilters to TRUE;

        May 4, 1989     KKC - Delete ReportHeaderTextGen and move it to
                              PrintCaption.mod.
        Aug 3, 1989     MWP - Remove initialization of OutputDeviceName.
        Sep 7, 1989     MWP - Set OutputDiskName to zero len.
        Sep 11, 1989    AJL - Initialize the control block in case any diagnostic tracing
                              modules use it before TLStart.
        27-Sep-89   MWP/KKC - Store the Timeout so print routines can actually
                              use it.

    *)
FROM Text                   IMPORT
    (* TYPE *)                  AText;

VAR
    i                       :   CARDINAL;
    ControlStyle            :   AControlStyle;



BEGIN
    PrintDiskFileName[0] := 0C;
    TranslateOverlay[0]  := 0C;
    OutputDeviceName[0] := 0C;
    OutputDiskName[0] := 0C;

    NNotesPrintLines := 2;
    i := 0;
    WHILE (i <= HIGH(ReportSettings)) DO
        ReportSettings[i] := 0;
        INC(i);
    END;
    ReportHeaderTextIn := AText(NIL);
    ReportActiveFilters  := TRUE;

        (* Initialize the control block in case any diagnostic tracing
           programs use it before TLStart. *)

    WITH PrintCB DO
        Style := OutToScreen;
        ControlStyle := PrinterNormal;
        PortType := PortParallel;
        PrinterNumber := 0;
    END;

    FOR ControlStyle := MIN(AControlStyle) TO MAX(AControlStyle) DO
        WITH PrintCB.ControlStrings[ControlStyle] DO
            NewPage[0] := 0C;
            NewLine[0] := 1C;   NewLine[1] := 15C;
            Normal[0] := 0C;
            Bold[0] := 0C;
            TopMargin := 1;
            LeftMargin := 1;
            BottomMargin := 60;
            RightMargin := 79;
            Init := AText(NIL);
            Terminate := AText(NIL);
        END;
    END;

    GlobalTimeOut   := 12000;                                     (* 27-Sep-89 MWP/KKC *)

END PrintStatic.
