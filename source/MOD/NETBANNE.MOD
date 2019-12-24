IMPLEMENTATION MODULE NetBanners;
    
    (*  MODIFICATION HISTORY
        24-Jun-88 CMH   Removed import of unused InitSnetMatrix and
                        ChildrenCruncher.
        13-Jul-89 CMH   Improved display of new Pert/Tree view
                        status lines to steal procedure vector instead of
                        blanking Gantt view first and displaying Pert/Tree
                        view banner next.
        14-Jul-89 CMH   Fixed status banner formatting bug.
        18-Jul-89 CMH   Eliminated plus signs from task names of closed
                        summaries.
        24-Jul-89 EGK   Removed import of DrawMasterTaskExtension.
         4-Aug-89 CMH   More plus sign changes.
         8-Aug-89 CMH   Added import of TrimFront.
         6-Sep-89 EGK   In DisplayBanner, extend the string with Procustes
                        instead of SetLengthOf, to make sure that we don't
                        show leftover characters from the leftmost field.
         8-Sep-89 CMH   Removed MasterTaskWidth variable;
        14-Sep-89 EGK   Treat unknown columns (i.e., those that return a
                        null string for the column name, such as the
                        extinct "sequence number" column) as if their
                        column ID was zero.  That way, the banner won't try
                        to reserve space to display them.
        21-Sep-89 LAA   Removed all reference to Animation.
        15-Dec-89 EGK   Removed reference to ULYMAX.
        05-Feb-90 EGK   Removed unused imports from NetCharacters.
     *)
     
FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,
                                ATaskFilter, ATaskFilterSet;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* PROC *)                  GetColumnInfo, GetColumnString;
    
FROM Chart                  IMPORT
    (* VAR *)                   BugTaskA, BugTaskB, GanttChart, CursorTask;

FROM ChartControl           IMPORT
    (* TYPE *)                 AChartState, AChartStateSet,
    (* PROC *)                 UnSetState;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Burp, Error, Message, MultipleChoiceBox;

FROM Gantt                  IMPORT
    (* TYPE *)                  AGanttLineType;

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineSpecificChange,
                                ValidateGanttOutline,
                                AGanttOutlineStatus,
                                AGanttOutlineStatusSet,
                                AGanttOutlineShowing;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode,
    (* CONST *)                 maxcol, 
    (* PROC *)                  EraseLn, FlushKeyboardBuffer, KeyPress,
                                PutString;

FROM Layout                 IMPORT 
                                GanttWStart, GanttWEnd, MenuStart, MenuEnd;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Search, SetLengthOf, SetString, CtoS,
                                Procustes, ConcatLS, ConcatS, Copy, Insert,
                                LJust, TrimRear, TrimFront, Overlay, LengthOf;

FROM NetCharacters          IMPORT
    (* CONST *)                 blank, VBar1;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NormalLayoutActive, GetNormalNetLayout,
    (* PROC *)                  DisplayNetworkLight, GetBigNetLayout;

FROM NetStatic              IMPORT
                                SnetRowOne,    SnetColOne;
                                
FROM NetUtility             IMPORT
    (* CONST *)                 ToScreen, ToPrinter,
                                NormalLayout,  EnlargedLayout,
                                MasterTaskHeight,
                                ULX, ULY, SeperatorLine, 
    (* VAR *)                   SnetChars,
                                BoxLayout, 
                                CharWidth, CharHeight,
                                BoxWidth, BoxHeight,
                                SnetRowMin,    SnetRowMax,
                                SnetColMin,    SnetColMax,
                                ExpandedSnetHeight, ExpandedSnetWidth,
    (* PROC *)                  GetBoxSize,  
                                GetHorizMin, GetVertMin, 
                                GetHorizMax, GetVertMax, 
                                GetPad, (* DrawMasterTaskExtension, *)
                                ISnetChars, InitSnetHandW,
                                SetFilterVideoModes,
                                MasterTaskCheck;
                                
FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode,
    (* PROC *)                  ValidateTreeNode;



