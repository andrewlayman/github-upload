IMPLEMENTATION MODULE FlexDisp;


FROM LStrings IMPORT
    (* PROC *)      SetString, ConcatS, ConcatLS, CtoS, Procustes,
                    Overlay, Fill, Copy, Remove, Insert, SetLengthOf,
                    LengthOf;

FROM FlexStor       IMPORT AnExtHandle;


FROM FlexData IMPORT
          MaxPages, MaxDataSize,
          MaxUserRecordsPerPage, MaxRecordsPerPage, MaxRecordSize,
          MaxGeneration, AHandlesInternals, ACellNo,
          APageNo, ARecordNo, ACellInfo, ACellBlock, CellBlockTable,
          ACellBlockNumber, TopCellBlock, MaxCellPerBlock,
          ACellPointer, APageSet, APageIndexArray, APageHeader, BPBS,
          APage, APagePointer, APageInfo, APageTable,
          PageTable,
          Quantity;


FROM PageSupply IMPORT
    (* TYPE *)      APageClass, APageHandle,
    (* PROC *)      CreatePage, DiscardPage, RetrievePage,
                    SynchPage,
                    StartupPageClass, ShutdownPageClass;

FROM SYSTEM  IMPORT
    (* TYPE *)      BYTE, TSIZE, SIZE, ADDRESS, ADR, CODE;


PROCEDURE CtoH     (Card:CARDINAL; VAR String:ARRAY OF CHAR);
CONST
    RADIX = 16;
    Size  = 4;
VAR
    i,j,k : CARDINAL;
BEGIN
    j := Size;
    REPEAT
        k := Card MOD RADIX;
        IF (k < 10) THEN
            String[j] := CHR(ORD("0")+k);
        ELSE
            String[j] := CHR(ORD("A")+(k-10));
        END;
        Card := Card DIV RADIX;
        DEC(j);
    UNTIL (j = 0);
    String[0] := CHR(Size);
END CtoH;

PROCEDURE AtoS( A : ADDRESS; VAR S : ARRAY OF CHAR);
VAR
    S2  : ARRAY [0..40] OF CHAR;
BEGIN
    CtoH(A.SEGMENT,S);
    ConcatS(S,":");
    CtoH(A.OFFSET,S2);
    ConcatLS(S,S2);
END AtoS;


PROCEDURE HAToString( A : ADDRESS; VAR S : ARRAY OF CHAR);
VAR
    S2  : ARRAY [0..40] OF CHAR;
BEGIN
    CtoH(A.SEGMENT,S);
    CtoH(A.OFFSET MOD 16,S2);
    Remove(S2,1,3);
    ConcatLS(S,S2);
    ConcatS(S,".");
    CtoH(A.OFFSET DIV 256,S2);
    Remove(S2,1,2);
    ConcatLS(S,S2);
END HAToString;




PROCEDURE HandleToString( H : AnExtHandle; VAR S : ARRAY OF CHAR );
BEGIN
    HAToString(ADDRESS(H),S);
END HandleToString;






END FlexDisp.
