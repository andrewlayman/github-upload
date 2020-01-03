Rem   Batch file built by REBUILD on 03-17-1991 at 14:46:19
Rem        Exclude items with 'MACRO'
Rem        Exclude items with 'REPORT'
Rem        Exclude items with 'OPTIONAL'
Rem        Exclude items with 'EXPORT'
Rem        Exclude items with 'IMPORT'
Rem
Del Trouble.Log
IF EXIST B4COMPIL.BAT c:\COMMAND/C B4COMPIL.BAT
IF EXIST GENERIC.PAT DEL GENERIC.PAT
IF EXIST CHECKING.PAT DEL CHECKING.PAT
Rem
Rem  Create the two standard pattern files, GENERIC.PAT and CHECKING.PAT
Rem
ECHO .head>>GENERIC.PAT
ECHO del *.lst>>GENERIC.PAT
ECHO .def>>GENERIC.PAT
ECHO m2c {#.def}>>GENERIC.PAT
ECHO .between>>GENERIC.PAT
ECHO if exist *.lst goto error>>GENERIC.PAT
ECHO .mod>>GENERIC.PAT
ECHO m2comp {#.mod}>>GENERIC.PAT
ECHO if exist *.lst goto error>>GENERIC.PAT
ECHO .link>>GENERIC.PAT
ECHO rem link step omitted>>GENERIC.PAT
ECHO .tail>>GENERIC.PAT
ECHO goto end>>GENERIC.PAT
ECHO IF EXIST OK.BAT c:\COMMAND/C OK %%1>>GENERIC.PAT
ECHO :error>>GENERIC.PAT
ECHO IF EXIST ERROR.BAT c:\COMMAND/C ERROR %%1>>GENERIC.PAT
ECHO :end>>GENERIC.PAT
Rem
Rem  Now the CHECKING pattern file.  Only difference is that
Rem  the modula compiler is run with extra checking on.
Rem
ECHO .head>>CHECKING.PAT
ECHO del *.lst>>CHECKING.PAT
ECHO .def>>CHECKING.PAT
ECHO m2c {#.def}>>CHECKING.PAT
ECHO .between>>CHECKING.PAT
ECHO if exist *.lst goto error>>CHECKING.PAT
ECHO .mod>>CHECKING.PAT
ECHO m2comp {#.mod/r+/t+}>>CHECKING.PAT
ECHO if exist *.lst goto error>>CHECKING.PAT
ECHO .link>>CHECKING.PAT
ECHO rem link step omitted>>CHECKING.PAT
ECHO .tail>>CHECKING.PAT
ECHO goto end>>CHECKING.PAT
ECHO IF EXIST OK.BAT c:\COMMAND/C OK %%1>>CHECKING.PAT
ECHO :error>>CHECKING.PAT
ECHO IF EXIST ERROR.BAT c:\COMMAND/C ERROR %%1>>CHECKING.PAT
ECHO :end>>CHECKING.PAT

:01
M2Make TimeLine/pf=Generic/S=EXE
c:\Command/c CmdFile TimeLine /s=15000/b EXE
IF EXIST *.LST ECHO Compile failure on TimeLine at 01>>TROUBLE.LOG
IF EXIST *.LST GOTO 02
M2L TimeLine/s=15000/b
IF NOT EXIST TimeLine.EXE ECHO Link failure for TimeLine>>TROUBLE.LOG

:0101
    M2Make TLStats/pf=Generic/S=OVL
    c:\Command/c CmdFile TLStats (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLStats at 0101>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0102
    M2L TLStats(TimeLine)/o/b
    IF NOT EXIST TLStats.OVL ECHO Link failure for TLStats>>TROUBLE.LOG

:0102

:0103
    M2Make TLMenus/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMenus (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMenus at 0103>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0104
    M2L TLMenus(TimeLine)/o/b
    IF NOT EXIST TLMenus.OVL ECHO Link failure for TLMenus>>TROUBLE.LOG

:0104
    M2Make TLReg/pf=Generic/S=OVL
    c:\Command/c CmdFile TLReg (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLReg at 0104>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0105
    M2L TLReg(TimeLine)/o/b
    IF NOT EXIST TLReg.OVL ECHO Link failure for TLReg>>TROUBLE.LOG

:0105
    M2Make TLMain/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMain (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMain at 0105>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0106
    M2L TLMain(TimeLine)/o/b
    IF NOT EXIST TLMain.OVL ECHO Link failure for TLMain>>TROUBLE.LOG

:0106
    M2Make TLEMS/pf=Generic/S=OVL
    c:\Command/c CmdFile TLEMS (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLEMS at 0106>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0107
    M2L TLEMS(TimeLine)/o/b
    IF NOT EXIST TLEMS.OVL ECHO Link failure for TLEMS>>TROUBLE.LOG

:0107
    M2Make TLSwapF/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSwapF (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSwapF at 0107>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0108
    M2L TLSwapF(TimeLine)/o/b
    IF NOT EXIST TLSwapF.OVL ECHO Link failure for TLSwapF>>TROUBLE.LOG

:0108
    M2Make TLBTSMac/pf=Generic/S=OVL
    c:\Command/c CmdFile TLBTSMac (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLBTSMac at 0108>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0109
    M2L TLBTSMac(TimeLine)/o/b
    IF NOT EXIST TLBTSMac.OVL ECHO Link failure for TLBTSMac>>TROUBLE.LOG

:0109
    M2Make TLCaptio/pf=Generic/S=OVL
    c:\Command/c CmdFile TLCaptio (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLCaptio at 0109>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010A
    M2L TLCaptio(TimeLine)/o/b
    IF NOT EXIST TLCaptio.OVL ECHO Link failure for TLCaptio>>TROUBLE.LOG

:010A

:010B
    M2Make TLFBase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFBase (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLFBase at 010B>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010C
    M2L TLFBase(TimeLine)
    IF NOT EXIST TLFBase.OVL ECHO Link failure for TLFBase>>TROUBLE.LOG

:010B01
        M2Make TLChange/pf=Generic/S=OVL
        c:\Command/c CmdFile TLChange (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLChange at 010B01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B02
        M2L TLChange(TLFBase)/o/b
        IF NOT EXIST TLChange.OVL ECHO Link failure for TLChange>>TROUBLE.LOG

:010B02
        M2Make TLTAFORM/pf=Generic/S=OVL
        c:\Command/c CmdFile TLTAFORM (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLTAFORM at 010B02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B03
        M2L TLTAFORM(TLFBase)/o/b
        IF NOT EXIST TLTAFORM.OVL ECHO Link failure for TLTAFORM>>TROUBLE.LOG

:010B03
        M2Make TLRsrc/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRsrc (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRsrc at 010B03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B04
        M2L TLRsrc(TLFBase)/o/b
        IF NOT EXIST TLRsrc.OVL ECHO Link failure for TLRsrc>>TROUBLE.LOG

:010B04
        M2Make TLDOSFrm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDOSFrm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDOSFrm at 010B04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B05
        M2L TLDOSFrm(TLFBase)/o/b
        IF NOT EXIST TLDOSFrm.OVL ECHO Link failure for TLDOSFrm>>TROUBLE.LOG

:010B05

:010B06
        M2Make TLFForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLFForm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLFForm at 010B06>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B07
        M2L TLFForm(TLFBase)/o/b
        IF NOT EXIST TLFForm.OVL ECHO Link failure for TLFForm>>TROUBLE.LOG
:010B07
:010B08
:010B09

:010B0A
        M2Make TLD411FM/pf=Generic/S=OVL
        c:\Command/c CmdFile TLD411FM (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLD411FM at 010B0A>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0B
        M2L TLD411FM(TLFBase)/o/b
        IF NOT EXIST TLD411FM.OVL ECHO Link failure for TLD411FM>>TROUBLE.LOG

:010B0B
:010B0C

:010B0D
:010B0G

:010B0H
        M2Make TLSchFor/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSchFor (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSchFor at 010B0H>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0I
        M2L TLSchFor(TLFBase)/o/b
        IF NOT EXIST TLSchFor.OVL ECHO Link failure for TLSchFor>>TROUBLE.LOG

:010B0I

:010B0J

:010B0K

:010B0L

:010B0M

:010B0N
:010B0O
        M2Make TLAsList/pf=Generic/S=OVL
        c:\Command/c CmdFile TLAsList (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLAsList at 010B0O>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0P
        M2L TLAsList(TLFBase)/o/b
        IF NOT EXIST TLAsList.OVL ECHO Link failure for TLAsList>>TROUBLE.LOG

:010B0P

:010B0Q

:010B0R

:010B0S

:010B0X
        M2Make TLCalcul/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCalcul (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCalcul at 010B0X>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0Y
        M2L TLCalcul(TLFBase)/o/b
        IF NOT EXIST TLCalcul.OVL ECHO Link failure for TLCalcul>>TROUBLE.LOG
:010B0Y


:010C
    M2Make TLFilter/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFilter (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFilter at 010C>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010D
    M2L TLFilter(TimeLine)/o/b
    IF NOT EXIST TLFilter.OVL ECHO Link failure for TLFilter>>TROUBLE.LOG

:010D
    M2Make TLDir411/pf=Generic/S=OVL
    c:\Command/c CmdFile TLDir411 (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLDir411 at 010D>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010E
    M2L TLDir411(TimeLine)/o/b
    IF NOT EXIST TLDir411.OVL ECHO Link failure for TLDir411>>TROUBLE.LOG

:010E
    M2Make TLFSelct/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFSelct (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFSelct at 010E>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010F
    M2L TLFSelct(TimeLine)/o/b
    IF NOT EXIST TLFSelct.OVL ECHO Link failure for TLFSelct>>TROUBLE.LOG

:010F
    M2Make TLTaskLi/pf=Generic/S=OVL
    c:\Command/c CmdFile TLTaskLi (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLTaskLi at 010F>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010G
    M2L TLTaskLi(TimeLine)/o/b
    IF NOT EXIST TLTaskLi.OVL ECHO Link failure for TLTaskLi>>TROUBLE.LOG
:010G
:010H

:010I
    M2Make TLRsrcEd/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRsrcEd (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRsrcEd at 010I>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010J
    M2L TLRsrcEd(TimeLine)/o/b
    IF NOT EXIST TLRsrcEd.OVL ECHO Link failure for TLRsrcEd>>TROUBLE.LOG

:010J
    M2Make TLLayLis/pf=Generic/S=OVL
    c:\Command/c CmdFile TLLayLis (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLLayLis at 010J>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010K
    M2L TLLayLis(TimeLine)/o/b
    IF NOT EXIST TLLayLis.OVL ECHO Link failure for TLLayLis>>TROUBLE.LOG

:010K
    M2Make TLPlan/pf=Generic/S=OVL
    c:\Command/c CmdFile TLPlan (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLPlan at 010K>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010L
    M2L TLPlan(TimeLine)
    IF NOT EXIST TLPlan.OVL ECHO Link failure for TLPlan>>TROUBLE.LOG

:010K01

:010K03
        M2Make TLCPM/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCPM (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCPM at 010K03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010K04
        M2L TLCPM(TLPlan)/o/b
        IF NOT EXIST TLCPM.OVL ECHO Link failure for TLCPM>>TROUBLE.LOG

:010K04
        M2Make TLplanEX/pf=Generic/S=OVL
        c:\Command/c CmdFile TLplanEX (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLplanEX at 010K04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010K05
        M2L TLplanEX(TLPlan)/o/b
        IF NOT EXIST TLplanEX.OVL ECHO Link failure for TLplanEX>>TROUBLE.LOG
:010K05


:010L
    M2Make TLGetIt/pf=Generic/S=OVL
    c:\Command/c CmdFile TLGetIt (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLGetIt at 010L>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010M
    M2L TLGetIt(TimeLine)
    IF NOT EXIST TLGetIt.OVL ECHO Link failure for TLGetIt>>TROUBLE.LOG

:010L01
        M2Make TLStart/pf=Generic/S=OVL
        c:\Command/c CmdFile TLStart (TLGetIt)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLStart at 010L01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L02
        M2L TLStart(TLGetIt)/o/b
        IF NOT EXIST TLStart.OVL ECHO Link failure for TLStart>>TROUBLE.LOG

:010L02

:010L05
        M2Make TLiTl5/pf=Generic/S=OVL
        c:\Command/c CmdFile TLiTl5 (TLGetIt)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLiTl5 at 010L05>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L06
        M2L TLiTl5(TLGetIt)/o/b
        IF NOT EXIST TLiTl5.OVL ECHO Link failure for TLiTl45>>TROUBLE.LOG
:010L06


:010M
    M2Make TlxPrep/pf=Generic/S=OVL
    c:\Command/c CmdFile TlxPrep (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TlxPrep at 010M>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010N
    M2L TlxPrep(TimeLine)
    IF NOT EXIST TlxPrep.OVL ECHO Link failure for TlxPrep>>TROUBLE.LOG

:010M01
        M2Make TlxCnfg/pf=Generic/S=OVL
        c:\Command/c CmdFile TlxCnfg (TlxPrep)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TlxCnfg at 010M01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010M02
        M2L TlxCnfg(TlxPrep)/o/b
        IF NOT EXIST TlxCnfg.OVL ECHO Link failure for TlxCnfg>>TROUBLE.LOG
:010M02


:010N
    M2Make TlxTl5/pf=Generic/S=OVL
    c:\Command/c CmdFile TlxTl5 (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TlxTl5 at 010N>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010O
    M2L TlxTl5(TimeLine)/o/b
    IF NOT EXIST TlxTl5.OVL ECHO Link failure for TlxTl45>>TROUBLE.LOG

:010O

:010Y
:010Z
    M2Make TLRollem/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRollem (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLRollem at 010Z>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0110
    M2L TLRollem(TimeLine)
    IF NOT EXIST TLRollem.OVL ECHO Link failure for TLRollem>>TROUBLE.LOG
:010Z01
:010Z02
:010Z03

:0110
:0111
:0112
:0113
:0114
:0115
:0116
:0117
:0118

:0119


:011A
:011B

:011C
:011D

:011D01


:011E
    M2Make TLSPBase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSPBase (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLSPBase at 011E>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011F
    M2L TLSPBase(TimeLine)
    IF NOT EXIST TLSPBase.OVL ECHO Link failure for TLSPBase>>TROUBLE.LOG

:011E01
        M2Make TLSpread/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSpread (TLSPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSpread at 011E01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011E02
        M2L TLSpread(TLSPBase)/o/b
        IF NOT EXIST TLSpread.OVL ECHO Link failure for TLSpread>>TROUBLE.LOG
:011E02


:011F
    M2Make TLShowJo/pf=Generic/S=OVL
    c:\Command/c CmdFile TLShowJo (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLShowJo at 011F>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011G
    M2L TLShowJo(TimeLine)/o/b
    IF NOT EXIST TLShowJo.OVL ECHO Link failure for TLShowJo>>TROUBLE.LOG

:011G
:011N

:011O
    M2Make TLErase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLErase (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLErase at 011O>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011P
    M2L TLErase(TimeLine)/o/b
    IF NOT EXIST TLErase.OVL ECHO Link failure for TLErase>>TROUBLE.LOG

:011P
    M2Make TLRenum/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRenum (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRenum at 011P>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011Q
    M2L TLRenum(TimeLine)/o/b
    IF NOT EXIST TLRenum.OVL ECHO Link failure for TLRenum>>TROUBLE.LOG

:011Q
:011R
    M2Make TLMagic/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMagic (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMagic at 011R>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011S
    M2L TLMagic(TimeLine)/o/b
    IF NOT EXIST TLMagic.OVL ECHO Link failure for TLMagic>>TROUBLE.LOG
:011S
:011T
:011U

:011V
    M2Make TLBookm/pf=Generic/S=OVL
    c:\Command/c CmdFile TLBookm (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLBookm at 011V>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011X
    M2L TLBookm(TimeLine)/o/b
    IF NOT EXIST TLBookm.OVL ECHO Link failure for TLBookm>>TROUBLE.LOG
:011X

:011Y

:011Z
    M2Make TLXMS/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXMS (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLXMS at 011Z>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0120
    M2L TLXMS(TimeLine)/o/b
    IF NOT EXIST TLXMS.OVL ECHO Link failure for TLXMS>>TROUBLE.LOG

:0120
    M2Make TLVIDMEM/pf=Generic/S=OVL
    c:\Command/c CmdFile TLVIDMEM (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLVIDMEM at 0120>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0121
    M2L TLVIDMEM(TimeLine)/o/b
    IF NOT EXIST TLVIDMEM.OVL ECHO Link failure for TLVIDMEM>>TROUBLE.LOG

:0121
    M2Make TLPALETT/pf=Generic/S=OVL
    c:\Command/c CmdFile TLPALETT (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLPALETT at 0121>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0122
    M2L TLPALETT(TimeLine)/o/b
    IF NOT EXIST TLPALETT.OVL ECHO Link failure for TLPALETT>>TROUBLE.LOG

:02
