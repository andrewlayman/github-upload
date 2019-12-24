IMPLEMENTATION MODULE Bind;

(*  =========================================================================
    Last Edit : August 6, 1989 10:16PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
         Simulates Overlay calls in OS/2.

    MODIFICATION HISTORY:
        04-Aug-89 WKH   First version for Time Line V4.
    =========================================================================
*)

FROM Strings                IMPORT 
    (* PROC *)                  CompareStr, Length;


(*********************
FROM TL1D123	    IMPORT TL1D123Bind;
FROM TL2D123	    IMPORT TL2D123Bind;
FROM TL2Form	    IMPORT TL2FormBind;
FROM TLBTSMacro     IMPORT TLBTSMacBind;
FROM TLCALNDR	    IMPORT TLCalndrBind;
FROM TLChange	    IMPORT TLChangeBind;
FROM TLCr	    IMPORT TLCrBind;
FROM TlCrForm	    IMPORT TLCrFormBind;
FROM TLCrWork	    IMPORT TLCrWorkBind;
FROM TLDepend	    IMPORT TLDependBind;
FROM TLDir411	    IMPORT TLDir411Bind;
FROM TLDOS	    IMPORT TLDOSBind;
FROM TLDR	    IMPORT TLDRBind;
FROM TLEdge	    IMPORT TLEdgeBind;
FROM TlEdits	    IMPORT TlEditsBind;
FROM TLFBase	    IMPORT TLFBaseBind;
FROM TLFForm	    IMPORT TLFFormBind;
FROM TLFileMg	    IMPORT TLFileMgBind;
FROM TLFilter	    IMPORT TLFilterBind;
FROM TLGetIt	    IMPORT TLGetItBind;
FROM TLGlue	    IMPORT TLGlueBind;
FROM TLGR	    IMPORT TLGRBind;
FROM TLHelper	    IMPORT TLHelperBind;
FROM TLHR	    IMPORT TLHRBind;
FROM TliOutLn	    IMPORT TLiOutLnBind;
FROM TLITL2	    IMPORT TLITL2Bind;
FROM TLITL3	    IMPORT TLITL3Bind;
FROM TLLayout	    IMPORT TLLayoutBind;
FROM TLLink	    IMPORT TLLinkBind;
FROM TLLoops	    IMPORT TLLoopsBind;
FROM TLMain	    IMPORT TLMainBind;
FROM TLMkBase	    IMPORT TLMkBaseBind;
FROM TLNBMat	    IMPORT TLNBMatBind;
FROM TLNBUILD	    IMPORT TLNBUILDBind;
FROM TLNCalc	    IMPORT TLNCalcBind;
FROM TLNet	    IMPORT TLNetBind;
FROM TLNetForm	    IMPORT TLNetForBind;
FROM TLNetList	    IMPORT TLNetListBind;
FROM TlNewPrj	    IMPORT TLNewPrjBind;
FROM TLNPrint	    IMPORT TLNPrintBind;
FROM TLNSHOW	    IMPORT TLNSHOWBind;
FROM TLNTREE	    IMPORT TLNTREEBind;
FROM TLPlan	    IMPORT TLPlanBind;
FROM TLPltFrm	    IMPORT TLPltFrmBind;
FROM TLPrt1D	    IMPORT TLPrt1DBind;
FROM TLPrt2D	    IMPORT TLPrt2DBind;
FROM TLPutIt	    IMPORT TLPutItBind;
FROM TLREPFOR	    IMPORT TLRepForBind;
FROM TLRHForm	    IMPORT TLRHFormBind;
FROM TLRHist	    IMPORT TLRHistBind;
FROM TlRollEm	    IMPORT TLRollEmBind;
FROM TLRPBASE	    IMPORT TLRPBASEBind;
FROM TLRPlan	    IMPORT TLRPlanBind;
FROM TLRsrc	    IMPORT TLRsrcBind;
FROM TLRTable	    IMPORT TLRTableBind;
FROM TLSchFor	    IMPORT TLSchForBind;
FROM TLSetClk	    IMPORT TLSetClkBind;
FROM TLSetPlt	    IMPORT TLSetPltBind;
FROM TLSetPrt	    IMPORT TLSetPrtBind;
FROM TLSetVideo     IMPORT TLSetVideoBind;
FROM TLSort	    IMPORT TLSortBind;
FROM TLSR	    IMPORT TLSRBind;
FROM TLStart	    IMPORT TLStartBind;
FROM TLTTable	    IMPORT TLTTableBind;
FROM TLX123	    IMPORT TLX123Bind;
FROM TLXCNFG	    IMPORT TLXCNFGBind;
FROM TLXCSV	    IMPORT TLXCSVBind;
FROM TLXDB	    IMPORT TLXDBBind;
FROM TLXDB3	    IMPORT TLXDB3Bind;
FROM TLXEdges	    IMPORT TLXEdgesBind;
FROM TLXForm	    IMPORT TLXFormBind;
FROM TLXPorts	    IMPORT TLXPortsBind;
FROM TLXPrep	    IMPORT TLXPrepBind;
FROM TLXRsAss	    IMPORT TLXRsAssBind;
FROM TLXTL3	    IMPORT TLXTL3Bind;
FROM TLXTLG	    IMPORT TLXTLGBind;

FROM Macros	    IMPORT MacrosBind;
FROM MacForm1	    IMPORT MacForm1Bind;
FROM MacSave	    IMPORT MacSaveBind;
FROM MacLoad	    IMPORT MacLoadBind;
FROM MacInst	    IMPORT MacInstBind;
FROM MacEdit	    IMPORT MacEditBind;
FROM MacSetKeys     IMPORT MacSetKeysBind;
FROM MacInit	    IMPORT MacInitBind;
FROM MacMenuForm    IMPORT MacMenuFormBind;
FROM MacMsgForm     IMPORT MacMsgFormBind;
FROM MacAuto	    IMPORT MacAutoBind;
FROM MacChain	    IMPORT MacChainBind;
FROM MacLink	    IMPORT MacLinkBind;
FROM MacAdd	    IMPORT MacAddBind;
FROM MacMenu	    IMPORT MacMenuBind;
FROM MacNest	    IMPORT MacNestBind;
FROM MacVarF	    IMPORT MacVarFBind;
FROM MacSec	    IMPORT MacSecBind;
FROM MacMenuDo	    IMPORT MacMenuDoBind;
FROM MacPick	    IMPORT MacPickBind;
FROM MacPlay	    IMPORT MacPlayBind;
FROM MacEd	    IMPORT MacEdBind;
FROM MacRec	    IMPORT MacRecBind;
************)


