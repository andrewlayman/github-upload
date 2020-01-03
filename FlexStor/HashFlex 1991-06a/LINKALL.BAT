Rem   Batch file built by REBUILD on 06-27-1990 at 11:07:54
Rem        Exclude items with 'MACRO'
Rem
Del Trouble.Log
IF EXIST B4COMPIL.BAT X:COMMAND/C B4COMPIL.BAT
IF EXIST GENERIC.PAT DEL GENERIC.PAT
IF EXIST CHECKING.PAT DEL CHECKING.PAT
M2L TimeLine/s=15000/b/map
IF NOT EXIST TimeLine.EXE ECHO Link failure for TimeLine>>TROUBLE.LOG
tag !

    M2L TLTskChk(TimeLine)/o/b
    IF NOT EXIST TLTskChk.OVL ECHO Link failure for TLTskChk>>TROUBLE.LOG
    M2L TLStats(TimeLine)/o/b
    IF NOT EXIST TLStats.OVL ECHO Link failure for TLStats>>TROUBLE.LOG
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
    M2L TLEMS(TimeLine)/o/b
    IF NOT EXIST TLEMS.OVL ECHO Link failure for TLEMS>>TROUBLE.LOG
    M2L TLSwapF(TimeLine)/o/b
    IF NOT EXIST TLSwapF.OVL ECHO Link failure for TLSwapF>>TROUBLE.LOG
    M2L TLBTSMac(TimeLine)/o/b
    IF NOT EXIST TLBTSMac.OVL ECHO Link failure for TLBTSMac>>TROUBLE.LOG
    M2L TLCaptio(TimeLine)/o/b
    IF NOT EXIST TLCaptio.OVL ECHO Link failure for TLCaptio>>TROUBLE.LOG
    M2L TLMemoEd(TimeLine)/o/b
    IF NOT EXIST TLMemoEd.OVL ECHO Link failure for TLMemoEd>>TROUBLE.LOG
    M2L TLFBase(TimeLine)/map
    IF NOT EXIST TLFBase.OVL ECHO Link failure for TLFBase>>TROUBLE.LOG
        M2L TLCalcul(TLFBase)/o/b
        IF NOT EXIST TLCalcul.OVL ECHO Link failure for TLCalcul>>TROUBLE.LOG
        M2L TLDOSFrm(TLFBase)/o/b
        IF NOT EXIST TLDOSFrm.OVL ECHO Link failure for TLDOSFrm>>TROUBLE.LOG
        M2L TLAssgn(TLFBase)/map
        IF NOT EXIST TLAssgn.OVL ECHO Link failure for TLAssgn>>TROUBLE.LOG
            M2L TLChange(TLAssgn)/o/b
            IF NOT EXIST TLChange.OVL ECHO Link failure for TLChange>>TROUBLE.LOG
        M2L TLRsrc(TLFBase)/o/b
        IF NOT EXIST TLRsrc.OVL ECHO Link failure for TLRsrc>>TROUBLE.LOG
        M2L TLFForm(TLFBase)/o/b
        IF NOT EXIST TLFForm.OVL ECHO Link failure for TLFForm>>TROUBLE.LOG
        M2L TLLink(TLFBase)/o/b
        IF NOT EXIST TLLink.OVL ECHO Link failure for TLLink>>TROUBLE.LOG
        M2L TLDir411(TLFBase)/o/b
        IF NOT EXIST TLDir411.OVL ECHO Link failure for TLDir411>>TROUBLE.LOG
        M2L TLRepFor(TLFBase)/o/b
        IF NOT EXIST TLRepFor.OVL ECHO Link failure for TLRepFor>>TROUBLE.LOG
        M2L TLCalndr(TLFBase)/o/b
        IF NOT EXIST TLCalndr.OVL ECHO Link failure for TLCalndr>>TROUBLE.LOG
        M2L TLEdge(TLFBase)/o/b
        IF NOT EXIST TLEdge.OVL ECHO Link failure for TLEdge>>TROUBLE.LOG
        M2L TL2Form(TLFBase)/o/b
        IF NOT EXIST TL2Form.OVL ECHO Link failure for TL2Form>>TROUBLE.LOG
        M2L TLRHForm(TLFBase)/o/b
        IF NOT EXIST TLRHForm.OVL ECHO Link failure for TLRHForm>>TROUBLE.LOG
        M2L TLSetClk(TLFBase)/o/b
        IF NOT EXIST TLSetClk.OVL ECHO Link failure for TLSetClk>>TROUBLE.LOG
        M2L TLSchFor(TLFBase)/o/b
        IF NOT EXIST TLSchFor.OVL ECHO Link failure for TLSchFor>>TROUBLE.LOG
        M2L TLLayout(TLFBase)/o/b
        IF NOT EXIST TLLayout.OVL ECHO Link failure for TLLayout>>TROUBLE.LOG
        M2L TLFltFrm(TLFBase)/o/b
        IF NOT EXIST TLFltFrm.OVL ECHO Link failure for TLFltFrm>>TROUBLE.LOG
        M2L TLXForm(TLFBase)/o/b
        IF NOT EXIST TLXForm.OVL ECHO Link failure for TLXForm>>TROUBLE.LOG
        M2L TLNetFor(TLFBase)/o/b
        IF NOT EXIST TLNetFor.OVL ECHO Link failure for TLNetFor>>TROUBLE.LOG
        M2L TLXSSOpt(TLFBase)/o/b
        IF NOT EXIST TLXSSOpt.OVL ECHO Link failure for TLXSSOpt>>TROUBLE.LOG
        M2L TLIForm(TLFBase)/o/b
        IF NOT EXIST TLIForm.OVL ECHO Link failure for TLIForm>>TROUBLE.LOG
        M2L TLAsList(TLFBase)/o/b
        IF NOT EXIST TLAsList.OVL ECHO Link failure for TLAsList>>TROUBLE.LOG
        M2L TLGSGant(TLFBase)/o/b
        IF NOT EXIST TLGSGant.OVL ECHO Link failure for TLGSGant>>TROUBLE.LOG
        M2L TLGSPert(TLFBase)/o/b
        IF NOT EXIST TLGSPert.OVL ECHO Link failure for TLGSPert>>TROUBLE.LOG
        M2L TLGSPage(TLFBase)/o/b
        IF NOT EXIST TLGSPage.OVL ECHO Link failure for TLGSPage>>TROUBLE.LOG
        M2L TLComm(TLFBase)/o/b
        IF NOT EXIST TLComm.OVL ECHO Link failure for TLComm>>TROUBLE.LOG
        M2L TLDevSet(TLFBase)/o/b
        IF NOT EXIST TLDevSet.OVL ECHO Link failure for TLDevSet>>TROUBLE.LOG
        M2L TLGSColr(TLFBase)/o/b
        IF NOT EXIST TLGSColr.OVL ECHO Link failure for TLGSColr>>TROUBLE.LOG
        M2L TLSetMou(TLFBase)/o/b
        IF NOT EXIST TLSetMou.OVL ECHO Link failure for TLSetMou>>TROUBLE.LOG
    M2L TLFilter(TimeLine)/o/b
    IF NOT EXIST TLFilter.OVL ECHO Link failure for TLFilter>>TROUBLE.LOG
    M2L TLFSelct(TimeLine)/o/b
    IF NOT EXIST TLFSelct.OVL ECHO Link failure for TLFSelct>>TROUBLE.LOG
    M2L TLTaskLi(TimeLine)/o/b
    IF NOT EXIST TLTaskLi.OVL ECHO Link failure for TLTaskLi>>TROUBLE.LOG
    M2L TLGoTo(TimeLine)/o/b
    IF NOT EXIST TLGoTo.OVL ECHO Link failure for TLGoTo>>TROUBLE.LOG
    M2L TLDepend(TimeLine)/o/b
    IF NOT EXIST TLDepend.OVL ECHO Link failure for TLDepend>>TROUBLE.LOG
    M2L TLRHist(TimeLine)/o/b
    IF NOT EXIST TLRHist.OVL ECHO Link failure for TLRHist>>TROUBLE.LOG
    M2L TLRsrcEd(TimeLine)/o/b
    IF NOT EXIST TLRsrcEd.OVL ECHO Link failure for TLRsrcEd>>TROUBLE.LOG
    M2L TLLayLis(TimeLine)/o/b
    IF NOT EXIST TLLayLis.OVL ECHO Link failure for TLLayLis>>TROUBLE.LOG
    M2L TLPlan(TimeLine)/map
    IF NOT EXIST TLPlan.OVL ECHO Link failure for TLPlan>>TROUBLE.LOG
        M2L TLRPlan(TLPlan)/o/b
        IF NOT EXIST TLRPlan.OVL ECHO Link failure for TLRPlan>>TROUBLE.LOG
        M2L TLLoops(TLPlan)/o/b
        IF NOT EXIST TLLoops.OVL ECHO Link failure for TLLoops>>TROUBLE.LOG
        M2L TLCPM(TLPlan)/o/b
        IF NOT EXIST TLCPM.OVL ECHO Link failure for TLCPM>>TROUBLE.LOG
    M2L TLGetIt(TimeLine)/map
    IF NOT EXIST TLGetIt.OVL ECHO Link failure for TLGetIt>>TROUBLE.LOG
        M2L TLiTl5(TLGetIt)/o/b
        IF NOT EXIST TLiTl5.OVL ECHO Link failure for TLiTl45>>TROUBLE.LOG
    M2L TlxPrep(TimeLine)/map
    IF NOT EXIST TlxPrep.OVL ECHO Link failure for TlxPrep>>TROUBLE.LOG
        M2L TlxCnfg(TlxPrep)/o/b
        IF NOT EXIST TlxCnfg.OVL ECHO Link failure for TlxCnfg>>TROUBLE.LOG
    M2L TlxTl5(TimeLine)/o/b
    IF NOT EXIST TlxTl5.OVL ECHO Link failure for TlxTl45>>TROUBLE.LOG
    M2L TLCr(TimeLine)/map
    IF NOT EXIST TLCr.OVL ECHO Link failure for TLCr>>TROUBLE.LOG
        M2L TLCrForm(TLCr)/o/b
        IF NOT EXIST TLCrForm.OVL ECHO Link failure for TLCrForm>>TROUBLE.LOG
        M2L TLCrWork(TLCr)/o/b
        IF NOT EXIST TLCrWork.OVL ECHO Link failure for TLCrWork>>TROUBLE.LOG
    M2L TLRTable(TimeLine)/o/b
    IF NOT EXIST TLRTable.OVL ECHO Link failure for TLRTable>>TROUBLE.LOG
    M2L TLTTable(TimeLine)/o/b
    IF NOT EXIST TLTTable.OVL ECHO Link failure for TLTTable>>TROUBLE.LOG
    M2L TLXRsass(TimeLine)/o/b
    IF NOT EXIST TLXRsass.OVL ECHO Link failure for TLXRsass>>TROUBLE.LOG
    M2L TLRPBase(TimeLine)/map
    IF NOT EXIST TLRPBase.OVL ECHO Link failure for TLRPBase>>TROUBLE.LOG
        M2L TLGr(TLRPBase)/o/b
        IF NOT EXIST TLGr.OVL ECHO Link failure for TLGr>>TROUBLE.LOG
        M2L TLPrt1D(TLRPBase)/o/b
        IF NOT EXIST TLPrt1D.OVL ECHO Link failure for TLPrt1D>>TROUBLE.LOG
        M2L TLPrt2D(TLRPBase)/o/b
        IF NOT EXIST TLPrt2D.OVL ECHO Link failure for TLPrt2D>>TROUBLE.LOG
        M2L TLHR(TLRPBase)/o/b
        IF NOT EXIST TLHR.OVL ECHO Link failure for TLHR>>TROUBLE.LOG
        M2L ViReport(TLRPBase)/o/b
        IF NOT EXIST ViReport.OVL ECHO Link failure for ViReport>>TROUBLE.LOG
        M2L TLAr(TLRPBase)/o/b
        IF NOT EXIST TLAr.OVL ECHO Link failure for TLAr>>TROUBLE.LOG
        M2L TLArOptn(TLRPBase)/o/b
        IF NOT EXIST TLArOptn.OVL ECHO Link failure for TLArOptn>>TROUBLE.LOG
        M2L TLDr(TLRPBase)/o/b
        IF NOT EXIST TLDr.OVL ECHO Link failure for TLDr>>TROUBLE.LOG
        M2L TLSr(TLRPBase)/o/b
        IF NOT EXIST TLSr.OVL ECHO Link failure for TLSr>>TROUBLE.LOG
        M2L TLSrOptn(TLRPBase)/o/b
        IF NOT EXIST TLSrOptn.OVL ECHO Link failure for TLSrOptn>>TROUBLE.LOG
    M2L TLGlue(TimeLine)/o/b
    IF NOT EXIST TLGlue.OVL ECHO Link failure for TLGlue>>TROUBLE.LOG
    M2L TLRollem(TimeLine)/o/b
    IF NOT EXIST TLRollem.OVL ECHO Link failure for TLRollem>>TROUBLE.LOG
    M2L TLLnkClo(TLRollem)/o/b
    IF NOT EXIST TLLnkClo.OVL ECHO Link failure for TLLnkClo>>TROUBLE.LOG
    M2L TLLnkSum(TLRollem)/o/b
    IF NOT EXIST TLLnkSum.OVL ECHO Link failure for TLLnkSum>>TROUBLE.LOG
    M2L TLEdits(TimeLine)/o/b
    IF NOT EXIST TLEdits.OVL ECHO Link failure for TLEdits>>TROUBLE.LOG
    M2L TLHelper(TimeLine)/o/b
    IF NOT EXIST TLHelper.OVL ECHO Link failure for TLHelper>>TROUBLE.LOG
    M2L TLMKBase(TimeLine)/o/b
    IF NOT EXIST TLMKBase.OVL ECHO Link failure for TLMKBase>>TROUBLE.LOG
    M2L TLSort(TimeLine)/o/b
    IF NOT EXIST TLSort.OVL ECHO Link failure for TLSort>>TROUBLE.LOG
    M2L TLFileMG(TimeLine)/o/b
    IF NOT EXIST TLFileMG.OVL ECHO Link failure for TLFileMG>>TROUBLE.LOG
    M2L TLSetVid(TimeLine)/o/b
    IF NOT EXIST TLSetVid.OVL ECHO Link failure for TLSetVid>>TROUBLE.LOG
    M2L TLDOS(TimeLine)/o/b
    IF NOT EXIST TLDOS.OVL ECHO Link failure for TLDOS>>TROUBLE.LOG
    M2L TLPSetup(TimeLine)/o/b
    M2L TLFmtInt(TimeLine)/o/b
    IF NOT EXIST TLFmtInt.OVL ECHO Link failure for TLFmtInt>>TROUBLE.LOG
    M2L TLAlarm(TimeLine)/o/b
    IF NOT EXIST TLAlarm.OVL ECHO Link failure for TLAlarm>>TROUBLE.LOG
    M2L TLSpread(TimeLine)/o/b
    IF NOT EXIST TLSpread.OVL ECHO Link failure for TLSpread>>TROUBLE.LOG
    M2L TLShowJo(TimeLine)/o/b
    IF NOT EXIST TLShowJo.OVL ECHO Link failure for TLShowJo>>TROUBLE.LOG
    M2L TLWBSGen(TimeLine)/map
    IF NOT EXIST TLWBSGen.OVL ECHO Link failure for TLWBSGen>>TROUBLE.LOG
        M2L TLWBSMAN(TLWBSGen)/o/b
        IF NOT EXIST TLWBSMAN.OVL ECHO Link failure for TLWBSMAN>>TROUBLE.LOG
        M2L TLWBSREN(TLWBSGen)/o/b
        IF NOT EXIST TLWBSREN.OVL ECHO Link failure for TLWBSREN>>TROUBLE.LOG
        M2L TLRENUMB(TLWBSGen)/o/b
        IF NOT EXIST TLRENUMB.OVL ECHO Link failure for TLRENUMB>>TROUBLE.LOG
        M2L TLWBSVER(TLWBSGen)/o/b
        IF NOT EXIST TLWBSVER.OVL ECHO Link failure for TLWBSVER>>TROUBLE.LOG
        M2L TLVERIFY(TLWBSGen)/o/b
        IF NOT EXIST TLVERIFY.OVL ECHO Link failure for TLVERIFY>>TROUBLE.LOG
        M2L TLWBSNUM(TLWBSGen)/o/b
        IF NOT EXIST TLWBSNUM.OVL ECHO Link failure for TLWBSNUM>>TROUBLE.LOG
        M2L TLWBSVR(TLWBSGen)/o/b
        IF NOT EXIST TLWBSVR.OVL ECHO Link failure for TLWBSVR>>TROUBLE.LOG
        M2L TLWBSTRA(TLWBSGen)/o/b
        IF NOT EXIST TLWBSTRA.OVL ECHO Link failure for TLWBSTRA>>TROUBLE.LOG
        M2L TLWBSERA(TLWBSGen)/o/b
        IF NOT EXIST TLWBSERA.OVL ECHO Link failure for TLWBSERA>>TROUBLE.LOG
        M2L TLDUPLIC(TLWBSGen)/o/b
        IF NOT EXIST TLDUPLIC.OVL ECHO Link failure for TLDUPLIC>>TROUBLE.LOG
    M2L TLGSPrep(TimeLine)/o/b
    IF NOT EXIST TLGSPrep.OVL ECHO Link failure for TLGSPrep>>TROUBLE.LOG
    M2L TLMakStd(TimeLine)/o/b
    IF NOT EXIST TLMakStd.OVL ECHO Link failure for TLMakStd>>TROUBLE.LOG
    M2L TLErase(TimeLine)/o/b
    IF NOT EXIST TLErase.OVL ECHO Link failure for TLErase>>TROUBLE.LOG
    M2L TLRenum(TimeLine)/o/b
    IF NOT EXIST TLRenum.OVL ECHO Link failure for TLRenum>>TROUBLE.LOG
    M2L Macros(TimeLine)/map
    IF NOT EXIST Macros.OVL ECHO Link failure for Macros>>TROUBLE.LOG
        M2L MacAdd(Macros)/o/b
        IF NOT EXIST MacAdd.OVL ECHO Link failure for MacAdd>>TROUBLE.LOG
        M2L MacChain(Macros)/o/b
        IF NOT EXIST MacChain.OVL ECHO Link failure for MacChain>>TROUBLE.LOG
        M2L MacEdit(Macros)/o/b
        IF NOT EXIST MacEdit.OVL ECHO Link failure for MacEdit>>TROUBLE.LOG
        M2L MacForm1(Macros)/o/b
        IF NOT EXIST MacForm1.OVL ECHO Link failure for MacForm1>>TROUBLE.LOG
        M2L MacInit(Macros)/o/b
        IF NOT EXIST MacInit.OVL ECHO Link failure for MacInit>>TROUBLE.LOG
        M2L MacInst(Macros)/o/b
        IF NOT EXIST MacInst.OVL ECHO Link failure for MacInst>>TROUBLE.LOG
        M2L MacLink(Macros)/o/b
        IF NOT EXIST MacLink.OVL ECHO Link failure for MacLink>>TROUBLE.LOG
        M2L MacLoad(Macros)/o/b
        IF NOT EXIST MacLoad.OVL ECHO Link failure for MacLoad>>TROUBLE.LOG
        M2L MacMenu(Macros)/o/b
        IF NOT EXIST MacMenu.OVL ECHO Link failure for MacMenu>>TROUBLE.LOG
        M2L MacMenuD(Macros)/o/b
        IF NOT EXIST MacMenuD.OVL ECHO Link failure for MacMenuD>>TROUBLE.LOG
        M2L MacMenuF(Macros)/o/b
        IF NOT EXIST MacMenuF.OVL ECHO Link failure for MacMenuF>>TROUBLE.LOG
        M2L MacMsgFo(Macros)/o/b
        IF NOT EXIST MacMsgFo.OVL ECHO Link failure for MacMsgFo>>TROUBLE.LOG
        M2L MacNest(Macros)/o/b
        IF NOT EXIST MacNest.OVL ECHO Link failure for MacNest>>TROUBLE.LOG
        M2L MacSave(Macros)/o/b
        IF NOT EXIST MacSave.OVL ECHO Link failure for MacSave>>TROUBLE.LOG
        M2L MacSec(Macros)/o/b
        IF NOT EXIST MacSec.OVL ECHO Link failure for MacSec>>TROUBLE.LOG
        M2L MacVarF(Macros)/o/b
        IF NOT EXIST MacVarF.OVL ECHO Link failure for MacVarF>>TROUBLE.LOG
        M2L MacPick(Macros)/o/b
        IF NOT EXIST MacPick.OVL ECHO Link failure for MacPick>>TROUBLE.LOG
        M2L MacPlay(Macros)/o/b
        IF NOT EXIST MacPlay.OVL ECHO Link failure for MacPlay>>TROUBLE.LOG
        M2L MacEd(Macros)/o/b
        IF NOT EXIST MacEd.OVL ECHO Link failure for MacEd>>TROUBLE.LOG
        M2L MacRec(Macros)/o/b
        IF NOT EXIST MacRec.OVL ECHO Link failure for MacRec>>TROUBLE.LOG
    M2L TLMagic(TimeLine)/o/b
    IF NOT EXIST TLMagic.OVL ECHO Link failure for TLMagic>>TROUBLE.LOG
    M2L TLLogger(TimeLine)/o/b
    IF NOT EXIST TLLogger.OVL ECHO Link failure for TLLogger>>TROUBLE.LOG
    M2L TLTimer(TimeLine)/o/b
    IF NOT EXIST TLTimer.OVL ECHO Link failure for TLTimer>>TROUBLE.LOG
    M2L TLKodak(TimeLine)/o/b
    IF NOT EXIST TLKodak.OVL ECHO Link failure for TLKodak>>TROUBLE.LOG
    M2L TLLocker(TimeLine)/o/b
    IF NOT EXIST TLLocker.OVL ECHO Link failure for TLLocker>>TROUBLE.LOG
    M2L TLMagic2(TimeLine)/o/b
    IF NOT EXIST TLMagic2.OVL ECHO Link failure for TLMagic2>>TROUBLE.LOG

:02
IF EXIST AFCOMPIL.BAT X:COMMAND/C AFCOMPIL.BAT
:LOGOUT
