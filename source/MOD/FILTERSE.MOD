(*V1=NORMAL Version*)
(*V8=GELDED Version for debugging*)

IMPLEMENTATION MODULE FilterSelect;

    (* MODIFICATION HISTORY:

    5/6/87 EGK      Many changes (mostly deletions) to re-implement the
                    filter list using object-oriented scheme.  Moved
                    CreateFilter and DeleteFilter to FilterOutlines module,
                    removed ForAllFilters and the internal SelectFilterNames
                    module, and re-coded SelectFilterName and SortFilters to
                    use the new filter list object.

    5/7/87 EGK      Minor changes to fix problems with phrase file numbers.

    01-Jun-87 LAA   Recoded MustFind to use the new methods of TreeObjects
                    instead of FindTask, which is no longer in Allocs.
    7/6/87  EGK     Replaced DoFilterNamesForm with ChooseFilter, which uses
                    a menu.
    7/9/87  EGK     The user-selected highlight filter is now Highlight1,
                    since we now have a total of four highlight filters.
    22-Sep-87 LAA   Incorporated form changes proposed by DSB, and in process
                    added field number constants and consolidated code.
    15-Oct-87 RSC   Added Shadows to boxes.  Added parameter to EditText.
    19-Oct-87 EGK   Call ResetMatching when filter list is put up.
    28-Oct-87 RSC   Notify forms when text has been edited.
    05-Nov-87 LAA   Fixed bug under which Shift-F8 acted like F2 on the notes
                    field.
    06-Nov-87 RSC   ljust wbs, obs, and notes.
    18-Dec-87 EGK   Moved DoFilterForm into TLFILTER overlay.
    23-Dec-87 LAA   Fixed DoFilterForm to return CancelKey if there's any
                    problem with the overlay.
    02-Mar-88 LAA   Forced TLFBASE to load on the heap, not in reserved layer.
    05-Mar-88 LAA   Pass this module's module number as the help number.
    31-Oct-88 EGK   Put up a message after clearing select filter.
    23-Jan-89 EGK   Moved ChooseFilter into TLFSELCT overlay.
    *)



FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskFilter;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Keys                   IMPORT
    (* CONST *)                 DoIt, CancelKey, ExitKey, InsertKey, DeleteKey,
                                EditKey, BackSpace, CopyKey;

FROM LStrings               IMPORT
    (* PROC *)                  SubStr, Fill, Compare, TrimRear, LJust, Copy,
                                ConcatLS, TrimFront, Upshift, Remove, Search,
                                Procustes, SetLengthOf, LengthOf, SetString;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTree;


CONST
    ModuleNumber            = 17100;




(*<NORMAL*)





PROCEDURE DoFilterForm ( Filter : ATreeNode)
                                            : ACode;

VAR
    PrivateOverlayContext       : AnOverlayContext;
    OverlayName                 : ARRAY [0..20] OF CHAR;
    Result                      : ACode;

BEGIN

    PrivateOverlayContext.FilterNode := Filter;
    PrivateOverlayContext.ReturnCode := CancelKey;
    SetString (OverlayName, "\TLFBASE(TLFLTFRM)");                (* 02-Mar-88 LAA *)

    IF (CallOverlayWithContext (OverlayName, ADR(PrivateOverlayContext))) THEN
    END;

    RETURN PrivateOverlayContext.ReturnCode;

END DoFilterForm;





PROCEDURE ChooseFilter ( Variety    : ATaskFilter);

VAR
    OverlayName                 : ARRAY [0..20] OF CHAR;
    Result                      : BOOLEAN;

BEGIN

    SetString (OverlayName, "TLFSELCT");
    Result := CallOverlayWithContext (OverlayName, ADR(Variety));

END ChooseFilter;



BEGIN                       (* FilterSelect *)
END FilterSelect.
