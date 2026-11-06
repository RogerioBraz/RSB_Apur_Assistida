namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Resolves the ICbsFiscalHistory implementation configured in CBS Setup. Since the enum
/// "CBS Fiscal History Adapter" has a DefaultImplementation, assigning an enum value to an
/// Interface variable never fails - even without configuration, the result is the default
/// (no link) adapter, guaranteeing that reconciliation always has a valid implementation to
/// call (RF09: missing adapter raises a warning, not a fatal error).
/// </summary>
codeunit 50129 "CBS Adapter Factory"
{
    Access = Internal;

    procedure CreateAdapter(): Interface "ICbsFiscalHistory"
    var
        Setup: Record "CBS Setup";
        Adapter: Interface "ICbsFiscalHistory";
    begin
        Setup.GetSetup(Setup);
        Adapter := Setup."Fiscal History Adapter";
        exit(Adapter);
    end;
}
