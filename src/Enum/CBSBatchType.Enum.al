namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Type of publication batch (see ADR-04/5.5 of the specification: atomic batch
/// publication).
/// </summary>
enum 50142 "CBS Batch Type"
{
    Extensible = false;
    Access = Internal;
    Caption = 'CBS Batch Type';

    value(0; Collection)
    {
        Caption = 'Collection';
    }
    value(1; Republication)
    {
        Caption = 'Republication';
    }
    value(2; BatchReconciliation)
    {
        Caption = 'Batch Reconciliation';
    }
}
