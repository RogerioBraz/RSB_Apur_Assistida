namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Administration profile: configures Setup and Credential (including the secret, which is
/// written to Isolated Storage and never read back as text), maintains the Job Queue and can
/// purge data. Separated from the operational profile on purpose: whoever configures the
/// credential is not necessarily who runs the collection (separation of duties, spec 12.4).
/// </summary>
permissionset 50182 "CBS Admin"
{
    Assignable = true;
    Caption = 'CBS Admin';

    Permissions =
        tabledata "CBS Setup" = RIMD,
        tabledata "CBS Credential" = RIMD,
        tabledata "CBS Request" = RIMD,
        tabledata "CBS File" = RIMD,
        tabledata "CBS Debt" = RIMD,
        tabledata "CBS Reconciliation" = RIMD,
        tabledata "CBS Batch" = RIMD,
        tabledata "CBS Coverage" = RIMD,
        tabledata "CBS Log Entry" = RIMD,
        tabledata "CBS Fiscal History Buffer" = RIMD,

        page "CBS Setup Card" = X,
        page "CBS Panel" = X,
        page "CBS Debt List" = X,
        page "CBS Reconciliation List" = X,
        page "CBS Request List" = X,
        page "CBS Credential List" = X,
        page "CBS Credential Card" = X,
        page "CBS Reverse Lookup Request" = X,

        codeunit "CBS Job Queue Dispatcher" = X,
        codeunit "CBS Collection Orchestrator" = X,
        codeunit "CBS Reconciliation Engine" = X,
        codeunit "CBS Reverse Lookup" = X,
        codeunit "CBS Exporter" = X,
        codeunit "CBS Adapter Factory" = X,
        codeunit "CBS Default Adapter" = X,
        codeunit "CBS Tax Authority Connector" = X,
        codeunit "CBS JSON Importer" = X,
        codeunit "CBS Batch Publisher" = X,
        codeunit "CBS Telemetry" = X,
        codeunit "CBS Url Helper" = X,
        codeunit "CBS Demo Data Loader" = X;
}