(*--------------------------------------------------------------------------*)
        (*  
            ClearBanner
            
            Clears the three message lines above the network
            drawing area.
         *)


PROCEDURE ClearBanner();

BEGIN

   EraseLn(GanttWStart-1);
   EraseLn(GanttWStart-2);
   EraseLn(GanttWStart-3);

END ClearBanner;


(*--------------------------------------------------------------------------*)
        (*          
            ClearMessage
            
            Clear top line first time.
        *)

PROCEDURE ClearMessage();

VAR
   s : ARRAY[0..81] OF CHAR;

BEGIN    

    Fill(s,blank,80);
    Message(s);

END ClearMessage;


(*--------------------------------------------------------------------------*)
        (*
            DisplayBanner 
            
            Updates the three message lines above the network
            drawing area with cursor task information.
         *)


PROCEDURE DisplayBanner();        

CONST
    LayoutRows = 3;
    MaxFieldWidth = 80;
    BannerMidPoint = 39;
    
VAR
    i,
    index,
    MaxLeftValue,
    MaxRightValue,
    MaxLeftTitle,
    MaxRightTitle,
    LinesOfData : CARDINAL;
    layout      : ANetworkLayout;
    task        : ATaskPtr;
    TempReal    : REAL;
    DataRecord  : AColumnDataRecord;
    Found       : BOOLEAN;
    PlusSign,
    s,
    TempString  : ARRAY [0..255] OF CHAR;
    
BEGIN

    SetString(PlusSign,"+");
    
 (* set the cursor task *)  
    GanttChart^.Methods^.SetCursorNode(GanttChart,CursorTask);
    
 (* determine layout and get the layout pointer *)
    IF (BoxLayout=NormalLayout) THEN
        layout:=GetNormalNetLayout();
    ELSE
        layout:=GetBigNetLayout();
    END;
    
    LinesOfData:= 3;

    FOR i:= 1 TO LayoutRows DO
    
     (* get title width *)
        FormatBanner(i,MaxLeftTitle,MaxRightTitle);
        MaxLeftValue:= 0;
        MaxRightValue:= 0;
        IF (MaxLeftTitle > 0) AND (MaxRightTitle > 0) THEN
            MaxLeftValue:= (BannerMidPoint) - MaxLeftTitle;
            MaxRightValue:= (BannerMidPoint) - MaxRightTitle;
        ELSIF (MaxLeftTitle = 0) THEN
            MaxRightValue:= maxcol - MaxRightTitle;
        ELSE (* MaxRightTitle = 0 *)
            MaxLeftValue:= maxcol - MaxLeftTitle;
        END;   
    
     (* clear the output string *)   
        Fill(s,blank,maxcol+1);
        SetLengthOf(s,0);
     

        task := CursorTask^.Methods^.LockFlexStorDataObject(CursorTask);
        
        IF (layout^.Fields[i].ColumnID > 0) THEN
         (* left title *)  
            GetColumnInfo(CursorTask, task,
                          layout^.Fields[i].ColumnID,
                          ColumnName,
                          MaxLeftTitle,
                          DataRecord);
            Copy(DataRecord.StringValue, TempString);
            LJust(TempString);
            TrimRear(TempString);
            IF (LengthOf(TempString) > 0) THEN      (* 9/14/89 EGK *)
                ConcatLS(s,TempString);
                ConcatS(s,": ");
                (* left value *)
                Found := GetColumnString(CursorTask,task,
                                         layout^.Fields[i].ColumnID,
                                         Plan, 
                                         MaxFieldWidth, 
                                         TempString);
                LJust(TempString);
                index := Search(TempString,PlusSign,0);
                IF (index = 1) THEN
                    TempString[index] := blank;
                END;
                TrimFront(TempString);
                TrimRear(TempString);
                ConcatLS(s,TempString);
                SetLengthOf(s,BannerMidPoint);
            END;
        END;

     (* dividing line *)
        IF ((MaxLeftTitle > 0) AND (MaxRightTitle > 0)) THEN
             SetLengthOf(s,BannerMidPoint);
             ConcatS(s,VBar1);
        END;
        
        IF (layout^.Fields[i+LayoutRows].ColumnID > 0) THEN
         (* right title *)
            GetColumnInfo(CursorTask, task,
                          layout^.Fields[i+LayoutRows].ColumnID,
                          ColumnName,
                          MaxRightTitle,
                          DataRecord);
            Copy(DataRecord.StringValue, TempString);
            LJust(TempString);
            TrimRear(TempString);
            IF (LengthOf(TempString) > 0) THEN          (* 9/14/89 EGK *)
                ConcatLS(s,TempString);
                ConcatS(s,": ");
             (* right value *)
                Found := GetColumnString(CursorTask,task,
                                         layout^.Fields[i+LayoutRows].ColumnID,
                                         Plan, 
                                         MaxFieldWidth, 
                                         TempString);
                LJust(TempString);
                index := Search(TempString,PlusSign,0);
                IF (index = 1) THEN
                    TempString[index] := blank;
                END;
                TrimFront(TempString);
                TrimRear(TempString);
                ConcatLS(s,TempString);
            END;
        END;
    
     (* display this output line *)
        Procustes (s, maxcol+1);            (* 9/6/89 EGK *)
        PutString(s,ULX,GanttWStart-LinesOfData,videomessage);
        DEC(LinesOfData);
    
        CursorTask^.Methods^.UnlockUnchangedDataObject(CursorTask);

    END; (* for *)
    
