namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Selects the ICbsFiscalHistory implementation used by the company. Extensible: a
/// localization partner adds a new value pointing to its own codeunit, without changing a
/// single line of the core (Service Binding Interface pattern). The default value "No Link"
/// guarantees that the factory never fails due to missing configuration (see CBS Adapter
/// Factory).
/// </summary>
enum 50111 "CBS Fiscal History Adapter" implements "ICbsFiscalHistory"
{
    Extensible = true;
    Access = Public;
    Caption = 'CBS Fiscal History Adapter';
    DefaultImplementation = "ICbsFiscalHistory" = "CBS Default Adapter";

    value(0; NoLink)
    {
        Caption = 'No Link (default)';
        Implementation = "ICbsFiscalHistory" = "CBS Default Adapter";
    }
}
