M2L TimeLine/s=15000/b
IF NOT EXIST TimeLine.EXE ECHO Link failure for TimeLine>>TROUBLE.LOG
tag !
    M2L TLStats(TimeLine)/o/b
    IF NOT EXIST TLStats.OVL ECHO Link failure for TLStats>>TROUBLE.LOG
    M2L TLMenus(TimeLine)/o/b
    IF NOT EXIST TLMenus.OVL ECHO Link failure for TLMenus>>TROUBLE.LOG
    M2L TLReg(TimeLine)/o/b
    IF NOT EXIST TLReg.OVL ECHO Link failure for TLReg>>TROUBLE.LOG
    M2L TLMain(TimeLine)/o/b
    IF NOT EXIST TLMain.OVL ECHO Link failure for TLMain>>TROUBLE.LOG
    M2L TLEMS(TimeLine)/o/b
    IF NOT EXIST TLEMS.OVL ECHO Link failure for TLEMS>>TROUBLE.LOG
    M2L TLSwapF(TimeLine)/o/b
    IF NOT EXIST TLSwapF.OVL ECHO Link failure for TLSwapF>>TROUBLE.LOG
    M2L TLBTSMac(TimeLine)/o/b
    IF NOT EXIST TLBTSMac.OVL ECHO Link failure for TLBTSMac>>TROUBLE.LOG
    M2L TLCaptio(TimeLine)/o/b
    IF NOT EXIST TLCaptio.OVL ECHO Link failure for TLCaptio>>TROUBLE.LOG
    M2L TLFBase(TimeLine)
    IF NOT EXIST TLFBase.OVL ECHO Link failure for TLFBase>>TROUBLE.LOG
        M2L TLChange(TLFBase)/o/b
        IF NOT EXIST TLChange.OVL ECHO Link failure for TLChange>>TROUBLE.LOG
        M2L TLTAFORM(TLFBase)/o/b
        IF NOT EXIST TLTAFORM.OVL ECHO Link failure for TLTAFORM>>TROUBLE.LOG
        M2L TLRsrc(TLFBase)/o/b
        IF NOT EXIST TLRsrc.OVL ECHO Link failure for TLRsrc>>TROUBLE.LOG
        M2L TLDOSFrm(TLFBase)/o/b
        IF NOT EXIST TLDOSFrm.OVL ECHO Link failure for TLDOSFrm>>TROUBLE.LOG
        M2L TLFForm(TLFBase)/o/b
        IF NOT EXIST TLFForm.OVL ECHO Link failure for TLFForm>>TROUBLE.LOG
        M2L TLD411FM(TLFBase)/o/b
        IF NOT EXIST TLD411FM.OVL ECHO Link failure for TLD411FM>>TROUBLE.LOG
        M2L TLSchFor(TLFBase)/o/b
        IF NOT EXIST TLSchFor.OVL ECHO Link failure for TLSchFor>>TROUBLE.LOG
        M2L TLAsList(TLFBase)/o/b
        IF NOT EXIST TLAsList.OVL ECHO Link failure for TLAsList>>TROUBLE.LOG
        M2L TLCalcul(TLFBase)/o/b
        IF NOT EXIST TLCalcul.OVL ECHO Link failure for TLCalcul>>TROUBLE.LOG
    M2L TLFilter(TimeLine)/o/b
    IF NOT EXIST TLFilter.OVL ECHO Link failure for TLFilter>>TROUBLE.LOG
    M2L TLDir411(TimeLine)/o/b
    IF NOT EXIST TLDir411.OVL ECHO Link failure for TLDir411>>TROUBLE.LOG
    M2L TLFSelct(TimeLine)/o/b
    IF NOT EXIST TLFSelct.OVL ECHO Link failure for TLFSelct>>TROUBLE.LOG
    M2L TLTaskLi(TimeLine)/o/b
    IF NOT EXIST TLTaskLi.OVL ECHO Link failure for TLTaskLi>>TROUBLE.LOG
    M2L TLRsrcEd(TimeLine)/o/b
    IF NOT EXIST TLRsrcEd.OVL ECHO Link failure for TLRsrcEd>>TROUBLE.LOG
    M2L TLLayLis(TimeLine)/o/b
    IF NOT EXIST TLLayLis.OVL ECHO Link failure for TLLayLis>>TROUBLE.LOG
    M2L TLPlan(TimeLine)
    IF NOT EXIST TLPlan.OVL ECHO Link failure for TLPlan>>TROUBLE.LOG
        M2L TLCPM(TLPlan)/o/b
        IF NOT EXIST TLCPM.OVL ECHO Link failure for TLCPM>>TROUBLE.LOG
        M2L TLplanEX(TLPlan)/o/b
        IF NOT EXIST TLplanEX.OVL ECHO Link failure for TLplanEX>>TROUBLE.LOG
    M2L TLGetIt(TimeLine)
    IF NOT EXIST TLGetIt.OVL ECHO Link failure for TLGetIt>>TROUBLE.LOG
        M2L TLStart(TLGetIt)/o/b
        IF NOT EXIST TLStart.OVL ECHO Link failure for TLStart>>TROUBLE.LOG
        M2L TLiTl5(TLGetIt)/o/b
        IF NOT EXIST TLiTl5.OVL ECHO Link failure for TLiTl45>>TROUBLE.LOG
    M2L TlxPrep(TimeLine)
    IF NOT EXIST TlxPrep.OVL ECHO Link failure for TlxPrep>>TROUBLE.LOG
        M2L TlxCnfg(TlxPrep)/o/b
        IF NOT EXIST TlxCnfg.OVL ECHO Link failure for TlxCnfg>>TROUBLE.LOG
    M2L TlxTl5(TimeLine)/o/b
    IF NOT EXIST TlxTl5.OVL ECHO Link failure for TlxTl45>>TROUBLE.LOG
    M2L TLRollem(TimeLine)
    IF NOT EXIST TLRollem.OVL ECHO Link failure for TLRollem>>TROUBLE.LOG
    M2L TLSPBase(TimeLine)
    IF NOT EXIST TLSPBase.OVL ECHO Link failure for TLSPBase>>TROUBLE.LOG
        M2L TLSpread(TLSPBase)/o/b
        IF NOT EXIST TLSpread.OVL ECHO Link failure for TLSpread>>TROUBLE.LOG
    M2L TLShowJo(TimeLine)/o/b
    IF NOT EXIST TLShowJo.OVL ECHO Link failure for TLShowJo>>TROUBLE.LOG
    M2L TLErase(TimeLine)/o/b
    IF NOT EXIST TLErase.OVL ECHO Link failure for TLErase>>TROUBLE.LOG
    M2L TLRenum(TimeLine)/o/b
    IF NOT EXIST TLRenum.OVL ECHO Link failure for TLRenum>>TROUBLE.LOG
    M2L TLMagic(TimeLine)/o/b
    IF NOT EXIST TLMagic.OVL ECHO Link failure for TLMagic>>TROUBLE.LOG
    M2L TLBookm(TimeLine)/o/b
    IF NOT EXIST TLBookm.OVL ECHO Link failure for TLBookm>>TROUBLE.LOG
    M2L TLXMS(TimeLine)/o/b
    IF NOT EXIST TLXMS.OVL ECHO Link failure for TLXMS>>TROUBLE.LOG
    M2L TLVIDMEM(TimeLine)/o/b
    IF NOT EXIST TLVIDMEM.OVL ECHO Link failure for TLVIDMEM>>TROUBLE.LOG
    M2L TLPALETT(TimeLine)/o/b
    IF NOT EXIST TLPALETT.OVL ECHO Link failure for TLPALETT>>TROUBLE.LOG
