namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Controls the atomic publication of a batch (see ADR-04 and spec section 6.8/9.1): the
/// batch records only become visible to consumption (panel, lists) after "Published" is set
/// to true, in a single final transaction.
/// </summary>
table 50106 "CBS Batch"
{
    Caption = 'CBS Batch';
    DataClassification = SystemMetadata;
    Access = Internal;

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            DataClassification = SystemMetadata;
        }
        field(10; "Request Entry No"; Integer)
        {
            Caption = 'Request';
            TableRelation = "CBS Request"."Entry No";
            DataClassification = SystemMetadata;
        }
        field(11; Type; Enum "CBS Batch Type")
        {
            Caption = 'Type';
            DataClassification = SystemMetadata;
        }
        field(12; "File Hash"; Text[64])
        {
            Caption = 'File Hash';
            DataClassification = SystemMetadata;
        }
        field(20; Published; Boolean)
        {
            Caption = 'Published';
            DataClassification = SystemMetadata;
        }
        field(21; "Published On"; DateTime)
        {
            Caption = 'Published On';
            DataClassification = SystemMetadata;
        }
        field(22; Records; Integer)
        {
            Caption = 'Records';
            DataClassification = SystemMetadata;
        }
        field(30; "Started On"; DateTime)
        {
            Caption = 'Started On';
            DataClassification = SystemMetadata;
        }
        field(31; "Ended On"; DateTime)
        {
            Caption = 'Ended On';
            DataClassification = SystemMetadata;
        }
        field(40; "Error Text"; Text[250])
        {
            Caption = 'Error';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
        key(K2; "File Hash", "Request Entry No")
        {
            // prevents publishing the same file twice for the same request
        }
    }
}
