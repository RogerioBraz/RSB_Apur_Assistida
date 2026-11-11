namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Evaluates a debt against the fiscal history (via adapter) and records the result in CBS
/// Reconciliation. The Adjustment classification reflects an internal divergence between the
/// line item CBS value and the note total (spec section 6.9/8.1/8.4) - NOT the debt origin,
/// which is merely informational. The absence of a configured adapter (enum "No Link")
/// generates the NoAdapter classification, distinct from DebtWithoutNote (a configured
/// adapter that genuinely did not find the note) - see RF09.
/// </summary>
codeunit 50135 "CBS Reconciliation Engine"
{
    Access = Internal;

    /// <summary>
    /// Manual, on-demand entry point (action button): evaluates every CBS Debt that does not
    /// yet have any reconciliation trail recorded. Returns the number of debts reconciled.
    /// </summary>
    procedure ReconcilePending(): Integer
    var
        Debt: Record "CBS Debt";
        Reconciliation: Record "CBS Reconciliation";
        Factory: Codeunit "CBS Adapter Factory";
        Setup: Record "CBS Setup";
        Adapter: Interface "ICbsFiscalHistory";
        ReconciledCount: Integer;
    begin
        Setup.GetSetup(Setup);
        Adapter := Factory.CreateAdapter();
        if Debt.FindSet() then
            repeat
                Reconciliation.SetRange("Debt Entry No", Debt."Entry No");
                if Reconciliation.IsEmpty() then begin
                    ReconcileDebt(Debt, Adapter, Setup."Fiscal History Adapter", Setup."Reconciliation Tolerance", '');
                    ReconciledCount += 1;
                end;
            until Debt.Next() = 0;
        exit(ReconciledCount);
    end;

    /// <summary>Evaluates a single debt and records a new trail line in CBS Reconciliation.</summary>
    procedure ReconcileDebt(var Debt: Record "CBS Debt"; Adapter: Interface "ICbsFiscalHistory"; SelectedAdapter: Enum "CBS Fiscal History Adapter"; Tolerance: Decimal; BatchTrailCode: Code[20])
    var
        Reconciliation: Record "CBS Reconciliation";
        Buffer: Record "CBS Fiscal History Buffer";
        NoteExists: Boolean;
        DeclaredCbsTotal: Decimal;
        DeclaredCbsItems: Decimal;
        Reason: Text[250];
    begin
        NoteExists := Adapter.GetNoteByKey(Debt."Access Key", Debt.Environment, Buffer);
        DeclaredCbsTotal := 0;
        DeclaredCbsItems := 0;
        if NoteExists then
            Adapter.GetDeclaredCbs(Debt."Access Key", Debt.Environment, DeclaredCbsTotal, DeclaredCbsItems);

        Reconciliation.Init();
        Reconciliation."Debt Entry No" := Debt."Entry No";
        Reconciliation."Access Key" := Debt."Access Key";
        Reconciliation."Note Exists" := NoteExists;
        Reconciliation."CBS Declared Total" := DeclaredCbsTotal;
        Reconciliation."CBS Declared Items" := DeclaredCbsItems;
        Reconciliation.Difference := Debt."CBS Assessed" - DeclaredCbsTotal;
        Reconciliation."Adapter Used" := SelectedAdapter;
        Reconciliation."Batch Trail Code" := BatchTrailCode;
        Reconciliation.Classification := Classify(Debt, NoteExists, DeclaredCbsTotal, DeclaredCbsItems, SelectedAdapter, Tolerance, Reason);
        Reconciliation.Reason := Reason;
        Reconciliation.Insert(true);
    end;

    /// <summary>
    /// Pure classification rule, kept separate from ReconcileDebt to allow isolated unit
    /// testing without depending on a real adapter or on writing to a table.
    /// </summary>
    procedure Classify(Debt: Record "CBS Debt"; NoteExists: Boolean; DeclaredCbsTotal: Decimal; DeclaredCbsItems: Decimal; SelectedAdapter: Enum "CBS Fiscal History Adapter"; Tolerance: Decimal; var Reason: Text[250]): Enum "CBS Reconciliation Class."
    var
        Difference: Decimal;
    begin
        // The MVP reconciles NF-e (model 55) only. A CT-e/NFS-e debt cannot be matched
        // against the NF-e history, so classifying it as "debt without note" would flood the
        // fiscal user with false exceptions (see spec 2.2: other DFe models are roadmap).
        if Debt.Document <> Debt.Document::NFe then begin
            Reason := CopyStr(StrSubstNo(NotNfeMsg, Format(Debt.Document)), 1, 250);
            exit("CBS Reconciliation Class."::NotApplicableDFe);
        end;

        if not NoteExists then begin
            if SelectedAdapter = SelectedAdapter::NoLink then begin
                Reason := NoAdapterMsg;
                exit("CBS Reconciliation Class."::NoAdapter);
            end;
            Reason := DebtWithoutNoteMsg;
            exit("CBS Reconciliation Class."::DebtWithoutNote);
        end;

        if DeclaredCbsTotal = 0 then begin
            Reason := NoDeclaredCbsMsg;
            exit("CBS Reconciliation Class."::NoDeclaredCbs);
        end;

        // Internal divergence: the sum of the line item CBS values differs from the note
        // total (mandatory fixture case from spec section 8.4: item 0.17 vs. total 0.19).
        if (DeclaredCbsItems <> 0) and (DeclaredCbsItems <> DeclaredCbsTotal) then begin
            Reason := CopyStr(StrSubstNo(AdjustmentMsg, DeclaredCbsItems, DeclaredCbsTotal), 1, 250);
            exit("CBS Reconciliation Class."::Adjustment);
        end;

        Difference := Abs(Debt."CBS Assessed" - DeclaredCbsTotal);
        if Difference <= Tolerance then begin
            Reason := ReconciledMsg;
            exit("CBS Reconciliation Class."::Reconciled);
        end;

        Reason := CopyStr(StrSubstNo(DivergentMsg, Debt."CBS Assessed" - DeclaredCbsTotal), 1, 250);
        exit("CBS Reconciliation Class."::Divergent);
    end;

    var
        NotNfeMsg: Label 'Document type %1 is not NF-e (55); not applicable to the MVP reconciliation.', Comment = '%1 = document type';
        NoAdapterMsg: Label 'No fiscal history adapter is linked in this company.';
        DebtWithoutNoteMsg: Label 'Debt with assessed CBS and no matching note found in the fiscal history.';
        NoDeclaredCbsMsg: Label 'Matched note, but no CBS declared in the XML.';
        AdjustmentMsg: Label 'Internal divergence: sum of line items (%1) differs from the note total (%2).', Comment = '%1/%2 = CBS amounts';
        ReconciledMsg: Label 'Difference within the configured tolerance.';
        DivergentMsg: Label 'Assessed difference: %1.', Comment = '%1 = difference amount';
}
