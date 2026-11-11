namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Read-only profile: management, audit and anyone who only consults the panel, the debt list
/// and the reconciliation trail. Cannot run anything that changes data (no Execute on the
/// collection or reconciliation codeunits).
/// </summary>
permissionset 50180 "CBS Leitura"
{
    Assignable = true;
    Caption = 'CBS Leitura';

    Permissions =
        tabledata "CBS Setup" = R,
        tabledata "CBS Credential" = R,
        tabledata "CBS Request" = R,
        tabledata "CBS File" = R,
        tabledata "CBS Debt" = R,
        tabledata "CBS Reconciliation" = R,
        tabledata "CBS Batch" = R,
        tabledata "CBS Coverage" = R,
        tabledata "CBS Log Entry" = R,
        tabledata "CBS Fiscal History Buffer" = R,

        page "CBS Setup Card" = X,
        page "CBS Panel" = X,
        page "CBS Debt List" = X,
        page "CBS Reconciliation List" = X,
        page "CBS Request List" = X,
        page "CBS Credential List" = X,

        codeunit "CBS Exporter" = X;
}
