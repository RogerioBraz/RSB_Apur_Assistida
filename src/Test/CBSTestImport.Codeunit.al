namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Unit tests for the JSON importer (spec 9.3, T01/T07/T08/T14 subset) that do not need a
/// live API: period conversion, envelope traversal, leading-zero month, empty assessment and
/// natural-key collision preservation.
///
/// The importer reads from CBS File, so each test writes a small fixture into a File record
/// and imports it inside its own batch.
/// </summary>
codeunit 50171 "CBS Test Import"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure PeriodWithLeadingZeroIsConvertedToOneDayOfMonth()
    var
        Importer: Codeunit "CBS JSON Importer";
        CBSFile: Record "CBS File";
        Batch: Record "CBS Batch";
        Debt: Record "CBS Debt";
        Imported: Integer;
        Divergent: Integer;
        Invalid: Integer;
    begin
        // [GIVEN] a file whose only assessment period is "09/2026"
        CreateFileWithJson(CBSFile, '{"ni":"11222333","apuracao":[{"pa":"09/2026","debitos":[{"origem":0,"documento":55,"chave":"K-09","cbs":{"apurado":80.00,"saldoDevedor":40.00}}]}]}');
        CreateBatch(Batch, 'TESTE-09');

        // [WHEN] imported
        Importer.ImportFile(CBSFile, Enum::"CBS Environment Type"::RestrictedProduction, Batch, 0, Imported, Divergent, Invalid);

        // [THEN] one debt on the first day of September 2026
        AssertEquals(1, Imported, 'Expected one imported debt.');
        Debt.SetRange("Access Key", 'K-09');
        AssertTrue(Debt.FindFirst(), 'Debt K-09 not found.');
        AssertEquals(Format(DMY2Date(1, 9, 2026)), Format(Debt.Period), 'Period should be 01/09/2026.');
    end;

    [Test]
    procedure EmptyAssessmentImportsNothingAndDoesNotFail()
    var
        Importer: Codeunit "CBS JSON Importer";
        CBSFile: Record "CBS File";
        Batch: Record "CBS Batch";
        Imported: Integer;
        Divergent: Integer;
        Invalid: Integer;
    begin
        // [GIVEN] the official "no debts in the window" shape
        CreateFileWithJson(CBSFile, '{"ni":"11222333","apuracao":[]}');
        CreateBatch(Batch, 'TESTE-VAZIO');

        // [WHEN] imported
        Importer.ImportFile(CBSFile, Enum::"CBS Environment Type"::RestrictedProduction, Batch, 0, Imported, Divergent, Invalid);

        // [THEN] nothing imported, nothing invalid (this is a valid answer, not an error)
        AssertEquals(0, Imported, 'Expected no imported debt.');
        AssertEquals(0, Invalid, 'Empty assessment is not an invalid record.');
    end;

    [Test]
    procedure MultiplePeriodsInTheSameFileAreBothImported()
    var
        Importer: Codeunit "CBS JSON Importer";
        CBSFile: Record "CBS File";
        Batch: Record "CBS Batch";
        DebtA: Record "CBS Debt";
        DebtB: Record "CBS Debt";
        Imported: Integer;
        Divergent: Integer;
        Invalid: Integer;
    begin
        // [GIVEN] the official example shape: two periods in one file
        CreateFileWithJson(CBSFile, '{"ni":"11222333","apuracao":[{"pa":"06/2026","debitos":[{"origem":0,"documento":55,"chave":"K-06","cbs":{"apurado":80.00}}]},{"pa":"08/2026","debitos":[{"origem":0,"documento":55,"chave":"K-08","cbs":{"apurado":40.00}}]}]}');
        CreateBatch(Batch, 'TESTE-MULTI');

        // [WHEN] imported
        Importer.ImportFile(CBSFile, Enum::"CBS Environment Type"::RestrictedProduction, Batch, 0, Imported, Divergent, Invalid);

        // [THEN] both periods are present
        AssertEquals(2, Imported, 'Expected two imported debts.');
        DebtA.SetRange("Access Key", 'K-06');
        DebtB.SetRange("Access Key", 'K-08');
        AssertTrue(DebtA.FindFirst() and DebtB.FindFirst(), 'Both periods should be imported.');
    end;

    [Test]
    procedure MissingRequiredFieldsAreCountedAsInvalidNotAsFailure()
    var
        Importer: Codeunit "CBS JSON Importer";
        CBSFile: Record "CBS File";
        Batch: Record "CBS Batch";
        Imported: Integer;
        Divergent: Integer;
        Invalid: Integer;
    begin
        // [GIVEN] one good debt and one with an unknown document type
        CreateFileWithJson(CBSFile, '{"ni":"11222333","apuracao":[{"pa":"10/2026","debitos":[{"origem":0,"documento":55,"chave":"K-OK","cbs":{"apurado":10.00}},{"origem":0,"documento":999,"chave":"K-RUIM","cbs":{"apurado":20.00}}]}]}');
        CreateBatch(Batch, 'TESTE-INV');

        // [WHEN] imported
        Importer.ImportFile(CBSFile, Enum::"CBS Environment Type"::RestrictedProduction, Batch, 0, Imported, Divergent, Invalid);

        // [THEN] the good one is imported and the bad one is only counted, never aborting
        AssertEquals(1, Imported, 'Expected one imported debt.');
        AssertEquals(1, Invalid, 'Expected one invalid record.');
    end;

    [Test]
    procedure NaturalKeyCollisionPreservesTheOriginalInACollection()
    var
        Importer: Codeunit "CBS JSON Importer";
        CBSFile: Record "CBS File";
        Batch1: Record "CBS Batch";
        Batch2: Record "CBS Batch";
        Debt: Record "CBS Debt";
        Imported: Integer;
        Divergent: Integer;
        Invalid: Integer;
    begin
        // [GIVEN] the same natural key imported twice by two collection batches
        CreateFileWithJson(CBSFile, '{"ni":"11222333","apuracao":[{"pa":"10/2026","debitos":[{"origem":0,"documento":55,"chave":"K-DUP","cbs":{"apurado":100.00},"atualizacao":"2026-10-01T10:00:00Z"}]}]}');
        CreateBatch(Batch1, 'TESTE-DUP1');
        Importer.ImportFile(CBSFile, Enum::"CBS Environment Type"::RestrictedProduction, Batch1, 0, Imported, Divergent, Invalid);
        AssertEquals(1, Imported, 'First import should insert.');

        CreateBatch(Batch2, 'TESTE-DUP2');
        Batch1.Reset();
        Imported := 0;
        Divergent := 0;
        Importer.ImportFile(CBSFile, Enum::"CBS Environment Type"::RestrictedProduction, Batch2, 0, Imported, Divergent, Invalid);

        // [THEN] the second import does not overwrite: it is recorded as a divergence
        AssertEquals(0, Imported, 'A collection must not overwrite an existing debt.');
        AssertEquals(1, Divergent, 'The collision should be counted as divergent.');
        Debt.SetRange("Access Key", 'K-DUP');
        AssertEquals(1, Debt.Count(), 'There must still be exactly one debt.');
    end;

    local procedure CreateFileWithJson(var CBSFile: Record "CBS File"; JsonText: Text)
    var
        OutStr: OutStream;
        InStr: InStream;
    begin
        CBSFile.Init();
        CBSFile."Received On" := CurrentDateTime();
        CBSFile.Insert(true);
        Clear(CBSFile.Content);
        CBSFile.Content.CreateOutStream(OutStr);
        OutStr.WriteText(JsonText);
        CBSFile.Content.CreateInStream(InStr);
        CBSFile.SetContent(InStr);
        CBSFile.Modify(true);
    end;

    local procedure CreateBatch(var Batch: Record "CBS Batch"; Code: Code[20])
    begin
        if Batch.Get(Code) then
            exit;
        Batch.Init();
        Batch.Code := Code;
        Batch.Type := Batch.Type::Collection;
        Batch."Started On" := CurrentDateTime();
        Batch.Insert(true);
    end;

    local procedure AssertEquals(Expected: Text; Actual: Text; Message: Text)
    var
        AssertTextFailedErr: Label 'Assert failed: %1 Expected %2, actual %3.', Comment = '%1 = message, %2 = expected, %3 = actual';
    begin
        if Expected <> Actual then
            Error(AssertTextFailedErr, Message, Expected, Actual);
    end;

    local procedure AssertEquals(Expected: Integer; Actual: Integer; Message: Text)
    var
        AssertIntFailedErr: Label 'Assert failed: %1 Expected %2, actual %3.', Comment = '%1 = message, %2 = expected, %3 = actual';
    begin
        if Expected <> Actual then
            Error(AssertIntFailedErr, Message, Format(Expected), Format(Actual));
    end;

    local procedure AssertTrue(Condition: Boolean; Message: Text)
    var
        AssertFailedErr: Label 'Assert failed: %1', Comment = '%1 = message';
    begin
        if not Condition then
            Error(AssertFailedErr, Message);
    end;
}
