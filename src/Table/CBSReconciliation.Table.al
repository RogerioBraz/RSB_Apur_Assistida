namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Result of reconciling a debt against the fiscal history. The key is composed of the debt
/// number (Entry No of CBS Debt) and a sequential evaluation number, since the same debt can
/// be re-evaluated more than once (audit trail).
///
/// Naming note: the field is called "Classification" (matching the Reconciliation
/// Classification enum) consistently throughout the code that references it.
/// </summary>
table 50105 "CBS Reconciliation"
{
    Caption = 'CBS Reconciliation';
    DataClassification = SystemMetadata;
    Access = Internal;
    DrillDownPageId = "CBS Reconciliation List";
    LookupPageId = "CBS Reconciliation List";

    fields
    {
        field(1; "Debt Entry No"; Integer)
        {
            Caption = 'Debt';
            TableRelation = "CBS Debt"."Entry No";
            DataClassification = SystemMetadata;
        }
        field(2; "Evaluation No"; Integer)
        {
            Caption = 'Evaluation No.';
            DataClassification = SystemMetadata;
        }
        field(10; "Access Key"; Text[100])
        {
            Caption = 'NF-e Access Key';
            DataClassification = CustomerContent;
        }
        field(11; "Note Exists"; Boolean)
        {
            Caption = 'Note Exists in Fiscal History';
            DataClassification = SystemMetadata;
        }
        field(20; "CBS Declared Total"; Decimal)
        {
            Caption = 'CBS Declared (Note Total)';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(21; "CBS Declared Items"; Decimal)
        {
            Caption = 'CBS Declared (Sum of Line Items)';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(22; Difference; Decimal)
        {
            Caption = 'Difference (Assessed - Declared)';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(30; Classification; Enum "CBS Reconciliation Class.")
        {
            Caption = 'Classification';
            DataClassification = SystemMetadata;
        }
        field(31; Reason; Text[250])
        {
            Caption = 'Reason';
            DataClassification = SystemMetadata;
        }
        field(32; "Adapter Used"; Enum "CBS Fiscal History Adapter")
        {
            Caption = 'Adapter Used';
            DataClassification = SystemMetadata;
        }
        field(40; "Evaluated On"; DateTime)
        {
            Caption = 'Evaluated On';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(41; "Evaluated By"; Code[50])
        {
            Caption = 'Evaluated By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(42; "Batch Trail Code"; Code[20])
        {
            Caption = 'Bulk Reconciliation Batch';
            TableRelation = "CBS Batch".Code;
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Debt Entry No", "Evaluation No")
        {
            Clustered = true;
        }
        key(K2; "Access Key")
        {
        }
        key(K3; Classification)
        {
        }
        key(K4; "Batch Trail Code")
        {
        }
    }

    trigger OnInsert()
    begin
        "Evaluated On" := CurrentDateTime();
        "Evaluated By" := CopyStr(UserId(), 1, 50);
        if "Evaluation No" = 0 then
            "Evaluation No" := NextEvaluation("Debt Entry No");
    end;

    local procedure NextEvaluation(DebtEntryNo: Integer): Integer
    var
        Reconciliation: Record "CBS Reconciliation";
    begin
        Reconciliation.SetRange("Debt Entry No", DebtEntryNo);
        if Reconciliation.FindLast() then
            exit(Reconciliation."Evaluation No" + 1);
        exit(1);
    end;
}
