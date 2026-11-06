namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Telemetry abstraction. Every dimension recorded here must be technical metadata (codes,
/// counters, durations) - NEVER a CNPJ, NF-e key, token, secret or signed URL (RN03/ADR-08
/// of the specification). It also records the event in CBS Log Entry for querying inside
/// Business Central itself.
/// </summary>
codeunit 50131 "CBS Telemetry"
{
    Access = Internal;

    var
        CategoryLbl: Label 'CBS', Locked = true;

    procedure CollectionEvent(Correlation: Text[50]; MessageText: Text[250])
    begin
        Register("CBS Log Category"::Collection, "CBS Log Severity"::Normal, 'CBS-COLLECTION', MessageText, Correlation);
    end;

    procedure ImportEvent(Correlation: Text[50]; MessageText: Text[250])
    begin
        Register("CBS Log Category"::Import, "CBS Log Severity"::Normal, 'CBS-IMPORT', MessageText, Correlation);
    end;

    procedure ReconciliationEvent(Correlation: Text[50]; MessageText: Text[250])
    begin
        Register("CBS Log Category"::Reconciliation, "CBS Log Severity"::Normal, 'CBS-RECONCILIATION', MessageText, Correlation);
    end;

    procedure WarningEvent(Category: Enum "CBS Log Category"; Correlation: Text[50]; MessageText: Text[250])
    begin
        Register(Category, "CBS Log Severity"::Warning, 'CBS-WARNING', MessageText, Correlation);
    end;

    procedure ErrorEvent(Category: Enum "CBS Log Category"; Correlation: Text[50]; MessageText: Text[250])
    begin
        Register(Category, "CBS Log Severity"::Error, 'CBS-ERROR', MessageText, Correlation);
    end;

    local procedure Register(Category: Enum "CBS Log Category"; Severity: Enum "CBS Log Severity"; EventId: Text[100]; MessageText: Text[250]; Correlation: Text[50])
    var
        LogEntry: Record "CBS Log Entry";
        Dimensions: Dictionary of [Text, Text];
    begin
        LogEntry.Init();
        LogEntry."Date Time" := CurrentDateTime();
        LogEntry."User Id" := CopyStr(UserId(), 1, 50);
        LogEntry.Category := Category;
        LogEntry.Severity := Severity;
        LogEntry."Event" := CopyStr(EventId, 1, 100);
        LogEntry."Message" := MessageText;
        LogEntry.Correlation := Correlation;
        LogEntry.Insert();

        Dimensions.Add('Category', CategoryLbl);
        Dimensions.Add('Category2', Format(Category));
        Dimensions.Add('Severity', Format(Severity));
        Dimensions.Add('Correlation', Correlation);
        Session.LogMessage(EventId, MessageText, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;
}
