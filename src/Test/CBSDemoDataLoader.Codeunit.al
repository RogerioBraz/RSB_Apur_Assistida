namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Loads a small, self-contained set of demo data (setup, a sandbox credential, CBS debts
/// across three periods and a few reconciliation evaluations) so the extension can be
/// demonstrated end-to-end without a real connection to the Revenue Service API. Safe to run
/// more than once: existing demo records are updated in place instead of duplicated, and no
/// real/production data is ever touched.
/// </summary>
codeunit 50100 "CBS Demo Data Loader"
{
    Access = Internal;

    /// <summary>Loads (or refreshes) the full demo data set and shows a summary message.</summary>
    procedure Load()
    var
        Setup: Record "CBS Setup";
        Credential: Record "CBS Credential";
        InsertedDebts: Integer;
        InsertedReconciliations: Integer;
    begin
        EnsureDemoSetup(Setup);
        EnsureDemoCredential(Setup, Credential);
        EnsureDemoDebtsAndReconciliations(Setup, InsertedDebts, InsertedReconciliations);
        Message(DemoDataLoadedMsg, InsertedDebts, InsertedReconciliations);
    end;

    local procedure EnsureDemoSetup(var Setup: Record "CBS Setup")
    begin
        Setup.GetSetup(Setup);
        Setup.Environment := Setup.Environment::RestrictedProduction;
        Setup."Active Service" := Setup."Active Service"::Debts;
        if Setup."Base CNPJ" = '' then
            Setup."Base CNPJ" := DemoBaseCnpjTok;
        if Setup."Taxpayer CNPJ" = '' then
            Setup."Taxpayer CNPJ" := DemoTaxpayerCnpjTok;
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

    local procedure EnsureDemoDebtsAndReconciliations(Setup: Record "CBS Setup"; var InsertedDebts: Integer; var InsertedReconciliations: Integer)
    var
        EntryNo1, EntryNo2, EntryNo3, EntryNo4, EntryNo5, EntryNo6 : Integer;
        Adapter: Enum "CBS Fiscal History Adapter";
    begin
        InsertedDebts := 0;
        InsertedReconciliations := 0;
        Adapter := Setup."Fiscal History Adapter";

        // Two debts per period (oldest to most recent), with varied origins and amounts.
        if EnsureDemoDebt(Setup, DemoPeriod(2), "CBS Document Type"::NFe, '000001', "CBS Debt Origin"::Normal, 1250.75, EntryNo1) then
            InsertedDebts += 1;
        if EnsureDemoDebt(Setup, DemoPeriod(2), "CBS Document Type"::NFe, '000002', "CBS Debt Origin"::ReturnByPcont, 430.10, EntryNo2) then
            InsertedDebts += 1;
        if EnsureDemoDebt(Setup, DemoPeriod(1), "CBS Document Type"::NFe, '000003', "CBS Debt Origin"::Normal, 980.00, EntryNo3) then
            InsertedDebts += 1;
        if EnsureDemoDebt(Setup, DemoPeriod(1), "CBS Document Type"::NFe, '000004', "CBS Debt Origin"::Normal, 2100.55, EntryNo4) then
            InsertedDebts += 1;
        if EnsureDemoDebt(Setup, DemoPeriod(0), "CBS Document Type"::NFe, '000005', "CBS Debt Origin"::Normal, 310.40, EntryNo5) then
            InsertedDebts += 1;
        if EnsureDemoDebt(Setup, DemoPeriod(0), "CBS Document Type"::NFe, '000006', "CBS Debt Origin"::CreditCancellation, 75.20, EntryNo6) then
            InsertedDebts += 1;

        // Four of the six debts are reconciled (one per classification below); the two most
        // recent ones (EntryNo5/EntryNo6) are intentionally left pending, to demonstrate the
        // panel still showing debts awaiting reconciliation.
        if EnsureDemoReconciliation(EntryNo1, true, 1250.75, 1250.75, "CBS Reconciliation Class."::Reconciled, DemoReasonReconciledTxt, Adapter) then
            InsertedReconciliations += 1;
        if EnsureDemoReconciliation(EntryNo2, true, 430.10, 500.00, "CBS Reconciliation Class."::Divergent, DemoReasonDivergentTxt, Adapter) then
            InsertedReconciliations += 1;
        if EnsureDemoReconciliation(EntryNo3, false, 980.00, 0, "CBS Reconciliation Class."::DebtWithoutNote, DemoReasonNoNoteTxt, Adapter) then
            InsertedReconciliations += 1;
        if EnsureDemoReconciliation(EntryNo4, true, 2100.55, 0, "CBS Reconciliation Class."::NoDeclaredCbs, DemoReasonNoDeclaredTxt, Adapter) then
            InsertedReconciliations += 1;
    end;

    local procedure EnsureDemoDebt(Setup: Record "CBS Setup"; Period: Date; Document: Enum "CBS Document Type"; AccessKeySuffix: Text[10]; Origin: Enum "CBS Debt Origin"; AssessedAmount: Decimal; var EntryNo: Integer): Boolean
    var
        Debt: Record "CBS Debt";
        AccessKey: Text[100];
    begin
        AccessKey := DemoAccessKeyPrefixTok + AccessKeySuffix;
        Debt.SetRange(NI, Setup."Taxpayer CNPJ");
        Debt.SetRange("Access Key", AccessKey);
        if Debt.FindFirst() then begin
            EntryNo := Debt."Entry No";
            exit(false);
        end;

        Debt.Init();
        Debt.Environment := Setup.Environment;
        Debt.NI := Setup."Taxpayer CNPJ";
        Debt.Period := Period;
        Debt.Document := Document;
        Debt."Access Key" := AccessKey;
        Debt.Origin := Origin;
        Debt."Issued On" := CreateDateTime(Period, 090000T);
        Debt."Registered On" := CurrentDateTime();
        Debt."Updated On" := CurrentDateTime();
        Debt."CBS Assessed" := AssessedAmount;
        Debt."CBS Outstanding Balance" := AssessedAmount;
        Debt.Published := true; // demo rows must be visible on the panel
        Debt.Insert(true);
        EntryNo := Debt."Entry No";
        exit(true);
    end;

    local procedure EnsureDemoReconciliation(DebtEntryNo: Integer; NoteExists: Boolean; AssessedAmount: Decimal; DeclaredAmount: Decimal; Classification: Enum "CBS Reconciliation Class."; Reason: Text[250]; Adapter: Enum "CBS Fiscal History Adapter"): Boolean
    var
        Debt: Record "CBS Debt";
        Reconciliation: Record "CBS Reconciliation";
    begin
        Reconciliation.SetRange("Debt Entry No", DebtEntryNo);
        if not Reconciliation.IsEmpty() then
            exit(false);

        Debt.Get(DebtEntryNo);
        Reconciliation.Init();
        Reconciliation."Debt Entry No" := DebtEntryNo;
        Reconciliation."Access Key" := Debt."Access Key";
        Reconciliation."Note Exists" := NoteExists;
        Reconciliation."CBS Declared Total" := DeclaredAmount;
        Reconciliation."CBS Declared Items" := DeclaredAmount;
        Reconciliation.Difference := AssessedAmount - DeclaredAmount;
        Reconciliation.Classification := Classification;
        Reconciliation.Reason := Reason;
        Reconciliation."Adapter Used" := Adapter;
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
        DemoDataLoadedMsg: Label 'Demo data loaded: %1 new debt(s), %2 new reconciliation(s).', Comment = '%1/%2 = record counts';
}
