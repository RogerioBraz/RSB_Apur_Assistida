namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Publishes the content of a CBS File into CBS Debt atomically (ADR-04): the batch is only
/// marked Published=true in a single final transaction, after the whole import has finished
/// without error. If the import fails for any reason, the batch remains unpublished and the
/// panel continues to see only the last previously published batch (RF07). Idempotency by
/// file hash (RF05/RN02) is checked before reprocessing.
/// </summary>
codeunit 50136 "CBS Batch Publisher"
{
    Access = Internal;

    var
        Telemetry: Codeunit "CBS Telemetry";
        FileAlreadyPublishedMsg: Label 'File already imported previously (hash %1); nothing to do.', Comment = '%1 = file hash';
        BatchPublishedMsg: Label 'Batch %1 published: %2 imported, %3 divergent (collision), %4 invalid.', Comment = '%1 = batch code, %2/%3/%4 = counts';

    /// <summary>Publishes a freshly downloaded file as a batch of type Collection.</summary>
    procedure PublishCollection(var Request: Record "CBS Request"; var CBSFile: Record "CBS File"): Code[20]
    begin
        exit(Publish(Request, CBSFile, "CBS Batch Type"::Collection));
    end;

    /// <summary>Intentionally republishes an already saved file (flow 7.2): natural key collisions are replaced.</summary>
    procedure RepublishFile(var Request: Record "CBS Request"; var CBSFile: Record "CBS File"): Code[20]
    begin
        exit(Publish(Request, CBSFile, "CBS Batch Type"::Republication));
    end;

    local procedure Publish(var Request: Record "CBS Request"; var CBSFile: Record "CBS File"; Type: Enum "CBS Batch Type"): Code[20]
    var
        Batch: Record "CBS Batch";
        DebtMarker: Record "CBS Debt";
        BatchCode: Code[20];
        RecordsImported: Integer;
        RecordsDivergent: Integer;
        RecordsInvalid: Integer;
    begin
        BatchCode := BatchCodeFor(Request, CBSFile);

        if Batch.Get(BatchCode) then begin
            if Batch.Published then begin
                Telemetry.ImportEvent(Batch."Code", StrSubstNo(FileAlreadyPublishedMsg, CBSFile.Hash));
                exit(Batch."Code");
            end;
        end else begin
            Batch.Init();
            Batch."Code" := BatchCode;
            Batch."Request Entry No" := Request."Entry No";
            Batch.Type := Type;
            Batch."File Hash" := CBSFile.Hash;
            Batch."Started On" := CurrentDateTime();
            Batch.Insert();
        end;

        if not TryImport(CBSFile, Request.Environment, Batch, Request."Entry No", RecordsImported, RecordsDivergent, RecordsInvalid) then begin
            Batch."Error Text" := CopyStr(GetLastErrorText(), 1, 250);
            Batch."Ended On" := CurrentDateTime();
            Batch.Modify();
            Telemetry.ErrorEvent("CBS Log Category"::Import, Batch."Code", Batch."Error Text");
            exit(Batch."Code"); // remains UNPUBLISHED (ADR-04): panel unchanged
        end;

        // Single final transaction: no Commit() happened inside the import loop (it runs
        // entirely inside TryImport); the Published flag is only written here. The debts of
        // this batch become visible at the same instant as the batch itself (ADR-04).
        DebtMarker.SetRange("Batch Code", Batch."Code");
        DebtMarker.ModifyAll(Published, true);

        Batch.Published := true;
        Batch."Published On" := CurrentDateTime();
        Batch."Ended On" := CurrentDateTime();
        Batch.Records := RecordsImported;
        Batch.Modify();

        CBSFile.Processed := true;
        CBSFile.Modify();
        Commit();

        Telemetry.ImportEvent(Batch."Code", StrSubstNo(BatchPublishedMsg, Batch."Code", RecordsImported, RecordsDivergent, RecordsInvalid));
        exit(Batch."Code");
    end;

    [TryFunction]
    local procedure TryImport(var CBSFile: Record "CBS File"; Environment: Enum "CBS Environment Type"; Batch: Record "CBS Batch"; RequestEntryNo: Integer; var RecordsImported: Integer; var RecordsDivergent: Integer; var RecordsInvalid: Integer)
    var
        Importer: Codeunit "CBS JSON Importer";
    begin
        Importer.ImportFile(CBSFile, Environment, Batch, RequestEntryNo, RecordsImported, RecordsDivergent, RecordsInvalid);
    end;

    local procedure BatchCodeFor(Request: Record "CBS Request"; CBSFile: Record "CBS File"): Code[20]
    begin
        exit(CopyStr(StrSubstNo('L%1-%2', Request."Entry No", CopyStr(CBSFile.Hash, 1, 8)), 1, 20));
    end;
}
