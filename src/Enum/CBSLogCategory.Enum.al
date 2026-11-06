namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Category of the event recorded in CBS Log Entry, used to filter the log by area.
/// </summary>
enum 50143 "CBS Log Category"
{
    Extensible = false;
    Access = Internal;
    Caption = 'CBS Log Category';

    value(0; Collection)
    {
        Caption = 'Collection';
    }
    value(1; Import)
    {
        Caption = 'Import';
    }
    value(2; Reconciliation)
    {
        Caption = 'Reconciliation';
    }
    value(3; Configuration)
    {
        Caption = 'Configuration';
    }
    value(4; Security)
    {
        Caption = 'Security';
    }
}
