namespace RSB.ApurAssistida.CBS;

/// <summary>Main configuration card (one record per company).</summary>
page 50150 "CBS Setup Card"
{
    PageType = Card;
    ApplicationArea = All;
    Caption = 'CBS Setup';
    UsageCategory = Administration;
    SourceTable = "CBS Setup";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            group(Configuration)
            {
                Caption = 'Configuration';

                field(Environment; Rec.Environment)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this configuration operates in Production or Restricted Production (sandbox).';
                }
                field("Base CNPJ"; Rec."Base CNPJ")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the parent company''s base CNPJ (8 digits) used when opening requests.';
                }
                field("Taxpayer CNPJ"; Rec."Taxpayer CNPJ")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the taxpayer''s full CNPJ, used for verification during import.';
                }
                field("Credential Code"; Rec."Credential Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the active OAuth2 credential for this environment.';
                }
                field("Active Service"; Rec."Active Service")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the API service collected by the queue (the MVP only implements Debts).';
                }
                field(Blocked; Rec.Blocked)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether automatic collection is temporarily blocked.';
                }
            }
            group(Reconciliation)
            {
                Caption = 'Reconciliation';

                field("Fiscal History Adapter"; Rec."Fiscal History Adapter")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the fiscal history adapter used to locate the notes.';
                }
                field("Reconciliation Tolerance"; Rec."Reconciliation Tolerance")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the maximum difference (in value) accepted to classify as Reconciled.';
                }
            }
            group(DefaultPanelFilters)
            {
                Caption = 'Default panel filters';

                field("Starting Period"; Rec."Starting Period")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default starting period when opening the panel.';
                }
                field("Ending Period"; Rec."Ending Period")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default ending period when opening the panel.';
                }
            }
            group(Operation)
            {
                Caption = 'Operation';

                field("Incremental Window Days"; Rec."Incremental Window Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies, in days, the recent incremental window considered by the Revenue Service.';
                }
                field("JSON Retention Days"; Rec."JSON Retention Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies for how many days the original JSON is kept before purging.';
                }
                field("Daily Opening Quota"; Rec."Daily Opening Quota")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the daily quota of request openings per credential.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Credentials)
            {
                ApplicationArea = All;
                Caption = 'Credentials';
                Image = Setup;
                RunObject = page "CBS Credential List";
            }
            action(Panel)
            {
                ApplicationArea = All;
                Caption = 'CBS Panel';
                Image = ItemLedger;
                RunObject = page "CBS Panel";
            }
        }
        area(Processing)
        {
            action(RunCollectionNow)
            {
                ApplicationArea = All;
                Caption = 'Run Collection Now';
                ToolTip = 'Runs one collection cycle immediately - the same logic normally executed by the scheduled Job Queue entry - without waiting for its next scheduled run.';
                Image = Refresh;

                trigger OnAction()
                var
                    Dispatcher: Codeunit "CBS Job Queue Dispatcher";
                begin
                    Dispatcher.RunCycle();
                    Message(CollectionCycleRanMsg);
                end;
            }
            action(PurgeExpiredFiles)
            {
                ApplicationArea = All;
                Caption = 'Purge Expired JSON';
                ToolTip = 'Clears the original JSON of files older than the retention window. The file row and its hash are kept for audit and idempotency.';
                Image = Delete;

                trigger OnAction()
                var
                    Maintenance: Codeunit "CBS Maintenance";
                    PurgedCount: Integer;
                begin
                    PurgedCount := Maintenance.PurgeExpiredFiles();
                    Message(PurgedMsg, PurgedCount);
                end;
            }
            action(RebuildCoverage)
            {
                ApplicationArea = All;
                Caption = 'Rebuild Coverage';
                ToolTip = 'Rebuilds the coverage ledger (last collection and debt count per period) from the published data.';
                Image = Refresh;

                trigger OnAction()
                var
                    Maintenance: Codeunit "CBS Maintenance";
                    Rows: Integer;
                begin
                    Rows := Maintenance.RebuildCoverage();
                    Message(CoverageMsg, Rows);
                end;
            }
            action(LoadDemoData)
            {
                ApplicationArea = All;
                Caption = 'Load Demo Data';
                ToolTip = 'Loads a small set of fictitious setup, credential, debt and reconciliation records for demonstration purposes. Safe to run more than once.';
                Image = DataEntry;

                trigger OnAction()
                var
                    DemoDataLoader: Codeunit "CBS Demo Data Loader";
                begin
                    if not Confirm(LoadDemoDataConfirmQst) then
                        exit;
                    DemoDataLoader.Load();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup(Rec);
    end;

    var
        LoadDemoDataConfirmQst: Label 'This loads fictitious demo data (setup, credential, debts and reconciliations) for demonstration purposes. Continue?';
        CollectionCycleRanMsg: Label 'Collection cycle finished. See CBS Requests and CBS Log Entry for details.';
        PurgedMsg: Label '%1 file(s) purged.', Comment = '%1 = number of files purged';
        CoverageMsg: Label 'Coverage rebuilt: %1 period(s).', Comment = '%1 = number of period rows written';
}
