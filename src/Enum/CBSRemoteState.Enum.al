namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Local mirror of the status reported by the Revenue Service API for the request ticket.
/// </summary>
enum 50113 "CBS Remote State"
{
    Extensible = false;
    Access = Internal;
    Caption = 'CBS Remote State';

    value(0; Unknown)
    {
        Caption = 'Unknown';
    }
    value(1; Pending)
    {
        Caption = 'Pending';
    }
    value(2; Processing)
    {
        Caption = 'Processing';
    }
    value(3; Completed)
    {
        Caption = 'Completed';
    }
    value(4; Error)
    {
        Caption = 'Error';
    }
    value(5; Expired)
    {
        Caption = 'Expired';
    }
}
