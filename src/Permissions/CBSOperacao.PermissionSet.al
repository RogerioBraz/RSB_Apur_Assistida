namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Operational profile: the fiscal user. Runs collection cycles, reconciles debts, runs the
/// reverse lookup and exports results. Reads Setup and Credential but does not change them -
/// configuration belongs to the admin profile.
/// </summary>
permissionset 50181 "CBS Operacao"
{
    Assignable = true;
    Caption = 'CBS Operação';

    Permissions =
        tabledata "CBS Setup" = R,
        tabledata "CBS Credential" = R,
        tabledata "CBS Request" = RIMD,
        tabledata "CBS File" = RIMD,
        tabledata "CBS Debt" = RIMD,
        tabledata "CBS Reconciliation" = RIMD,
        tabledata "CBS Batch" = RIMD,
        tabledata "CBS Coverage" = RIMD,
        tabledata "CBS Log Entry" = RI,
        tabledata "CBS Fiscal History Buffer" = R,

        page "CBS Setup Card" = X,
        page "CBS Panel" = X,
        page "CBS Debt List" = X,
        page "CBS Reconciliation List" = X,
        page "CBS Request List" = X,
        page "CBS Credential List" = X,
        page "CBS Reverse Lookup Request" = X,

        codeunit "CBS Job Queue Dispatcher" = X,
        codeunit "CBS Collection Orchestrator" = X,
        codeunit "CBS Reconciliation Engine" = X,
        codeunit "CBS Reverse Lookup" = X,
        codeunit "CBS Exporter" = X,
        codeunit "CBS Adapter Factory" = X,
        codeunit "CBS Default Adapter" = X;
}
