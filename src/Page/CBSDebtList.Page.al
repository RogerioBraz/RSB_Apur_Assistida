namespace RSB.ApurAssistida.CBS;

/// <summary>List of CBS debts imported and normalized from the Revenue Service JSON.</summary>
page 50151 "CBS Debt List"
{
    PageType = List;
    ApplicationArea = All;
    Caption = 'CBS Debts';
    UsageCategory = Lists;
    SourceTable = "CBS Debt";
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(Control)
            {
                field("Entry No"; Rec."Entry No") { ApplicationArea = All; }
                field(Environment; Rec.Environment) { ApplicationArea = All; }
                field(NI; Rec.NI) { ApplicationArea = All; }
                field(Period; Rec.Period) { ApplicationArea = All; }
                field(Document; Rec.Document) { ApplicationArea = All; }
                field("Access Key"; Rec."Access Key") { ApplicationArea = All; }
                field(Origin; Rec.Origin) { ApplicationArea = All; }
                field("Issued On"; Rec."Issued On") { ApplicationArea = All; }
                field("CBS Assessed"; Rec."CBS Assessed") { ApplicationArea = All; }
                field("CBS Excess"; Rec."CBS Excess") { ApplicationArea = All; }
                field("CBS Not Due"; Rec."CBS Not Due") { ApplicationArea = All; }
                field("CBS Suspended"; Rec."CBS Suspended") { ApplicationArea = All; }
                field("CBS Prepaid"; Rec."CBS Prepaid") { ApplicationArea = All; }
                field("CBS Extinguished"; Rec."CBS Extinguished") { ApplicationArea = All; }
                field("CBS Outstanding Balance"; Rec."CBS Outstanding Balance") { ApplicationArea = All; }
                field("Batch Code"; Rec."Batch Code") { ApplicationArea = All; }
                field("Request Entry No"; Rec."Request Entry No") { ApplicationArea = All; }
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
                ToolTip = 'Shows the reconciliation evaluations recorded for this debt.';

                trigger OnAction()
                var
                    Reconciliation: Record "CBS Reconciliation";
                begin
                    Reconciliation.SetRange("Debt Entry No", Rec."Entry No");
                    Page.Run(Page::"CBS Reconciliation List", Reconciliation);
                end;
            }
        }
    }
}
