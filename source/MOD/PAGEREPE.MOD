IMPLEMENTATION MODULE PageRepeat;
(*
        MODIFICATION History -

        06-APR-89 KKC First version
        02-May-89 KKC - Make COLUMNHEADINGS, PAGEHEADINGS, PAGEFOOTINGS fields
                        not hidden when page break is not off.
        17-May-89 KKC - Rearrange form fields.
        19-May-89 KKC - Add One Task Per Page Option
        31-May-89 KKC - Set Heading/Footing fields to Every Page when 
                        page break is switched to YES.
        12-Jun-89 KKC - Split pagerepeat.mod into pagerepeat.mod and 
                        pageform.mod
        11-Aug-89 KKC - Pass Pointer instead of address.
                      - Add three blank lines between procedures.
        11-Sep-89 KKC - Default OneTaskRsrcPerPage to FALSE.
        20-Mar-91 AJL - Use a VAR parameter instead of a damn pointer.
                        Get with the 20th century, Ken!
*)

FROM SYSTEM                IMPORT
    (* TYPE  *)                 ADDRESS;

CONST
    ModuleNumber            =   7100;




PROCEDURE InitPageRepeatSettings(VAR PageRepeatSettings : APageRepeatSettings);
BEGIN
    WITH PageRepeatSettings DO
        PageBreaks := TRUE;
        OneTaskRsrcPerPage := FALSE;
        IgnoreLMargin := TRUE;
        ColumnHeadings := EveryPage;
        PageHeadings := EveryPage;
        PageFootings := EveryPage;
        UnlimitedWidth := TRUE;
    END;
END InitPageRepeatSettings;




PROCEDURE PageBreaksEnable( VAR PageRepeatSettings : APageRepeatSettings
                            ) : BOOLEAN;
BEGIN
   RETURN PageRepeatSettings.PageBreaks;
END PageBreaksEnable;




PROCEDURE IsOneTaskOrResourcePerPage(VAR PageRepeatSettings : APageRepeatSettings
                                    ) : BOOLEAN;
BEGIN
   RETURN PageRepeatSettings.OneTaskRsrcPerPage;
END IsOneTaskOrResourcePerPage;




(****************************************************************************
    RepeatColumnHeadings    -
        If PageBreak is disable then return false;
        If Columnheading is disable then return false;
        otherwise return true;
****************************************************************************)
PROCEDURE RepeatColumnHeadings(VAR PageRepeatSettings : APageRepeatSettings
                              ) : BOOLEAN;
BEGIN
    RETURN ( PageRepeatSettings.ColumnHeadings = EveryPage );
END RepeatColumnHeadings;




(****************************************************************************
    RepeatPageHeadings    -
        If PageBreak is disable then return false;
        If Pageheading is disable then return false;
        otherwise return true;
****************************************************************************)
PROCEDURE RepeatPageHeadings(VAR PageRepeatSettings : APageRepeatSettings
                            ) : BOOLEAN;
BEGIN
    RETURN ( PageRepeatSettings.PageHeadings = EveryPage );
END RepeatPageHeadings;




(****************************************************************************
    RepeatColumnFootings    -
        If PageBreak is disable then return false;
        If ColumnFooting is disable then return false;
        otherwise return true;
****************************************************************************)
PROCEDURE RepeatPageFootings(VAR PageRepeatSettings : APageRepeatSettings
                            ) : BOOLEAN;
BEGIN
    RETURN ( PageRepeatSettings.PageFootings = EveryPage );
END RepeatPageFootings;




PROCEDURE UnlimitedPageWidth(VAR PageRepeatSettings : APageRepeatSettings
                            ) : BOOLEAN;
BEGIN
    RETURN PageRepeatSettings.UnlimitedWidth;
END UnlimitedPageWidth;




PROCEDURE IgnoreLeftMargin(VAR PageRepeatSettings : APageRepeatSettings
                          ) : BOOLEAN;
BEGIN
    RETURN PageRepeatSettings.IgnoreLMargin;
END IgnoreLeftMargin;

END PageRepeat.
