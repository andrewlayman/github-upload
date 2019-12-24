IMPLEMENTATION MODULE PageOptn;
(*
        MODIFICATION History -

        12-Jun-89 KKC First version
        11-Aug-89 KKC - Pass Pointer instead of address.
                      - Add three blank lines between procedures.
        13-Oct-89 KKC - Restore the changes user made when he switch 
                        PageBreaks back to Yes.
        27-Nov-89 KKC - Rearrange the order of PAGEHEADINGS, PAGEFOOTINGS and 
                        COLUMNHEADINGS.
        04-Dec-89 KKC - Protect PAGEHEADINGS, PAGEFOOTINGS and COLUMNHEADINGS if
                        page break is no.
        20-Mar-91 AJL - Use a VAR parameter instead of a damn pointer.
         1-Jul-91 PFG   SetFormChange was being called whether changes were
                        made to the form or not.  Now it only gets called if
                        changes were made to this form, or if the previous
                        form was actually changed.
         9-Aug-91 PFG   Backed out my last change.  Marketing and QA nixed
                        it.
*)

FROM Codes                 IMPORT
    (* TYPE  *)                 ACode;

FROM FormCon               IMPORT
    (* TYPE  *)                 AFieldNo;

FROM Forms                 IMPORT
    (* TYPE  *)                 AFieldValue, AForm, ACheckReason,
    (* PROC  *)                 SetFieldHidden, SetFieldProtection,
                                SetFormChange, DoForm, ShowValue;

FROM Layout                IMPORT
    (* VAR   *)                 GanttWEnd;

FROM Kbio                  IMPORT
    (* CONST *)                 maxcol;

FROM Keys                  IMPORT
    (* CONST *)                 ExitKey;

FROM PageRepeat            IMPORT
    (* TYPE  *)                 APageRepeatSettingsPtr, APageRepeatSettings,
                                TitleChoices;

CONST
    ModuleNumber            =   7000;
    TLRPFORMID              =   58;

    PageRepeatFormLeft      =   11;
    PageRepeatFormRight     =   69;
    PageRepeatFormTop       =   11;
    PageRepeatFormBottom    =   18;

    PAGEBREAKS              =   0;
    ONETASKPERPAGE          =   1;
    IGNORELMARGIN           =   2;
    PAGEHEADINGS            =   3;
    PAGEFOOTINGS            =   4;
    COLUMNHEADINGS          =   5;
    UNLIMITEDWIDTH          =   6;

    LastPageRepeatFormFld   =   6;

TYPE

    ABackupPageRepeatSettings       =       RECORD
        OneTaskPerPage      :       CARDINAL;
        ColumnHeadings      :       CARDINAL;
        PageHeadings        :       CARDINAL;
        PageFootings        :       CARDINAL;
    END;


VAR
    BackupPageRepeatSettings    :   ABackupPageRepeatSettings;


(****************************************************************************
   SetPageRepeatSettingsForm -
      Set up the AssignReporrtSettings based on the value in FormValueArray.
      FormValueArray contains the information inputed from user.
****************************************************************************)
PROCEDURE SetPageRepeatSettings(
                                 VAR FormValue  : ARRAY OF AFieldValue;
                                 VAR PageRepeatSettings : APageRepeatSettings
                               );
BEGIN
    WITH PageRepeatSettings DO
        PageBreaks := (FormValue[PAGEBREAKS].CardValue <> 0);
        OneTaskRsrcPerPage := (FormValue[ONETASKPERPAGE].CardValue <> 0);
        ColumnHeadings := VAL(TitleChoices, 
                                        FormValue[COLUMNHEADINGS].CardValue);
        PageHeadings := VAL(TitleChoices, FormValue[PAGEHEADINGS].CardValue);
        PageFootings :=  VAL(TitleChoices,FormValue[PAGEFOOTINGS].CardValue);
        UnlimitedWidth := (FormValue[UNLIMITEDWIDTH].CardValue <> 0);
        IgnoreLMargin := (FormValue[IGNORELMARGIN].CardValue <> 0);
    END;
END SetPageRepeatSettings;




PROCEDURE CheckDoPageRepeatForm(          Form : AForm;
                                       FieldNo : AFieldNo;
                                 VAR FormValue : ARRAY OF AFieldValue;
                                   CheckReason : ACheckReason;
                                      VAR Code : CARDINAL
                               ) : BOOLEAN;
VAR
    PageBreakOff            :   BOOLEAN;
    i                       :   CARDINAL;
