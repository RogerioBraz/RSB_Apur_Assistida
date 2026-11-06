namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Reverse lookup (RF09, flow 7.3): finds, within an issue date range, fiscal history notes
/// that did not generate any CBS debt linked by key. Each note found in that condition
/// generates a new reconciliation trail line classified as NoteWithoutDebt.
/// </summary>
codeunit 50139 "CBS Reverse Lookup"
{
    Access = Internal;

    procedure Lookup(FromDate: Date; ToDate: Date): Integer
    var
        Factory: Codeunit "CBS Adapter Factory";
        Setup: Record "CBS Setup";
        Adapter: Interface "ICbsFiscalHistory";
    begin
        Setup.GetSetup(Setup);
        Adapter := Factory.CreateAdapter();
        exit(LookupWithAdapter(FromDate, ToDate, Setup.Environment, Setup."Fiscal History Adapter", Adapter));
    end;

    procedure LookupWithAdapter(FromDate: Date; ToDate: Date; Environment: Enum "CBS Environment Type"; SelectedAdapter: Enum "CBS Fiscal History Adapter"; Adapter: Interface "ICbsFiscalHistory"): Integer
    var
        Buffer: Record "CBS Fiscal History Buffer" temporary;
        Debt: Record "CBS Debt";
        Reconciliation: Record "CBS Reconciliation";
        NotesWithoutDebt: Integer;
    begin
        Adapter.ListByIssueDate(FromDate, ToDate, Environment, Buffer);
        if Buffer.FindSet() then
            repeat
                Debt.SetRange("Access Key", Buffer."Access Key");
                Debt.SetRange(Environment, Environment);
                if Debt.IsEmpty() then begin
                    Reconciliation.Init();
                    Reconciliation."Debt Entry No" := 0;
                    Reconciliation."Access Key" := Buffer."Access Key";
                    Reconciliation."Note Exists" := true;
                    Reconciliation."CBS Declared Total" := Buffer."CBS Declared Total";
                    Reconciliation."CBS Declared Items" := Buffer."CBS Declared Items";
                    Reconciliation."Adapter Used" := SelectedAdapter;
                    Reconciliation.Classification := Reconciliation.Classification::NoteWithoutDebt;
                    Reconciliation.Reason := NoteWithoutDebtMsg;
                    Reconciliation.Insert(true);
                    NotesWithoutDebt += 1;
                end;
            until Buffer.Next() = 0;
        exit(NotesWithoutDebt);
    end;

    var
        NoteWithoutDebtMsg: Label 'Note issued in the period with no CBS debt linked (reverse lookup).';
}
