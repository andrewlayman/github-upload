IMPLEMENTATION MODULE GrafLoad;

 (* MODIFICATION HISTORY:

     RSC 9-Sep-87 SPIKE upgrade.

 *)


    FROM FileSystem   IMPORT  File, Response;

    FROM FileAux      IMPORT  CheckIO;

    FROM RecordIO     IMPORT  ReadRecord, ReadString, ReadRecordPreface,
                              ReadRecordBody, ReadStringBody;

    FROM Subfiles     IMPORT  StartFileInput, StartSubfileInput;

    FROM LoadCommon   IMPORT  SkipRecordBody;

    FROM PlotStatic   IMPORT  GanttPlotRecord, NetPlotRecord,
                              PlotterRecord,
                              APlotType, PlotType, ALabelType, AGanttLabelType;

    FROM ReadAscii    IMPORT  ReadBoolean, ReadCardinal, ReadReal,
                              ReadTimeUnit, ReadDate;

    FROM Timeu        IMPORT  ATimeUnit;

    FROM SYSTEM       IMPORT  ADR, SIZE;


CONST
     ProjectType           = 1;
     EnvironmentType       = 2;
     PrintFileType         = 3;
     SummaryType           = 4;
     ResourceType          = 5;
     TaskType              = 6;
     EdgeType              = 8;
     CalendarType          = 9;
     BugsType              = 10;
     SignatureType         = 11;
     PrinterTableType      = 12;
     FileNamesType         = 13;
     VideoType             = 14;
     PreferencesType       = 15;
     CodeSetsType          = 16;
     FontsType             = 17;
     PlotsType             = 18;
     FiltersType           = 19;
     HeldItemsType         = 20;





PROCEDURE ReadLinesIndex( VAR F: File;
                              Length : CARDINAL;
                          VAR Yes : BOOLEAN;
                          VAR Period : ATimeUnit );
VAR
    C : CHAR;
BEGIN
    ReadRecordBody(F,Length,ADR(C),SIZE(C));
    Yes := TRUE;
    Period := Days;
    CASE C OF
        "m"     :  Period := Minutes;
      | "H"     :  Period := Hours;
      | "D"     :  Period := Days;
      | "W"     :  Period := Weeks;
      | "M"     :  Period := Months;
      | "Y"     :  Period := Years;
      ELSE
          Yes := FALSE;
    END;
END ReadLinesIndex;