BEGIN

    Code := 0;
    CASE CheckReason OF
        | CheckFormEntry :
            CASE FieldNo OF
            | PAGEBREAKS:
                PageBreakOff := (FormValue[FieldNo].CardValue = 0 );
                SetFieldProtection(Form, ONETASKPERPAGE, FormValue, PageBreakOff);
                FOR  i := PAGEHEADINGS TO COLUMNHEADINGS DO
                    SetFieldProtection(Form, i, FormValue, PageBreakOff);
                END;
                WITH BackupPageRepeatSettings DO
                    OneTaskPerPage := FormValue[ONETASKPERPAGE].CardValue;
                    ColumnHeadings := FormValue[COLUMNHEADINGS].CardValue;
                    PageHeadings   := FormValue[PAGEHEADINGS].CardValue;
                    PageFootings   := FormValue[PAGEFOOTINGS].CardValue;
                END;
            ELSE
            END;
        | CheckFormExit :     
        | CheckFieldEntry:   ;
            CASE FieldNo OF
            | PAGEBREAKS:
                IF (FormValue[FieldNo].CardValue <> 0 ) THEN
                    WITH BackupPageRepeatSettings DO
                        OneTaskPerPage := FormValue[ONETASKPERPAGE].CardValue;
                        ColumnHeadings := FormValue[COLUMNHEADINGS].CardValue;
                        PageHeadings   := FormValue[PAGEHEADINGS].CardValue;
                        PageFootings   := FormValue[PAGEFOOTINGS].CardValue;
                    END;
                END;
            ELSE
            END;
        | CheckFieldChange:   ;
            SetFormChange(Form);        (* 1-Jul-91 PFG *)
            CASE FieldNo OF
            | PAGEBREAKS:
                PageBreakOff := (FormValue[FieldNo].CardValue = 0 );
                FormValue[ONETASKPERPAGE].CardValue := 
                                                 FormValue[FieldNo].CardValue;
                SetFieldProtection(Form, ONETASKPERPAGE, FormValue, 
                                                                PageBreakOff);
                FOR  i := PAGEHEADINGS TO COLUMNHEADINGS DO
                    FormValue[i].CardValue := FormValue[FieldNo].CardValue;
                    SetFieldProtection(Form, i, FormValue, PageBreakOff);
                END;
                IF ( NOT PageBreakOff ) THEN
                    WITH BackupPageRepeatSettings DO
                        FormValue[ONETASKPERPAGE].CardValue:= OneTaskPerPage;
                        FormValue[COLUMNHEADINGS].CardValue:=ColumnHeadings;
                        FormValue[PAGEHEADINGS].CardValue  :=PageHeadings;
                        FormValue[PAGEFOOTINGS].CardValue  :=PageFootings;
                    END;
                END;
                ShowValue( Form, ONETASKPERPAGE, FormValue );
                FOR  i := PAGEHEADINGS TO COLUMNHEADINGS DO
                    ShowValue( Form, i, FormValue );
                END;
            ELSE
            END;
        | CheckFieldExit :      ;
        | CheckFieldKey  :   ;
        END;

    RETURN TRUE;

END CheckDoPageRepeatForm;




PROCEDURE InitPageRepeatForm( VAR PageRepeatSettings : APageRepeatSettings;
                              VAR FormValue : ARRAY OF AFieldValue
                            );
BEGIN
    WITH PageRepeatSettings DO
        FormValue[PAGEBREAKS].CardValue     := ORD(PageBreaks);
        FormValue[ONETASKPERPAGE].CardValue := ORD(OneTaskRsrcPerPage);
        FormValue[COLUMNHEADINGS].CardValue := ORD(ColumnHeadings);
        FormValue[PAGEHEADINGS].CardValue   := ORD(PageHeadings);
        FormValue[PAGEFOOTINGS].CardValue   := ORD(PageFootings);
        FormValue[UNLIMITEDWIDTH].CardValue := ORD(UnlimitedWidth);
        FormValue[IGNORELMARGIN].CardValue  := ORD(IgnoreLMargin);
    END;
END InitPageRepeatForm;




PROCEDURE DoPageRepeatForm( VAR PageRepeatSettings  : APageRepeatSettings
                          ) : BOOLEAN;
VAR
    Code                    :   ACode;
    FormValue               :   ARRAY [0..LastPageRepeatFormFld]
                                                              OF AFieldValue;
BEGIN
    InitPageRepeatForm(PageRepeatSettings, FormValue);
    Code := DoForm(PageRepeatFormLeft, PageRepeatFormTop,
                  PageRepeatFormRight, PageRepeatFormBottom, TLRPFORMID, TRUE,
                  FormValue, CheckDoPageRepeatForm);

    IF (Code = ExitKey) THEN
        SetPageRepeatSettings(FormValue, PageRepeatSettings);
    END;

    RETURN ( Code = ExitKey );

END DoPageRepeatForm;

END PageOptn.
