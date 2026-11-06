namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Local state machine of the collection cycle for a request (see spec section 7.1/3.7). It
/// is distinct from the state reported by the API (CBS Remote State); the local state
/// reflects what the extension knows and has decided to do next.
/// </summary>
enum 50112 "CBS Local State"
{
    Extensible = false;
    Access = Internal;
    Caption = 'CBS Local State';

    value(0; Open)
    {
        Caption = 'Open';
    }
    value(1; WaitingProcessing)
    {
        Caption = 'Waiting Processing';
    }
    value(2; FileAvailable)
    {
        Caption = 'File Available for Download';
    }
    value(3; FileSaved)
    {
        Caption = 'File Saved';
    }
    value(4; Published)
    {
        Caption = 'Published';
    }
    value(5; TransientError)
    {
        Caption = 'Transient Error';
    }
    value(6; DefinitiveError)
    {
        Caption = 'Definitive Error';
    }
    value(7; ExpiredProcessing)
    {
        Caption = 'Expired - Processing';
    }
    value(8; ExpiredFile)
    {
        Caption = 'Expired - File';
    }
    value(9; Cancelled)
    {
        Caption = 'Cancelled';
    }
}
