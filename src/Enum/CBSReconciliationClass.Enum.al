namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Classification of the reconciliation result between a CBS debt and the fiscal history
/// (see spec section 6.9/8.5). Extensible so that localization partners can add their own
/// classifications without changing the core.
/// </summary>
enum 50114 "CBS Reconciliation Class."
{
    Extensible = true;
    Access = Internal;
    Caption = 'CBS Reconciliation Classification';

    value(0; Reconciled)
    {
        Caption = 'Reconciled';
    }
    value(1; Divergent)
    {
        Caption = 'Divergent';
    }
    value(2; Adjustment)
    {
        Caption = 'Adjustment (internal item vs. total divergence)';
    }
    value(3; NoteWithoutDebt)
    {
        Caption = 'Note without Matching Debt';
    }
    value(4; DebtWithoutNote)
    {
        Caption = 'Debt without Matching Note';
    }
    value(5; NoDeclaredCbs)
    {
        Caption = 'Matched Note without Declared CBS';
    }
    value(6; NoAdapter)
    {
        Caption = 'No Fiscal History Adapter Linked';
    }
    value(7; NotApplicableDFe)
    {
        Caption = 'Not Applicable (document is not NF-e)';
    }
}