FROM TLMain                 IMPORT
                                TLMainBind;

FROM TLReg                  IMPORT
                                TLRegBind;

FROM TLStart                IMPORT
                                TLStartBind;

FROM TLCaption              IMPORT
                                TLCaptionBind;

FROM TLFilter               IMPORT
                                TLFilterBind;
TYPE
   BindPtr                  = ARRAY [0..9] OF CHAR;

VAR
   BindTable	            : ARRAY[0..MaxBindCount] OF BindProc;
   BindNameTable            : ARRAY[0..MaxBindCount] OF BindPtr;
   ABindProc	            : BindProc;


PROCEDURE InitBindTable ();
BEGIN

    BindTable[0] := TLMainBind;
    BindTable[1] := TLRegBind;
    BindTable[2] := TLStartBind;
    BindTable[3] := TLCaptionBind;
    BindTable[4] := TLFilterBind;

(*****************
    BindTable[0] := TL1D123Bind;
    BindTable[1] := TL2D123Bind;
    BindTable[2] := TL2FormBind;
    BindTable[3] := TLBTSMacBind;
    BindTable[4] := TLCalndrBind;
    BindTable[5] := TLChangeBind;
    BindTable[6] := TLCrBind;
    BindTable[7] := TLCrFormBind;
    BindTable[8] := TLCrWorkBind;
    BindTable[9] := TLDependBind;
    BindTable[10] := TLDir411Bind;
    BindTable[11] := TLDOSBind;
    BindTable[12] := TLDRBind;
    BindTable[13] := TLEdgeBind;
    BindTable[14] := TlEditsBind;
    BindTable[15] := TLFBaseBind;
    BindTable[16] := TLFFormBind;
    BindTable[17] := TLFileMgBind;
    BindTable[18] := TLFilterBind;
    BindTable[19] := TLGetItBind;
    BindTable[20] := TLGlueBind;
    BindTable[21] := TLGRBind;
    BindTable[22] := TLHelperBind;
    BindTable[23] := TLHRBind;
    BindTable[24] := TLiOutLnBind;
    BindTable[25] := TLITL2Bind;
    BindTable[26] := TLITL3Bind;
    BindTable[27] := TLLayoutBind;
    BindTable[28] := TLLinkBind;
    BindTable[29] := TLLoopsBind;
    BindTable[30] := MacrosBind;
    BindTable[31] := TLMainBind;
    BindTable[32] := TLMkBaseBind;
    BindTable[33] := TLNBMatBind;
    BindTable[34] := TLNBUILDBind;
    BindTable[35] := TLNCalcBind;
    BindTable[36] := TLNetBind;
    BindTable[37] := TLNetForBind;
    BindTable[38] := TLNetListBind;
    BindTable[39] := TLNewPrjBind;
    BindTable[40] := TLNPrintBind;
    BindTable[41] := TLNSHOWBind;
    BindTable[42] := TLNTREEBind;
    BindTable[43] := TLPlanBind;
    BindTable[44] := TLPltFrmBind;
    BindTable[45] := TLPrt1DBind;
    BindTable[46] := TLPrt2DBind;
    BindTable[47] := TLPutItBind;
    BindTable[48] := TLRepForBind;
    BindTable[49] := TLRHFormBind;
    BindTable[50] := TLRHistBind;
    BindTable[51] := TLRollEmBind;
    BindTable[52] := TLRPBASEBind;
    BindTable[53] := TLRPlanBind;
    BindTable[54] := TLRsrcBind;
    BindTable[55] := TLRTableBind;
    BindTable[56] := TLSchForBind;
    BindTable[57] := TLSetClkBind;
    BindTable[58] := TLSetPltBind;
    BindTable[59] := TLSetPrtBind;
    BindTable[60] := TLSetVideoBind;
    BindTable[61] := TLSortBind;
    BindTable[62] := TLSRBind;
    BindTable[63] := TLStartBind;
    BindTable[64] := TLTTableBind;
    BindTable[65] := TLX123Bind;
    BindTable[66] := TLXCNFGBind;
    BindTable[67] := TLXCSVBind;
    BindTable[68] := TLXDBBind;
    BindTable[69] := TLXDB3Bind;
    BindTable[70] := TLXEdgesBind;
    BindTable[71] := TLXFormBind;
    BindTable[72] := TLXPortsBind;
    BindTable[73] := TLXPrepBind;
    BindTable[74] := TLXRsAssBind;
    BindTable[75] := TLXTL3Bind;
    BindTable[76] := TLXTLGBind;
    BindTable[77] := MacForm1Bind;
    BindTable[78] := MacSaveBind;
    BindTable[79] := MacLoadBind;
    BindTable[80] := MacInstBind;
    BindTable[81] := MacEditBind;
    BindTable[82] := MacSetKeysBind;
    BindTable[83] := MacInitBind;
    BindTable[84] := MacMenuFormBind;
    BindTable[85] := MacMsgFormBind;
    BindTable[86] := MacAutoBind;
    BindTable[87] := MacChainBind;
    BindTable[88] := MacLinkBind;
    BindTable[89] := MacAddBind;
    BindTable[90] := MacMenuBind;
    BindTable[91] := MacNestBind;
    BindTable[92] := MacVarFBind;
    BindTable[93] := MacSecBind;
    BindTable[94] := MacMenuDoBind;
    BindTable[95] := MacPickBind;
    BindTable[96] := MacPlayBind;
    BindTable[97] := MacEdBind;
    BindTable[98] := MacRecBind;

***************************)
END InitBindTable;

