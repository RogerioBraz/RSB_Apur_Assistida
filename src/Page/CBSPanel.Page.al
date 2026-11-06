namespace RSB.ApurAssistida.CBS;

using System.Utilities;

/// <summary>
/// Panel for tracking CBS debts by period (RF04). When opened, the period range is filled
/// with the default values from CBS Setup ("Starting Period"/"Ending Period" fields) and can
/// be freely changed by the user through the page's standard FilterGroup. The totals shown
/// below the list always reflect the currently filtered set of rows.
/// </summary>
page 50154 "CBS Panel"
{
    PageType = List;
    ApplicationArea = All;
    Caption = 'CBS Panel';
    UsageCategory = Administration;
    SourceTable = "CBS Debt";
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(Control)
            {
                field(Environment; Rec.Environment) { ApplicationArea = All; }
                field(NI; Rec.NI) { ApplicationArea = All; }
                field(Period; Rec.Period) { ApplicationArea = All; }
                field(Document; Rec.Document) { ApplicationArea = All; }
                field("Access Key"; Rec."Access Key") { ApplicationArea = All; }
                field(Origin; Rec.Origin) { ApplicationArea = All; }
                field("CBS Assessed"; Rec."CBS Assessed") { ApplicationArea = All; }
                field("CBS Outstanding Balance"; Rec."CBS Outstanding Balance") { ApplicationArea = All; }
                field("Batch Code"; Rec."Batch Code") { ApplicationArea = All; }
            }
            group(Totals)
            {
                Caption = 'Totals of the Current Filter';

                field(TotalAssessedField; TotalAssessed)
                {
                    ApplicationArea = All;
                    Caption = 'Total CBS Assessed';
                    Editable = false;
                    ToolTip = 'Specifies the sum of CBS Assessed for the currently filtered rows.';
                }
                field(TotalOutstandingBalanceField; TotalOutstandingBalance)
                {
                    ApplicationArea = All;
                    Caption = 'Total Outstanding Balance';
                    Editable = false;
                    ToolTip = 'Specifies the sum of the Outstanding Balance for the currently filtered rows.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Reconciliations)
            {
                ApplicationArea = All;
                Caption = 'Reconciliations';
                Image = Reconcile;
                ToolTip = 'Shows the reconciliation evaluations recorded for the selected debt.';

                trigger OnAction()
                var
                    Reconciliation: Record "CBS Reconciliation";
                begin
                    Reconciliation.SetRange("Debt Entry No", Rec."Entry No");
                    Page.Run(Page::"CBS Reconciliation List", Reconciliation);
                end;
            }
        }
        area(Processing)
        {
            action(ReconcilePending)
            {
                ApplicationArea = All;
                Caption = 'Reconcile Pending Debts';
                ToolTip = 'Evaluates every CBS debt that has no reconciliation trail yet against the fiscal history, using the configured adapter and tolerance.';
                Image = Reconcile;

                trigger OnAction()
                var
                    Engine: Codeunit "CBS Reconciliation Engine";
                    ReconciledCount: Integer;
                begin
                    ReconciledCount := Engine.ReconcilePending();
                    CurrPage.Update(false);
                    Message(ReconciledPendingMsg, ReconciledCount);
                end;
            }
            action(ReverseLookup)
            {
                ApplicationArea = All;
                Caption = 'Reverse Lookup';
                ToolTip = 'Finds fiscal history notes, within an issue date range, that have no CBS debt linked by access key.';
                Image = Find;

                trigger OnAction()
                var
                    Setup: Record "CBS Setup";
                    ReverseLookup: Codeunit "CBS Reverse Lookup";
                    RequestPage: Page "CBS Reverse Lookup Request";
                    FromDate: Date;
                    ToDate: Date;
                    FoundCount: Integer;
                begin
                    Setup.GetSetup(Setup);
                    RequestPage.SetRange(Setup."Starting Period", Setup."Ending Period");
                    if RequestPage.RunModal() <> Action::OK then
                        exit;
                    RequestPage.GetRange(FromDate, ToDate);
                    FoundCount := ReverseLookup.Lookup(FromDate, ToDate);
                    Message(ReverseLookupDoneMsg, FoundCount);
                end;
            }
            action(ExportReconciliationCsv)
            {
                ApplicationArea = All;
                Caption = 'Export Reconciliation to CSV';
                ToolTip = 'Exports the latest reconciliation evaluation of every debt to a CSV file.';
                Image = ExportFile;

                trigger OnAction()
                var
                    Exporter: Codeunit "CBS Exporter";
                    TempBlob: Codeunit "Temp Blob";
                    InStr: InStream;
                    FileName: Text;
                begin
                    Exporter.ExportReconciliationCsv(TempBlob);
                    TempBlob.CreateInStream(InStr);
                    FileName := ReconciliationCsvFileNameTxt;
                    DownloadFromStream(InStr, ExportDialogTitleTxt, '', '', FileName);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        Setup: Record "CBS Setup";
    begin
        Setup.GetSetup(Setup);
        if (Setup."Starting Period" <> 0D) or (Setup."Ending Period" <> 0D) then
            Rec.SetRange(Period, Setup."Starting Period", Setup."Ending Period");
        UpdateTotals();
    end;

    trigger OnAfterGetRecord()
    begin
        UpdateTotals();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        UpdateTotals();
    end;

    local procedure UpdateTotals()
    var
        FilteredDebt: Record "CBS Debt";
    begin
        FilteredDebt.CopyFilters(Rec);
        FilteredDebt.CalcSums("CBS Assessed", "CBS Outstanding Balance");
        TotalAssessed := FilteredDebt."CBS Assessed";
        TotalOutstandingBalance := FilteredDebt."CBS Outstanding Balance";
    end;

    var
        TotalAssessed: Decimal;
        TotalOutstandingBalance: Decimal;
        ReconciledPendingMsg: Label '%1 debt(s) reconciled.', Comment = '%1 = count of debts reconciled';
        ReverseLookupDoneMsg: Label 'Reverse lookup finished: %1 note(s) found with no matching CBS debt.', Comment = '%1 = count of notes found';
        ReconciliationCsvFileNameTxt: Label 'CBS Reconciliation.csv';
        ExportDialogTitleTxt: Label 'Export Reconciliation';
}
