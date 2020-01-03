M2L TimeLine/s=15000/b/map
IF NOT EXIST TimeLine.EXE ECHO Link failure for TimeLine>>TROUBLE.LOG
    tag !
    M2L TLTskChk(TimeLine)/o/b
    IF NOT EXIST TLTskChk.OVL ECHO Link failure for TLMouse>>TROUBLE.LOG
    M2L TLMouse(TimeLine)/o/b
    IF NOT EXIST TLMouse.OVL ECHO Link failure for TLMouse>>TROUBLE.LOG
    M2L TLMenus(TimeLine)/o/b
    IF NOT EXIST TLMenus.OVL ECHO Link failure for TLMenus>>TROUBLE.LOG
    M2L TLStart(TimeLine)/o/b
    IF NOT EXIST TLStart.OVL ECHO Link failure for TLStart>>TROUBLE.LOG
    M2L TLReg(TimeLine)/o/b
    IF NOT EXIST TLReg.OVL ECHO Link failure for TLReg>>TROUBLE.LOG
    M2L TLMain(TimeLine)/o/b
    IF NOT EXIST TLMain.OVL ECHO Link failure for TLMain>>TROUBLE.LOG
    M2L TLSwapF(TimeLine)/o/b
    IF NOT EXIST TLSwapF.OVL ECHO Link failure for TLSwapF>>TROUBLE.LOG
    M2L TLEMS(TimeLine)/o/b
    IF NOT EXIST TLEMS.OVL ECHO Link failure for TLEMS>>TROUBLE.LOG
    M2L TLCaptio(TimeLine)/o/b
    IF NOT EXIST TLCaptio.OVL ECHO Link failure for TLCaptio>>TROUBLE.LOG
    M2L TLFBase(TimeLine)/map
    IF NOT EXIST TLFBase.OVL ECHO Link failure for TLFBase>>TROUBLE.LOG
        M2L TLFForm(TLFBase)/o/b
        IF NOT EXIST TLFForm.OVL ECHO Link failure for TLFForm>>TROUBLE.LOG
        M2L TLDir411(TLFBase)/o/b
        IF NOT EXIST TLDir411.OVL ECHO Link failure for TLDir411>>TROUBLE.LOG
    M2L TLFilter(TimeLine)/o/b
    IF NOT EXIST TLFilter.OVL ECHO Link failure for TLFilter>>TROUBLE.LOG
    M2L TLGoTo(TimeLine)/o/b
    IF NOT EXIST TLGoTo.OVL ECHO Link failure for TLGoTo>>TROUBLE.LOG
    M2L TLGetIt(TimeLine)/map
    IF NOT EXIST TLGetIt.OVL ECHO Link failure for TLGetIt>>TROUBLE.LOG
        M2L TLiTl5(TLGetIt)/o/b
        IF NOT EXIST TLiTl5.OVL ECHO Link failure for TLiTl45>>TROUBLE.LOG
