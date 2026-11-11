namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Execution environment towards the Brazilian Revenue Service (Receita Federal). Fixed
/// (not extensible): the distinction between Production and Restricted Production is a
/// strict security rule (see spec section 4.4/12) and must not be widened by partner
/// extensions.
/// </summary>
enum 50117 "CBS Environment Type"
{
    Extensible = false;
    // Public because it is part of the ICbsFiscalHistory signature: a partner adapter in
    // another module must be able to declare the Environment parameter.
    Access = Public;
    Caption = 'CBS Environment';

    value(0; Production)
    {
        Caption = 'Production';
    }
    value(1; RestrictedProduction)
    {
        Caption = 'Restricted Production (Sandbox)';
    }
}
