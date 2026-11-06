namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Audit and integration event log (collection, import, reconciliation, configuration and
/// security). An event table: it has no natural key, only the sequential number. NEVER
/// record a token, secret, signed URL or Revenue Service response body here (see RN03/ADR-08
/// and spec section 12).
/// </summary>
table 50108 "CBS Log Entry"
{
    Caption = 'CBS Event Log';
    DataClassification = SystemMetadata;
    Access = Internal;

    fields
    {
        field(1; "Entry No"; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(10; "Date Time"; DateTime)
        {
            Caption = 'Date and Time';
            DataClassification = SystemMetadata;
        }
        field(11; "User Id"; Code[50])
        {
            Caption = 'User';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(20; Category; Enum "CBS Log Category")
        {
            Caption = 'Category';
            DataClassification = SystemMetadata;
        }
        field(21; Severity; Enum "CBS Log Severity")
        {
            Caption = 'Severity';
            DataClassification = SystemMetadata;
        }
        field(30; "Event"; Text[100])
        {
            Caption = 'Event';
            DataClassification = SystemMetadata;
        }
        field(31; "Message"; Text[250])
        {
            Caption = 'Message';
            DataClassification = SystemMetadata;
        }
        field(32; Correlation; Text[50])
        {
            Caption = 'Correlation';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No")
        {
            Clustered = true;
        }
        key(K2; Category, "Date Time")
        {
        }
        key(K3; Severity)
        {
        }
    }
}
