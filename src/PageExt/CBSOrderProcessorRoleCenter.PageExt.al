namespace RSB.ApurAssistida.CBS;
using Microsoft.Sales.RoleCenters;

/// <summary>
/// Adds a "CBS Assisted Assessment" section to the standard Sales Order Processor Role
/// Center, grouping the extension's main pages (setup, credentials, panel, debts,
/// reconciliations and requests) in one place for quick access.
/// </summary>
pageextension 50100 "CBS Order Processor RC Ext" extends "Order Processor Role Center"
{
    actions
    {
        addlast(sections)
        {
            group("CBS Assisted Assessment")
            {
                Caption = 'CBS Assisted Assessment';

                action(CBSPanel)
                {
                    ApplicationArea = All;
                    Caption = 'CBS Panel';
                    ToolTip = 'Shows CBS debts by period, with totals for the current filter.';
                    Image = ItemLedger;
                    RunObject = page "CBS Panel";
                }
                action(CBSDebtList)
                {
                    ApplicationArea = All;
                    Caption = 'CBS Debts';
                    ToolTip = 'Shows every CBS debt imported from the Revenue Service API.';
                    Image = Entries;
                    RunObject = page "CBS Debt List";
                }
                action(CBSReconciliationList)
                {
                    ApplicationArea = All;
                    Caption = 'CBS Reconciliations';
                    ToolTip = 'Shows the reconciliation evaluations between CBS debts and the fiscal history.';
                    Image = Reconcile;
                    RunObject = page "CBS Reconciliation List";
                }
                action(CBSRequestList)
                {
                    ApplicationArea = All;
                    Caption = 'CBS Requests';
                    ToolTip = 'Shows the collection cycles (requests) opened with the Revenue Service API.';
                    Image = Process;
                    RunObject = page "CBS Request List";
                }
                action(CBSCredentialList)
                {
                    ApplicationArea = All;
                    Caption = 'CBS Credentials';
                    ToolTip = 'Shows the OAuth2 credentials configured per environment.';
                    Image = Certificate;
                    RunObject = page "CBS Credential List";
                }
                action(CBSSetupCard)
                {
                    ApplicationArea = All;
                    Caption = 'CBS Setup';
                    ToolTip = 'Opens the main CBS Assisted Assessment configuration.';
                    Image = Setup;
                    RunObject = page "CBS Setup Card";
                }
            }
        }
    }
}
