namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Records collection coverage and gaps by period, environment and service (see flow 7.4
/// and spec section 11). Populated by the coverage job and displayed on the panel.
/// </summary>
table 50107 "CBS Coverage"
{
    Caption = 'CBS Coverage';
    DataClassification = SystemMetadata;
    Access = Internal;

    fields
    {
        field(1; Environment; Enum "CBS Environment Type")
        {
            Caption = 'Environment';
            DataClassification = SystemMetadata;
        }
        field(2; Service; Enum "CBS Service")
        {
            Caption = 'Service';
            DataClassification = SystemMetadata;
        }
        field(3; Period; Date)
        {
            Caption = 'Period';
            DataClassification = CustomerContent;
        }
        field(10; "Query Completed On"; DateTime)
        {
            Caption = 'Last Query Completed On';
            DataClassification = SystemMetadata;
        }
        field(11; "Debts Imported"; Integer)
        {
            Caption = 'Debts Imported';
            DataClassification = SystemMetadata;
        }
        field(12; Gap; Boolean)
        {
            Caption = 'Gap Detected';
            DataClassification = SystemMetadata;
        }
        field(13; Reason; Text[250])
        {
            Caption = 'Gap Reason';
            DataClassification = SystemMetadata;
        }
        field(20; "Report Generated On"; DateTime)
        {
            Caption = 'Report Generated On';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; Environment, Service, Period)
        {
            Clustered = true;
        }
    }
}
