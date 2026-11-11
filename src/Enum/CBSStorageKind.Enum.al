namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Where the content of a CBS File record is actually stored.
/// </summary>
enum 50141 "CBS Storage Kind"
{
    Extensible = false;
    Access = Internal;
    Caption = 'CBS Storage Kind';

    value(0; Blob)
    {
        Caption = 'Blob (table field)';
    }
    value(1; External)
    {
        Caption = 'External Reference';
    }
    value(2; Purged)
    {
        Caption = 'Purged (retention window elapsed)';
    }
}