PROCEDURE InitBindNameTable ();
BEGIN
    BindNameTable[0] := "TLMain";
    BindNameTable[1] := "TLReg";
    BindNameTable[2] := "TLStart";
    BindNameTable[3] := "TLCaption";
    BindNameTable[4] := "TLFilter";

(******************************
     BindNameTable[0] := "TL1D123";
     BindNameTable[1] := "TL2D123";
     BindNameTable[2] := "TL2FORM";
     BindNameTable[3] := "TLBTSMAC";
     BindNameTable[4] := "TLCALNDR";
     BindNameTable[5] := "TLCHANGE";
     BindNameTable[6] := "TLCR";
     BindNameTable[7] := "TLCRFORM";
     BindNameTable[8] := "TLCRWORK";
     BindNameTable[9] := "TLDEPEND";
     BindNameTable[10] := "TLDIR411";
     BindNameTable[11] := "TLDOS";
     BindNameTable[12] := "TLDR";
     BindNameTable[13] := "TLEDGE";
     BindNameTable[14] := "TLEDITS";
     BindNameTable[15] := "TLFBASE";
     BindNameTable[16] := "TLFFORM";
     BindNameTable[17] := "TLFILEMG";
     BindNameTable[18] := "TLFILTER";
     BindNameTable[19] := "TLGETIT";
     BindNameTable[20] := "TLGLUE";
     BindNameTable[21] := "TLGR";
     BindNameTable[22] := "TLHELPER";
     BindNameTable[23] := "TLHR";
     BindNameTable[24] := "TLIOUTLN";
     BindNameTable[25] := "TLITL2";
     BindNameTable[26] := "TLITL3";
     BindNameTable[27] := "TLLAYOUT";
     BindNameTable[28] := "TLLINK";
     BindNameTable[29] := "TLLOOPS";
     BindNameTable[30] := "MACROS";
     BindNameTable[31] := "TLMAIN";
     BindNameTable[32] := "TLMKBASE";
     BindNameTable[33] := "TLNBMAT";
     BindNameTable[34] := "TLNBUILD";
     BindNameTable[35] := "TLNCALC";
     BindNameTable[36] := "TLNET";
     BindNameTable[37] := "TLNETFOR";
     BindNameTable[38] := "TLNETLIS";
     BindNameTable[39] := "TLNEWPRJ";
     BindNameTable[40] := "TLNPRINT";
     BindNameTable[41] := "TLNSHOW";
     BindNameTable[42] := "TLNTREE";
     BindNameTable[43] := "TLPLAN";
     BindNameTable[44] := "TLPLTFRM";
     BindNameTable[45] := "TLPRT1D";
     BindNameTable[46] := "TLPRT2D";
     BindNameTable[47] := "TLPUTIT";
     BindNameTable[48] := "TLREPFOR";
     BindNameTable[49] := "TLRHFORM";
     BindNameTable[50] := "TLRHIST";
     BindNameTable[51] := "TLROLLEM";
     BindNameTable[52] := "TLRPBASE";
     BindNameTable[53] := "TLRPLAN";
     BindNameTable[54] := "TLRSRC";
     BindNameTable[55] := "TLRTABLE";
     BindNameTable[56] := "TLSCHFOR";
     BindNameTable[57] := "TLSETCLK";
     BindNameTable[58] := "TLSETPLT";
     BindNameTable[59] := "TLSETPRT";
     BindNameTable[60] := "TLSETVID";
     BindNameTable[61] := "TLSORT";
     BindNameTable[62] := "TLSR";
     BindNameTable[63] := "TLSTART";
     BindNameTable[64] := "TLTTABLE";
     BindNameTable[65] := "TLX123";
     BindNameTable[66] := "TLXCNFG";
     BindNameTable[67] := "TLXCSV";
     BindNameTable[68] := "TLXDB";
     BindNameTable[69] := "TLXDB3";
     BindNameTable[70] := "TLXEDGES";
     BindNameTable[71] := "TLXFORM";
     BindNameTable[72] := "TLXPORTS";
     BindNameTable[73] := "TLXPREP";
     BindNameTable[74] := "TLXRSASS";
     BindNameTable[75] := "TLXTL3";
     BindNameTable[76] := "TLXTLG";
     BindNameTable[77] := "MACFORM";
     BindNameTable[78] := "MACSAVE";
     BindNameTable[79] := "MACLOAD";
     BindNameTable[80] := "MACINST";
     BindNameTable[81] := "MACEDIT";
     BindNameTable[82] := "MACSETKE";
     BindNameTable[83] := "MACINIT";
     BindNameTable[84] := "MACMENUF";
     BindNameTable[85] := "MACMSGFO";
     BindNameTable[86] := "MACAUTO";
     BindNameTable[87] := "MACCHAIN";
     BindNameTable[88] := "MACLINK";
     BindNameTable[89] := "MACADD";
     BindNameTable[90] := "MACMENU";
     BindNameTable[91] := "MACNEST";
     BindNameTable[92] := "MACVARF";
     BindNameTable[93] := "MACSEC";
     BindNameTable[94] := "MACMENUD";
     BindNameTable[95] := "MACPICK";
     BindNameTable[96] := "MACPLAY";
     BindNameTable[97] := "MACED";
     BindNameTable[98] := "MACREC";
*************************)


