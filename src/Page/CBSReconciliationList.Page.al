namespace RSB.ApurAssistida.CBS;

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
}
