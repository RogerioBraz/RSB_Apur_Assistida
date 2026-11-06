namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Severity of the event recorded in CBS Log Entry.
/// </summary>
enum 50144 "CBS Log Severity"
{
    Extensible = false;
    Access = Internal;
    Caption = 'CBS Log Severity';

    value(0; Normal)
    {
        Caption = 'Normal';
    }
    value(1; Warning)
    {
        Caption = 'Warning';
    }
    value(2; Error)
    {
        Caption = 'Error';
    }
    value(3; Critical)
    {
        Caption = 'Critical';
    }
}