END InitBindNameTable;

PROCEDURE ExecuteBindProc(VAR BindName : ARRAY OF CHAR);

VAR 
    CompareVal              : INTEGER;
    i	                    : CARDINAL;

BEGIN
     i := 0;

     REPEAT
        CompareVal := CompareStr(BindNameTable[i], BindName);

        IF ( CompareVal = 0 ) THEN
	        ABindProc := BindTable[i];
	        ABindProc ();
	        RETURN;
        END;

        INC(i);
     UNTIL ( i >= MaxBindCount );

END ExecuteBindProc;

(*******************
PROCEDURE AltExecuteBindProc( VAR BindName : ARRAY OF CHAR; MaxCount : CARDINAL );
VAR CompareVal : INTEGER;
VAR i	       : CARDINAL;
BEGIN
     i := 0;
     REPEAT
       CompareVal := CompareStr ( BindNameTable[i], BindName );
       IF ( CompareVal = 0 ) THEN
	  ABindProc := BindTable[i];
	  ABindProc ();
	  RETURN;
       END;
       INC(i);
     UNTIL ( i >= MaxCount );
END AltExecuteBindProc;

*******************)

PROCEDURE BindInit();

BEGIN (* Procedure BindInit *)

    InitBindTable();
    InitBindNameTable();

END BindInit;

END Bind.
