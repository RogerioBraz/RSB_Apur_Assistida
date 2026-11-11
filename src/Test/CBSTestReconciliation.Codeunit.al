namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Unit tests for the reconciliation classification rule (spec 9.3, T03-T06) and for the
/// document-type guard.
///
/// Classify is a pure function - no table writes, no adapter call - so these tests run
/// without any fiscal history and without the test libraries: assertions are local, which
/// keeps the shipped app free of a dependency on "Library Assert" (running them still needs
/// the Test Runner extension installed in the sandbox).
/// </summary>
codeunit 50170 "CBS Test Reconciliation"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure ReconciledWhenDifferenceIsWithinTolerance()
    var
        Debt: Record "CBS Debt";
        Classification: Enum "CBS Reconciliation Class.";
        Reason: Text[250];
    begin
        // [GIVEN] an NF-e debt of 100,00 and a note declaring 100,00
        CreateDebt(Debt, 100, "CBS Document Type"::NFe);

        // [WHEN] the debt is classified with zero tolerance
        Classification := Engine.Classify(Debt, true, 100, 100, "CBS Fiscal History Adapter"::NoLink, 0, Reason);

        // [THEN] it is reconciled
        AssertEquals(Format(Classification::Reconciled), Format(Classification), 'Expected Reconciled.');
    end;

    [Test]
    procedure DivergentWhenDifferenceExceedsTolerance()
    var
        Debt: Record "CBS Debt";
        Classification: Enum "CBS Reconciliation Class.";
        Reason: Text[250];
    begin
        // [GIVEN] assessed 100,00 against a declared 90,00
        CreateDebt(Debt, 100, "CBS Document Type"::NFe);

        // [WHEN] classified
        Classification := Engine.Classify(Debt, true, 90, 90, "CBS Fiscal History Adapter"::NoLink, 0, Reason);

        // [THEN] divergent
        AssertEquals(Format(Classification::Divergent), Format(Classification), 'Expected Divergent.');
    end;

    [Test]
    procedure AdjustmentWhenItemsDifferFromTotal()
    var
        Debt: Record "CBS Debt";
        Classification: Enum "CBS Reconciliation Class.";
        Reason: Text[250];
    begin
        // [GIVEN] the mandatory fixture of spec 8.4: items 0,17 vs total 0,19
        CreateDebt(Debt, 19, "CBS Document Type"::NFe);

        // [WHEN] classified
        Classification := Engine.Classify(Debt, true, 19, 17, "CBS Fiscal History Adapter"::NoLink, 0, Reason);

        // [THEN] internal divergence is an adjustment, not a plain divergence
        AssertEquals(Format(Classification::Adjustment), Format(Classification), 'Expected Adjustment.');
    end;

    [Test]
    procedure NoAdapterIsReportedWhenNoAdapterIsLinked()
    var
        Debt: Record "CBS Debt";
        Classification: Enum "CBS Reconciliation Class.";
        Reason: Text[250];
    begin
        // [GIVEN] a debt and no adapter configured in the company
        CreateDebt(Debt, 50, "CBS Document Type"::NFe);

        // [WHEN] classified with the NoLink adapter and the note not found
        Classification := Engine.Classify(Debt, false, 0, 0, "CBS Fiscal History Adapter"::NoLink, 0, Reason);

        // [THEN] it reports the missing adapter, not a missing note (RF09)
        AssertEquals(Format(Classification::NoAdapter), Format(Classification), 'Expected NoAdapter.');
    end;

    [Test]
    procedure NonNfeDocumentIsNotApplicable()
    var
        Debt: Record "CBS Debt";
        Classification: Enum "CBS Reconciliation Class.";
        Reason: Text[250];
    begin
        // [GIVEN] a CT-e (model 57) debt - the MVP reconciles NF-e only
        CreateDebt(Debt, 100, "CBS Document Type"::CTe);

        // [WHEN] classified, even with a matching amount
        Classification := Engine.Classify(Debt, true, 100, 100, "CBS Fiscal History Adapter"::NoLink, 0, Reason);

        // [THEN] it is set aside instead of flooding the user with false exceptions
        AssertEquals(Format(Classification::NotApplicableDFe), Format(Classification), 'Expected NotApplicableDFe.');
    end;

    [Test]
    procedure ToleranceAbsorbsSmallDifference()
    var
        Debt: Record "CBS Debt";
        Classification: Enum "CBS Reconciliation Class.";
        Reason: Text[250];
    begin
        // [GIVEN] a 0,05 difference
        CreateDebt(Debt, 100.05, "CBS Document Type"::NFe);

        // [WHEN] the tolerance is 0,10
        Classification := Engine.Classify(Debt, true, 100, 100, "CBS Fiscal History Adapter"::NoLink, 0.10, Reason);

        // [THEN] reconciled
        AssertEquals(Format(Classification::Reconciled), Format(Classification), 'Expected Reconciled within tolerance.');
    end;

    var
        Engine: Codeunit "CBS Reconciliation Engine";

    local procedure CreateDebt(var Debt: Record "CBS Debt"; Assessed: Decimal; Document: Enum "CBS Document Type")
    begin
        Debt.Init();
        Debt.Environment := Debt.Environment::RestrictedProduction;
        Debt.NI := '11222333000181';
        Debt.Period := DMY2Date(1, 10, 2026);
        Debt.Document := Document;
        Debt."Access Key" := '35240112223330001815500100000127000000001';
        Debt.Origin := Debt.Origin::Normal;
        Debt."CBS Assessed" := Assessed;
    end;

    local procedure AssertEquals(Expected: Text; Actual: Text; Message: Text)
    var
        AssertFailedErr: Label 'Assert failed: %1 Expected %2, actual %3.', Comment = '%1 = message, %2 = expected, %3 = actual';
    begin
        if Expected <> Actual then
            Error(AssertFailedErr, Message, Expected, Actual);
    end;
}
