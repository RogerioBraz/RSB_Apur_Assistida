namespace RSB.ApurAssistida.CBS;

/// <summary>
/// CBS service of the Assisted Assessment API. The MVP implements only Debts; the other
/// values exist for the extensibility planned for phase 3 (credits, payments, settlements),
/// but have no collection routine implemented yet.
/// </summary>
enum 50120 "CBS Service"
{
    Extensible = true;
    Access = Internal;
    Caption = 'CBS Service';

    value(0; Debts)
    {
        Caption = 'Debts';
    }
    value(1; Credits)
    {
        Caption = 'Credits (phase 3 - not implemented)';
    }
    value(2; Payments)
    {
        Caption = 'Payments (phase 3 - not implemented)';
    }
    value(3; Settlements)
    {
        Caption = 'Settlements (phase 3 - not implemented)';
    }
}
