namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Loads a small, self-contained demo data set so the extension can be shown end-to-end
/// without a real connection to the Revenue Service API.
///
/// What it creates:
///  - Setup (only the fields still empty - an already configured company is never
///    re-pointed to another environment) and a fictitious credential;
///  - three collection cycles (CBS Request) already Published, one per period, each with
///    its Published batch (CBS Batch) - so the Request List, the batch lineage and the
///    "Batch Code" columns are not empty;
///  - eight debts covering: reconciled, divergent, debt without note, note without declared
///    CBS, internal item-vs-total divergence (adjustment), a non-NF-e document, an
///    adjustment-origin debt and two still pending reconciliation;
///  - the reconciliation trail for six of them, leaving two pending on purpose so the
///    "Reconcile Pending Debts" action has something to process;
///  - the coverage ledger, rebuilt from the demo debts.
///
/// Safe to run more than once: existing demo records are reused instead of duplicated, and
/// no record outside the demo set is touched or deleted.
/// </summary>
codeunit 50100 "CBS Demo Data Loader"
{
    Access = Internal;

    /// <summary>Loads (or refreshes) the full demo data set and shows a summary message.</summary>
    procedure Load()
    var
        Setup: Record "CBS Setup";
        Credential: Record "CBS Credential";
        Maintenance: Codeunit "CBS Maintenance";
        CreatedDebts: Integer;
        CreatedReconciliations: Integer;
        CreatedRequests: Integer;
    begin
        EnsureDemoSetup(Setup);
        EnsureDemoCredential(Setup, Credential);
        EnsureDemoRequestsAndBatches(Setup, CreatedRequests);
        EnsureDemoDebts(Setup, CreatedDebts);
        CreatedReconciliations := EnsureDemoReconciliations();
        Maintenance.RebuildCoverage();
        Message(DemoDataLoadedMsg, CreatedDebts, CreatedReconciliations, CreatedRequests);
    end;

    /// <summary>
    /// Sets up the demo configuration. Only fields that are still empty are filled: a company
    /// already configured for Production is never switched to Restricted Production, because
    /// loading demo data must never change where real requests would be sent.
    /// </summary>
    local procedure EnsureDemoSetup(var Setup: Record "CBS Setup")
    begin
        Setup.GetSetup(Setup);
        if Setup."Base CNPJ" = '' then begin
            Setup.Environment := Setup.Environment::RestrictedProduction;
            Setup."Base CNPJ" := DemoBaseCnpjTok;
            Setup."Taxpayer CNPJ" := DemoTaxpayerCnpjTok;
        end;
        if Setup."Active Service" = Setup."Active Service"::Debts then
            Setup."Active Service" := Setup."Active Service"::Debts;
        if Setup."Reconciliation Tolerance" = 0 then
            Setup."Reconciliation Tolerance" := 1;
        if Setup."Starting Period" = 0D then
            Setup."Starting Period" := DemoPeriod(2);
        if Setup."Ending Period" = 0D then
            Setup."Ending Period" := DemoPeriod(0);
        Setup.Modify(true);
    end;

    local procedure EnsureDemoCredential(var Setup: Record "CBS Setup"; var Credential: Record "CBS Credential")
    var
        SecretValue: Text;
        DemoSecret: SecretText;
    begin
        if not Credential.Get(DemoCredentialCodeTok) then begin
            Credential.Init();
            Credential.Code := DemoCredentialCodeTok;
            Credential.Insert(true);
        end;
        Credential.Description := DemoCredentialDescTxt;
        Credential.Environment := Credential.Environment::RestrictedProduction;
        Credential."Client Id" := DemoClientIdTok;
        Credential."Token Url" := DemoTokenUrlTok;
        Credential.Scope := DemoScopeTok;
        Credential.Active := true;
        Credential.Modify(true);
        if not Credential.HasClientSecret() then begin
            SecretValue := DemoClientSecretTok;
            DemoSecret := SecretValue;
            Credential.SetClientSecret(DemoSecret);
        end;
        if Setup."Credential Code" = '' then begin
            Setup."Credential Code" := Credential.Code;
            Setup.Modify(true);
        end;
    end;

    /// <summary>
    /// Creates one Published collection cycle per demo period, each with its Published batch.
    /// Without this the Request List is empty and the debt rows show no batch lineage, which
    /// makes the atomic-publication feature impossible to demonstrate.
    /// </summary>
    local procedure EnsureDemoRequestsAndBatches(var Setup: Record "CBS Setup"; var CreatedRequests: Integer)
    var
        Index: Integer;
        PeriodValue: Date;
        BatchCode: Code[20];
    begin
        CreatedRequests := 0;
        for Index := 0 to 2 do begin
            PeriodValue := DemoPeriod(2 - Index);
            BatchCode := DemoBatchCode(PeriodValue);

            if not CreateDemoRequest(Setup, PeriodValue, DemoBatchRequestTicket(PeriodValue)) then
                CreatedRequests += 1;
            CreateDemoBatch(PeriodValue, BatchCode);
        end;
    end;

    local procedure CreateDemoRequest(Setup: Record "CBS Setup"; PeriodValue: Date; Ticket: Text[100]): Boolean
    var
        Request: Record "CBS Request";
    begin
        Request.SetRange(Ticket, Ticket);
        if Request.FindFirst() then
            exit(false);

        Request.Init();
        Request.Service := Setup."Active Service";
        Request.Environment := Setup.Environment;
        Request."Base CNPJ" := Setup."Base CNPJ";
        Request.Ticket := Ticket;
        Request."Local State" := Request."Local State"::Published;
        Request."Remote State" := Request."Remote State"::Completed;
        Request."Remote State Detail" := 'Demo cycle (fictitious data).';
        Request.Attempts := 0;
        Request."Created On" := CurrentDateTime();
        Request."Updated On" := CurrentDateTime();
        Request.Insert(true);
        exit(true);
    end;

    local procedure CreateDemoBatch(PeriodValue: Date; BatchCode: Code[20])
    var
        Batch: Record "CBS Batch";
    begin
        if Batch.Get(BatchCode) then
            exit;
        Batch.Init();
        Batch.Code := BatchCode;
        Batch.Type := Batch.Type::Collection;
        Batch."File Hash" := DemoHashToken(PeriodValue);
        Batch.Published := true;
        Batch."Published On" := CurrentDateTime();
        Batch."Started On" := CurrentDateTime();
        Batch."Ended On" := CurrentDateTime();
        Batch.Insert(true);
    end;

    local procedure EnsureDemoDebts(var Setup: Record "CBS Setup"; var CreatedDebts: Integer)
    var
        Debt: Record "CBS Debt";
        PeriodValue: Date;
        BatchCode: Code[20];
    begin
        CreatedDebts := 0;

        // Period -2: one reconciled, one divergent (assessed 430,10 vs declared 500,00).
        PeriodValue := DemoPeriod(2);
        BatchCode := DemoBatchCode(PeriodValue);
        if CreateDemoDebt(Setup, PeriodValue, BatchCode, "CBS Document Type"::NFe, '000001', "CBS Debt Origin"::Normal, 1250.75) then
            CreatedDebts += 1;
        if CreateDemoDebt(Setup, PeriodValue, BatchCode, "CBS Document Type"::NFe, '000002', "CBS Debt Origin"::ReturnByPcont, 430.10) then
            CreatedDebts += 1;

        // Period -1: one debt with no matching note, one matched note without declared CBS.
        PeriodValue := DemoPeriod(1);
        BatchCode := DemoBatchCode(PeriodValue);
        if CreateDemoDebt(Setup, PeriodValue, BatchCode, "CBS Document Type"::NFe, '000003', "CBS Debt Origin"::Normal, 980.00) then
            CreatedDebts += 1;
        if CreateDemoDebt(Setup, PeriodValue, BatchCode, "CBS Document Type"::NFe, '000004', "CBS Debt Origin"::Normal, 2100.55) then
            CreatedDebts += 1;

        // Current period: two debts left pending reconciliation on purpose.
        PeriodValue := DemoPeriod(0);
        BatchCode := DemoBatchCode(PeriodValue);
        if CreateDemoDebt(Setup, PeriodValue, BatchCode, "CBS Document Type"::NFe, '000005', "CBS Debt Origin"::Normal, 310.40) then
            CreatedDebts += 1;
        if CreateDemoDebt(Setup, PeriodValue, BatchCode, "CBS Document Type"::NFe, '000006', "CBS Debt Origin"::CreditCancellation, 75.20) then
            CreatedDebts += 1;

        // Fixture of spec 8.4: line items 0,17 vs total 0,19 -> internal divergence.
        // Scaled to 170,00 / 190,00 so the amounts look like a real invoice.
        if CreateDemoDebt(Setup, PeriodValue, BatchCode, "CBS Document Type"::NFe, '000007', "CBS Debt Origin"::Normal, 190.00) then
            CreatedDebts += 1;

        // A CT-e debt: the MVP reconciles NF-e only, so this one must land as
        // Not Applicable instead of a false "debt without note".
        if CreateDemoDebt(Setup, PeriodValue, BatchCode, "CBS Document Type"::CTe, '000008', "CBS Debt Origin"::Normal, 120.00) then
            CreatedDebts += 1;
    end;

    local procedure CreateDemoDebt(Setup: Record "CBS Setup"; PeriodValue: Date; BatchCode: Code[20]; Document: Enum "CBS Document Type"; KeySuffix: Text[10]; Origin: Enum "CBS Debt Origin"; AssessedAmount: Decimal): Boolean
    var
        Debt: Record "CBS Debt";
        AccessKey: Text[100];
    begin
        AccessKey := DemoAccessKeyPrefixTok + KeySuffix;
        Debt.SetRange("Access Key", AccessKey);
        if Debt.FindFirst() then
            exit(false);

        Debt.Init();
        Debt.Environment := Setup.Environment;
        Debt.NI := Setup."Taxpayer CNPJ";
        Debt.Period := PeriodValue;
        Debt.Document := Document;
        Debt."Access Key" := AccessKey;
        Debt.Origin := Origin;
        Debt."Issued On" := CreateDateTime(CalcDate('<+5D>', PeriodValue), 103000T);
        Debt."Registered On" := CreateDateTime(CalcDate('<+6D>', PeriodValue), 091500T);
        Debt."Updated On" := CurrentDateTime();
        Debt."CBS Assessed" := AssessedAmount;
        Debt."CBS Outstanding Balance" := AssessedAmount;
        Debt."Batch Code" := BatchCode;
        Debt.Published := true; // demo rows must be visible on the panel
        Debt.Insert(true);
        exit(true);
    end;

    /// <summary>
    /// Records the reconciliation trail of the demo debts, one per classification, and
    /// deliberately leaves two debts without any evaluation.
    /// </summary>
    local procedure EnsureDemoReconciliations(): Integer
    var
        Setup: Record "CBS Setup";
        Debt: Record "CBS Debt";
        Created: Integer;
    begin
        Setup.GetSetup(Setup);
        Created := 0;

        if CreateDemoReconciliation('000001', true, 1250.75, 1250.75, 1250.75, "CBS Reconciliation Class."::Reconciled, DemoReasonReconciledTxt, Setup) then
            Created += 1;
        if CreateDemoReconciliation('000002', true, 430.10, 500.00, 500.00, "CBS Reconciliation Class."::Divergent, DemoReasonDivergentTxt, Setup) then
            Created += 1;
        if CreateDemoReconciliation('000003', false, 980.00, 0, 0, "CBS Reconciliation Class."::DebtWithoutNote, DemoReasonNoNoteTxt, Setup) then
            Created += 1;
        if CreateDemoReconciliation('000004', true, 2100.55, 0, 0, "CBS Reconciliation Class."::NoDeclaredCbs, DemoReasonNoDeclaredTxt, Setup) then
            Created += 1;
        // Internal divergence: items 170,00 vs total 190,00 -> Adjustment (spec 8.4).
        if CreateDemoReconciliation('000007', true, 190.00, 190.00, 170.00, "CBS Reconciliation Class."::Adjustment, DemoReasonAdjustmentTxt, Setup) then
            Created += 1;
        // CT-e: out of MVP scope, reported as such instead of a false exception.
        if CreateDemoReconciliation('000008', true, 120.00, 120.00, 120.00, "CBS Reconciliation Class."::NotApplicableDFe, DemoReasonNotApplicableTxt, Setup) then
            Created += 1;
        exit(Created);
    end;

    local procedure CreateDemoReconciliation(KeySuffix: Text[10]; NoteExists: Boolean; AssessedAmount: Decimal; DeclaredTotal: Decimal; DeclaredItems: Decimal; Classification: Enum "CBS Reconciliation Class."; Reason: Text[250]; Setup: Record "CBS Setup"): Boolean
    var
        Debt: Record "CBS Debt";
        Reconciliation: Record "CBS Reconciliation";
        AccessKey: Text[100];
    begin
        AccessKey := DemoAccessKeyPrefixTok + KeySuffix;
        Debt.SetRange("Access Key", AccessKey);
        if not Debt.FindFirst() then
            exit(false);

        Reconciliation.SetRange("Debt Entry No", Debt."Entry No");
        if not Reconciliation.IsEmpty() then
            exit(false);

        Reconciliation.Init();
        Reconciliation."Debt Entry No" := Debt."Entry No";
        Reconciliation."Access Key" := Debt."Access Key";
        Reconciliation."Note Exists" := NoteExists;
        Reconciliation."CBS Declared Total" := DeclaredTotal;
        Reconciliation."CBS Declared Items" := DeclaredItems;
        Reconciliation.Difference := AssessedAmount - DeclaredTotal;
        Reconciliation.Classification := Classification;
        Reconciliation.Reason := Reason;
        Reconciliation."Adapter Used" := Setup."Fiscal History Adapter";
        Reconciliation.Insert(true);
        exit(true);
    end;

    /// <summary>Returns the first day of the month that is MonthsAgo months before WorkDate (0 = current month).</summary>
    local procedure DemoPeriod(MonthsAgo: Integer): Date
    var
        ReferenceDate: Date;
    begin
        case MonthsAgo of
            0:
                ReferenceDate := WorkDate();
            1:
                ReferenceDate := CalcDate('<-1M>', WorkDate());
            else
                ReferenceDate := CalcDate('<-2M>', WorkDate());
        end;
        exit(DMY2Date(1, Date2DMY(ReferenceDate, 2), Date2DMY(ReferenceDate, 3)));
    end;

    local procedure DemoBatchCode(PeriodValue: Date): Code[20]
    begin
        exit(CopyStr(StrSubstNo('DEMO-%1', Format(PeriodValue, 0, '<Year4><Month,2>')), 1, 20));
    end;

    local procedure DemoBatchRequestTicket(PeriodValue: Date): Text[100]
    begin
        exit(CopyStr(StrSubstNo('DEMO-TKT-%1', Format(PeriodValue, 0, '<Year4><Month,2>')), 1, 100));
    end;

    /// <summary>Stable fictitious SHA-256-shaped hash, so idempotency columns are not blank.</summary>
    local procedure DemoHashToken(PeriodValue: Date): Text[64]
    begin
        exit(CopyStr(StrSubstNo('demo0000%1', Format(PeriodValue, 0, '<Year4><Month,2>')), 1, 64));
    end;

    var
        DemoBaseCnpjTok: Label '11222333', Locked = true;
        DemoTaxpayerCnpjTok: Label '11222333000181', Locked = true;
        DemoCredentialCodeTok: Label 'DEMO', Locked = true;
        DemoCredentialDescTxt: Label 'Demo credential (sandbox, fictitious data)';
        DemoClientIdTok: Label 'demo-client-id', Locked = true;
        DemoTokenUrlTok: Label 'https://demo.rfb.gov.br/oauth2/token', Locked = true;
        DemoScopeTok: Label 'cbs.debitos.read', Locked = true;
        DemoClientSecretTok: Label 'demo-client-secret-not-real', Locked = true;
        DemoAccessKeyPrefixTok: Label '35240112223330001815500100000127', Locked = true;
        DemoReasonReconciledTxt: Label 'Difference within the configured tolerance.';
        DemoReasonDivergentTxt: Label 'Assessed difference: 69.90.';
        DemoReasonNoNoteTxt: Label 'No matching note found in the fiscal history.';
        DemoReasonNoDeclaredTxt: Label 'Matched note found with no declared CBS amount.';
        DemoReasonAdjustmentTxt: Label 'Internal divergence: sum of line items (170,00) differs from the note total (190,00).';
        DemoReasonNotApplicableTxt: Label 'Document type CT-e is not NF-e; not applicable to the MVP reconciliation.';
        DemoDataLoadedMsg: Label 'Demo data loaded: %1 debt(s), %2 reconciliation(s), %3 collection cycle(s). Two debts are left pending so you can try "Reconcile Pending Debts".', Comment = '%1/%2/%3 = record counts';
}
