namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Represents a collection cycle (a request) with the Revenue Service API: from accepting
/// the ticket to publishing the batch of debts. "Local State" is the state machine
/// controlled by the extension; "Remote State" is only a mirror of the latest status
/// reported by the API (see spec section 3.7/7.1).
///
/// There is deliberately no period (pa) field here: the official opening contract
/// (POST /debitos/{cnpj}) does not take a period - the API uses an incremental window on
/// the server side, and a single request can return debts from several periods in the same
/// file (each debt has its own "pa" in CBS Debt).
/// </summary>
table 50102 "CBS Request"
{
    Caption = 'CBS Request';
    DataClassification = SystemMetadata;
    Access = Internal;
    DrillDownPageId = "CBS Request List";
    LookupPageId = "CBS Request List";

    fields
    {
        field(1; "Entry No"; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(10; Service; Enum "CBS Service")
        {
            Caption = 'Service';
            DataClassification = SystemMetadata;
        }
        field(11; Environment; Enum "CBS Environment Type")
        {
            Caption = 'Environment';
            DataClassification = SystemMetadata;
        }
        field(12; "Base CNPJ"; Text[8])
        {
            Caption = 'Base CNPJ';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(20; Ticket; Text[100])
        {
            Caption = 'Ticket';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(21; "Local State"; Enum "CBS Local State")
        {
            Caption = 'Local State';
            DataClassification = SystemMetadata;
        }
        field(22; "Remote State"; Enum "CBS Remote State")
        {
            Caption = 'Remote State';
            DataClassification = SystemMetadata;
        }
        field(23; "Remote State Detail"; Text[250])
        {
            Caption = 'Remote State Detail';
            DataClassification = SystemMetadata;
        }
        field(30; Attempts; Integer)
        {
            Caption = 'Attempts in Current Cycle';
            DataClassification = SystemMetadata;
        }
        field(31; "Next Execution"; DateTime)
        {
            Caption = 'Next Execution';
            DataClassification = SystemMetadata;
        }
        field(32; "Wait Time Seconds"; Integer)
        {
            Caption = 'Estimated Wait Time (s)';
            DataClassification = SystemMetadata;
        }
        field(33; "Url Expires On"; DateTime)
        {
            Caption = 'Signed URL Expires On';
            DataClassification = SystemMetadata;
        }
        field(40; "File Hash"; Text[64])
        {
            Caption = 'File Hash (SHA-256)';
            DataClassification = SystemMetadata;
        }
        field(41; "File Entry No"; Integer)
        {
            Caption = 'File';
            TableRelation = "CBS File"."Entry No";
            DataClassification = SystemMetadata;
        }
        field(50; "Created On"; DateTime)
        {
            Caption = 'Created On';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(51; "Updated On"; DateTime)
        {
            Caption = 'Updated On';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No")
        {
            Clustered = true;
        }
        key(K2; "Local State", "Next Execution")
        {
            // used by the Job Queue dispatcher to select the next job
        }
        key(K3; Ticket)
        {
        }
    }

    trigger OnInsert()
    begin
        "Created On" := CurrentDateTime();
        "Updated On" := CurrentDateTime();
    end;

    trigger OnModify()
    begin
        "Updated On" := CurrentDateTime();
    end;
}
