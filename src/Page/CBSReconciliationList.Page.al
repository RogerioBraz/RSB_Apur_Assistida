namespace RSB.ApurAssistida.CBS;

using System.Utilities;

/// <summary>List of reconciliation evaluations between CBS debts and the fiscal history.</summary>
page 50153 "CBS Reconciliation List"
{
    PageType = List;
    ApplicationArea = All;
    Caption = 'CBS Reconciliations';
    UsageCategory = Lists;
    SourceTable = "CBS Reconciliation";
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(Control)
            {
                field("Debt Entry No"; Rec."Debt Entry No") { ApplicationArea = All; }
                field("Evaluation No"; Rec."Evaluation No") { ApplicationArea = All; }
                field("Access Key"; Rec."Access Key") { ApplicationArea = All; }
                field("Note Exists"; Rec."Note Exists") { ApplicationArea = All; }
                field("CBS Declared Total"; Rec."CBS Declared Total") { ApplicationArea = All; }
                field("CBS Declared Items"; Rec."CBS Declared Items") { ApplicationArea = All; }
                field(Difference; Rec.Difference) { ApplicationArea = All; }
                field(Classification; Rec.Classification) { ApplicationArea = All; }
                field(Reason; Rec.Reason) { ApplicationArea = All; }
                field("Adapter Used"; Rec."Adapter Used") { ApplicationArea = All; }
                field("Evaluated On"; Rec."Evaluated On") { ApplicationArea = All; }
                field("Evaluated By"; Rec."Evaluated By") { ApplicationArea = All; }
                field("Batch Trail Code"; Rec."Batch Trail Code") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
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
                    CurrPage.Update(false);
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

    var
        ReconciledPendingMsg: Label '%1 debt(s) reconciled.', Comment = '%1 = count of debts reconciled';
        ReverseLookupDoneMsg: Label 'Reverse lookup finished: %1 note(s) found with no matching CBS debt.', Comment = '%1 = count of notes found';
        ReconciliationCsvFileNameTxt: Label 'CBS Reconciliation.csv';
        ExportDialogTitleTxt: Label 'Export Reconciliation';
}
