IMPLEMENTATION MODULE NetworkData;

    (* MODIFICATION HISTORY
        28-Jan-89 KKC   Initialize CurrentActiveView.
    *)

BEGIN                       (* NetStatic *)
    CurrentActiveView := NotPertview;
    AnnealingChoice := Average;      (* This is a kludge!!!  remove *)
    NetworkType     := Conventional; (* and put into TLStart!!!  WKH *)
END NetworkData.