END DisplayBanner;


(*--------------------------------------------------------------------------*)
        (*
            FormatBanner 
         *)


PROCEDURE FormatBanner(RowNumber : CARDINAL;
                   VAR MaxLeftTitle, MaxRightTitle : CARDINAL);        

CONST
    LayoutRows = 3;
    MaxFieldWidth= 80;
    
VAR
    layout     : ANetworkLayout;
    task       : ATaskPtr;
    TempReal   : REAL;
    DataRecord : AColumnDataRecord;    
    s          : ARRAY [0..255] OF CHAR;
    
BEGIN

 (* determine layout and get the layout pointer *)
    IF (BoxLayout=NormalLayout) THEN
        layout:=GetNormalNetLayout();
    ELSE
        layout:=GetBigNetLayout();
    END;

    MaxLeftTitle:= 0;
    MaxRightTitle:= 0;
    

    task := CursorTask^.Methods^.LockFlexStorDataObject(CursorTask);
        
 (* left title *)  
    IF (layout^.Fields[RowNumber].ColumnID > 0) THEN
        GetColumnInfo(CursorTask, task,
                      layout^.Fields[RowNumber].ColumnID,
                      ColumnName,
                      MaxFieldWidth,
                      DataRecord);
        Copy(DataRecord.StringValue,s);
        LJust(s);
        TrimRear(s);
        IF (LengthOf(s) > 0) THEN           (* 9/14/89 EGK *)
            MaxLeftTitle:= ORD(s[0])+2;  (* include ": " *)
        END;
    END;
      
 (* right title *)  
    IF (layout^.Fields[RowNumber+LayoutRows].ColumnID > 0) THEN
        GetColumnInfo(CursorTask, task,
                      layout^.Fields[RowNumber+LayoutRows].ColumnID,
                      ColumnName,
                      MaxFieldWidth,
                      DataRecord);
        Copy(DataRecord.StringValue,s);
        LJust(s);
        TrimRear(s);
        IF (LengthOf(s) > 0) THEN           (* 9/14/89 EGK *)
            MaxRightTitle:= ORD(s[0])+2;  (* include ": " *)
        END;
    END;
        
    CursorTask^.Methods^.UnlockUnchangedDataObject(CursorTask);

    
END FormatBanner;


(*--------------------------------------------------------------------------*)
        (*  
            NoGanttStatusBanner
            
            Dummy procedure for gantt status lines.
         *)

PROCEDURE NoGanttStatusBanner(DummyTaskTreeNode : ATreeNode);
BEGIN
END NoGanttStatusBanner;


(*--------------------------------------------------------------------------*)


BEGIN                       (* NetBanners *)


END NetBanners.