PROCEDURE GetGraphDetails(VAR f:File);
VAR
    Version : CARDINAL;
    Type,
    Length  : CARDINAL;
    N                  : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput(f,PlotsType,Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
            101:  ReadTimeUnit(f,Length,NetPlotRecord.HorizPeriod);
          | 102:  ReadReal(f,Length,NetPlotRecord.PeriodsPerInch);
          | 103:  ReadCardinal(f,Length,NetPlotRecord.ActivityPen);
          | 108:  ReadCardinal(f,Length,NetPlotRecord.MilestonePen);
 (* ***** | 109:  ReadCardinal(f,Length,NetPlotRecord.HighlightPen); RSC 9/2/87 *)
          | 110:  ReadCardinal(f,Length,NetPlotRecord.LinkPen);
          | 111:  ReadLinesIndex(f,Length,NetPlotRecord.MajorLineYes,
                                 NetPlotRecord.MajorLinePeriod);
          | 112:  ReadLinesIndex(f,Length,NetPlotRecord.MinorLineYes,
                                 NetPlotRecord.MinorLinePeriod);
          | 121:  ReadBoolean(f,Length,NetPlotRecord.TaskNames);
          | 122:  ReadCardinal(f,Length,N);
                  NetPlotRecord.LowerLeftLabel := VAL(ALabelType,N);
          | 123:  ReadCardinal(f,Length,N);
                  NetPlotRecord.LowerRightLabel := VAL(ALabelType,N);
          | 124:  ReadCardinal(f,Length,NetPlotRecord.DependencyCriterion);
          | 130:  ReadCardinal(f,Length,NetPlotRecord.MajorLinePen);
          | 131:  ReadCardinal(f,Length,NetPlotRecord.MinorLinePen);

          | 201:  ReadTimeUnit(f,Length,GanttPlotRecord.HorizPeriod);
          | 202:  ReadReal(f,Length,GanttPlotRecord.PeriodsPerInch);
          | 203:  ReadCardinal(f,Length,GanttPlotRecord.ActivityPen);
(* ****** | 204:  ReadCardinal(f,Length,GanttPlotRecord.HighlightPen); RSC 9/2/87 *)
          | 205:  ReadCardinal(f,Length,GanttPlotRecord.MilestonePen);
          | 206:  ReadBoolean(f,Length,GanttPlotRecord.TotalFloat);
          | 207:  ReadBoolean(f,Length,GanttPlotRecord.Descr);
          | 208:  ReadBoolean(f,Length,GanttPlotRecord.VisSpace);
          | 213:  ReadBoolean(f,Length,GanttPlotRecord.DurColumn);
          | 214:  ReadBoolean(f,Length,GanttPlotRecord.ESColumn);
          | 215:  ReadBoolean(f,Length,GanttPlotRecord.EFColumn);
          | 216:  ReadBoolean(f,Length,GanttPlotRecord.LSColumn);
          | 217:  ReadBoolean(f,Length,GanttPlotRecord.LFColumn);
          | 218:  ReadBoolean(f,Length,GanttPlotRecord.FFColumn);
          | 219:  ReadBoolean(f,Length,GanttPlotRecord.TFColumn);
          | 220:  ReadLinesIndex(f,Length,GanttPlotRecord.MajorLineYes,
                                 GanttPlotRecord.MajorLinePeriod);
          | 221:  ReadLinesIndex(f,Length,GanttPlotRecord.MinorLineYes,
                                 GanttPlotRecord.MinorLinePeriod);
          | 222:  ReadCardinal(f,Length,N);
                  GanttPlotRecord.AdditionalLabel := VAL(AGanttLabelType,N);
          | 226:  ReadBoolean(f,Length,GanttPlotRecord.StatusColumn);
          | 230:  ReadCardinal(f,Length,GanttPlotRecord.MajorLinePen);
          | 231:  ReadCardinal(f,Length,GanttPlotRecord.MinorLinePen);

         | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

END GetGraphDetails;



 (* MOved here from TLStart and TLiTl3  11/16/87 RSC *)

PROCEDURE GetPlotterDetails(VAR f:File);
VAR
    Version,
    Type,
    Length,
    N        : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput(f,PlotsType,Version)) THEN
        RETURN;
    END;

    (* RSC 11/6/87 : I added types 7, 10, and 100 *)

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        WITH PlotterRecord DO
            CASE Type OF
                1  :  ReadStringBody(f,Length,EquivalentTo);
              | 2  :  ReadBoolean(f,Length,DeleteAfterPlot);
              | 3  :  ReadCardinal(f,Length,NumberOfCopies);
              | 4  :  ReadStringBody(f,Length,Name);
              | 5  :  ReadBoolean(f,Length,SolidBars);
              | 6  :  ReadBoolean(f,Length,SolidBarsAllowed);
              | 7  :  ReadBoolean(f,Length,ReducedBar);
              | 8  :  ReadCardinal(f,Length,BarSpacing);
              | 10 :  ReadBoolean(f,Length,PortraitOrientation);
              | 11 :  ReadRecordBody(f,Length,ADR(PaperSize),SIZE(PaperSize));
              | 12 :  ReadCardinal(f,Length,PenSpeed);

      (* RSC 9/2/87: *)

              | 13 :  ReadBoolean(f,Length,IncreasingSpeed);
              | 14 :  ReadCardinal(f,Length,NumberOfPens);
              | 24 :  ReadBoolean(f,Length,DrawBordersFlag);

              | 31..35 
                   :  ReadCardinal(f,Length,HighlightPenNums[Type - 30]);

              | 51 :  ReadCardinal(f,Length,BorderPen);
              | 100:  ReadBoolean(f,Length,CascadeNetwork);

             | 0FFH : EXIT;
              ELSE    SkipRecordBody(f,Length);
            END;
        END;
    END;

END GetPlotterDetails;








END GrafLoad.
